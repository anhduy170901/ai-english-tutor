using AiEnglishTutor.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace AiEnglishTutor.Persistence.Context
{
    public class TutorWriteDbContext : DbContext
    {
        public TutorWriteDbContext(DbContextOptions<TutorWriteDbContext> options) : base(options) { }

        public DbSet<LearningSession> Sessions => Set<LearningSession>();
        public DbSet<SessionMessage> Messages => Set<SessionMessage>();

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            modelBuilder.Entity<LearningSession>(entity =>
            {
                entity.HasKey(e => e.Id);
                entity.Property(e => e.Id).ValueGeneratedNever();
                entity.Property(e => e.Topic).IsRequired().HasMaxLength(255);
                entity.HasMany(e => e.Messages)
                      .WithOne(e => e.Session)
                      .HasForeignKey(e => e.SessionId)
                      .OnDelete(DeleteBehavior.Cascade);
            });

            modelBuilder.Entity<SessionMessage>(entity =>
            {
                entity.HasKey(e => e.Id);
                entity.Property(e => e.Id).ValueGeneratedNever();
                entity.Property(e => e.Content).IsRequired();
            });
        }
    }
}
