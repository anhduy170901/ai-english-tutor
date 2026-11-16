using AiEnglishTutor.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace AiEnglishTutor.Persistence.Context
{
    public class TutorReadDbContext : DbContext
    {
        public TutorReadDbContext(DbContextOptions<TutorReadDbContext> options) : base(options) { }

        public DbSet<LearningSession> Sessions => Set<LearningSession>();
        public DbSet<SessionMessage> Messages => Set<SessionMessage>();

        protected override void OnConfiguring(DbContextOptionsBuilder optionsBuilder)
        {
            base.OnConfiguring(optionsBuilder);
            // Strict CQRS: Disable Change Tracking for Read Context
            optionsBuilder.UseQueryTrackingBehavior(QueryTrackingBehavior.NoTracking);
        }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            modelBuilder.Entity<LearningSession>(entity =>
            {
                entity.HasKey(e => e.Id);
                entity.HasMany(e => e.Messages)
                      .WithOne(e => e.Session)
                      .HasForeignKey(e => e.SessionId);
            });
        }
    }
}
