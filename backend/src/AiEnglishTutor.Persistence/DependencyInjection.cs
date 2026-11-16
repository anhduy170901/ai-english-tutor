using AiEnglishTutor.Application.Repositories;
using AiEnglishTutor.Application.Services;
using AiEnglishTutor.Persistence.Context;
using AiEnglishTutor.Persistence.Repositories;
using AiEnglishTutor.Persistence.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace AiEnglishTutor.Persistence
{
    public static class DependencyInjection
    {
        public static IServiceCollection AddPersistence(this IServiceCollection services, IConfiguration configuration)
        {
            var connectionString = configuration.GetConnectionString("DefaultConnection") 
                ?? throw new InvalidOperationException("Database connection string 'DefaultConnection' was not found. Please configure it in appsettings.json or via the ConnectionStrings__DefaultConnection environment variable.");

            // Write DbContext (PostgreSQL)
            services.AddDbContext<TutorWriteDbContext>(options =>
                options.UseNpgsql(connectionString));

            // Read DbContext (PostgreSQL)
            services.AddDbContext<TutorReadDbContext>(options =>
                options.UseNpgsql(connectionString));

            // Repositories (Write)
            services.AddScoped<ISessionRepository, SessionRepository>();

            // Query Services (Read)
            services.AddScoped<ISessionQueryService, SessionQueryService>();

            return services;
        }
    }
}
