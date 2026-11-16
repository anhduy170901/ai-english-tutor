using System.Diagnostics;
using AiEnglishTutor.API.Hubs;
using AiEnglishTutor.Application.Usecases.Session.Commands.StartSession;
using AiEnglishTutor.Infrastructure;
using AiEnglishTutor.Persistence;
using AiEnglishTutor.Persistence.Context;
using Scalar.AspNetCore;
using Serilog;
using Serilog.Core;
using Serilog.Events;
using Serilog.Filters;
using Serilog.Sinks.SystemConsole.Themes;

var builder = WebApplication.CreateBuilder(args);

// 1. Configure Serilog logging (Identical layout to Identity.API, suppresses verbose EF Core SQL)
builder.Host.UseSerilog((context, services, configuration) =>
{
    var sqlLogEnabled = context.Configuration.GetValue<bool>("SqlLogEnabled", false);

    configuration
        .ReadFrom.Configuration(context.Configuration)
        .ReadFrom.Services(services)
        .Enrich.FromLogContext()
        .Enrich.With(new ActivityEnricher())
        .MinimumLevel.Information()
        .MinimumLevel.Override("Microsoft.AspNetCore", LogEventLevel.Warning)
        .MinimumLevel.Override("Microsoft.EntityFrameworkCore", LogEventLevel.Warning);

    if (!sqlLogEnabled)
    {
        configuration.Filter.ByExcluding(Matching.WithProperty<string>(
            "SourceContext",
            ctx => ctx != null && ctx.StartsWith("Microsoft.EntityFrameworkCore.Database.Command")));
    }

    configuration.WriteTo.Console(
        outputTemplate: "{Timestamp:yyyy-MM-dd HH:mm:ss.fff} [{Level:u3}] [{TraceId}] {Message:lj}{NewLine}{Exception}",
        theme: AnsiConsoleTheme.Code);
});

// 2. Add Services to the container
builder.Services.AddControllers();
builder.Services.AddOpenApi();

// 3. Add Clean Architecture Layers
builder.Services.AddPersistence(builder.Configuration);
builder.Services.AddInfrastructure(builder.Configuration);

// 4. Add MediatR (CQRS)
builder.Services.AddMediatR(cfg => 
    cfg.RegisterServicesFromAssembly(typeof(StartSessionCommand).Assembly));

// 5. Add SignalR
builder.Services.AddSignalR(options =>
{
    options.EnableDetailedErrors = true;
    options.MaximumReceiveMessageSize = 10 * 1024 * 1024; // 10MB audio chunk limit
    // Default is 1, which queues a new ProcessUserAudio/ProcessUserText invocation behind
    // whichever one is already running on the same connection instead of letting it interrupt
    // (barge-in). Raised just enough to let a new turn start and cancel the previous one.
    options.MaximumParallelInvocationsPerClient = 4;
})
.AddJsonProtocol(options =>
{
    options.PayloadSerializerOptions.Converters.Add(new AiEnglishTutor.API.Converters.ByteArrayJsonConverter());
});

// 6. CORS policy for Web/Browser clients
// NOTE: CORS is enforced by web browsers (Flutter Web, React, etc.).
// Native Flutter mobile apps (iOS/Android) communicate directly and do not send Origin headers, so CORS does not govern native mobile.
var allowedOrigins = builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>() 
    ?? new[] { "http://localhost:3000", "http://localhost:5000", "http://localhost:5173", "http://localhost:8080", "http://127.0.0.1:3000", "http://127.0.0.1:5000", "http://127.0.0.1:5173", "http://127.0.0.1:8080" };

builder.Services.AddCors(options =>
{
    options.AddPolicy("DefaultCorsPolicy", policy =>
    {
        policy.WithOrigins(allowedOrigins)
              .AllowAnyMethod()
              .AllowAnyHeader()
              .AllowCredentials();
    });
});

var app = builder.Build();

// 7. Ensure Database Created
using (var scope = app.Services.CreateScope())
{
    var writeContext = scope.ServiceProvider.GetRequiredService<TutorWriteDbContext>();
    writeContext.Database.EnsureCreated();
}

// 8. Configure HTTP Request Pipeline
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
    app.MapScalarApiReference();
}

app.UseCors("DefaultCorsPolicy");

app.MapControllers();
app.MapHub<VoiceHub>("/hubs/voice");

app.Run();

/// <summary>
/// Enriches log events with the current Activity TraceId for request correlation.
/// </summary>
public class ActivityEnricher : ILogEventEnricher
{
    public void Enrich(LogEvent logEvent, ILogEventPropertyFactory propertyFactory)
    {
        var activity = Activity.Current;
        if (activity != null)
        {
            var traceId = activity.TraceId.ToString();
            if (!string.IsNullOrEmpty(traceId) && traceId != "00000000000000000000000000000000")
            {
                logEvent.AddPropertyIfAbsent(propertyFactory.CreateProperty("TraceId", traceId));
            }
        }
    }
}
