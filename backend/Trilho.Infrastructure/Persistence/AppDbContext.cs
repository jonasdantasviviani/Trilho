using Microsoft.EntityFrameworkCore;
using Trilho.Domain.Entities;
using Trilho.Domain.Enums;

namespace Trilho.Infrastructure.Persistence;

public class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    public DbSet<Line> Lines => Set<Line>();
    public DbSet<Station> Stations => Set<Station>();
    public DbSet<CrowdSnapshot> CrowdSnapshots => Set<CrowdSnapshot>();
    public DbSet<LineStatusEntry> LineStatuses => Set<LineStatusEntry>();
    public DbSet<HistoricalDemand> HistoricalDemands => Set<HistoricalDemand>();
    public DbSet<User> Users => Set<User>();
    public DbSet<UserPing> UserPings => Set<UserPing>();
    public DbSet<UserDeviceToken> UserDeviceTokens => Set<UserDeviceToken>();
    public DbSet<AdminUser> AdminUsers => Set<AdminUser>();

    public DbSet<GtfsAgency> GtfsAgencies => Set<GtfsAgency>();
    public DbSet<GtfsRoute> GtfsRoutes => Set<GtfsRoute>();
    public DbSet<GtfsStop> GtfsStops => Set<GtfsStop>();
    public DbSet<GtfsTrip> GtfsTrips => Set<GtfsTrip>();
    public DbSet<GtfsStopTime> GtfsStopTimes => Set<GtfsStopTime>();
    public DbSet<GtfsCalendar> GtfsCalendars => Set<GtfsCalendar>();
    public DbSet<City> Cities => Set<City>();

    protected override void OnModelCreating(ModelBuilder mb)
    {
        // Line
        mb.Entity<Line>(e => {
            e.HasKey(x => x.Id);
            e.HasIndex(x => x.Code).IsUnique();
            e.Property(x => x.Code).HasMaxLength(15).IsRequired();
            e.Property(x => x.Name).HasMaxLength(100).IsRequired();
            e.Property(x => x.Type).HasConversion<string>();
            e.Property(x => x.ColorHex).HasColumnType("char(6)").IsRequired();
            e.HasOne(x => x.City).WithMany(c => c.Lines).HasForeignKey(x => x.CityId);
        });

        // Station
        mb.Entity<Station>(e => {
            e.HasKey(x => x.Id);
            e.Property(x => x.ExternalId).HasMaxLength(50);
            e.Property(x => x.Name).HasMaxLength(150).IsRequired();
            e.Property(x => x.Location).HasColumnType("geography(Point,4326)");
            e.HasOne(x => x.Line).WithMany(x => x.Stations).HasForeignKey(x => x.LineId);
        });

        // CrowdSnapshot
        mb.Entity<CrowdSnapshot>(e => {
            e.HasKey(x => x.Id);
            e.Property(x => x.InferredDensity).HasPrecision(4, 2);
            e.Property(x => x.DensityLevel).HasConversion<string>();
            e.Property(x => x.Source).HasConversion<string>();
            e.HasOne(x => x.Station).WithMany(x => x.CrowdSnapshots).HasForeignKey(x => x.StationId);
            e.HasIndex(x => new { x.StationId, x.CapturedAt });
        });

        // LineStatusEntry
        mb.Entity<LineStatusEntry>(e => {
            e.ToTable("line_status");
            e.HasKey(x => x.Id);
            e.Property(x => x.Status).HasConversion<string>();
            e.HasOne(x => x.Line).WithMany(x => x.StatusHistory).HasForeignKey(x => x.LineId);
            e.HasIndex(x => new { x.LineId, x.CapturedAt });
        });

        // HistoricalDemand
        mb.Entity<HistoricalDemand>(e => {
            e.HasKey(x => new { x.StationId, x.DayType, x.Hour });
            e.Property(x => x.DayType).HasConversion<string>();
            e.HasOne(x => x.Station).WithMany(x => x.HistoricalDemands).HasForeignKey(x => x.StationId);
        });

        // User
        mb.Entity<User>(e => {
            e.HasKey(x => x.Id);
            e.Property(x => x.VipEmail).HasMaxLength(255);
            e.Property(x => x.TaxId).HasMaxLength(20);
            e.Property(x => x.ActiveBillingId).HasMaxLength(100);
            e.Property(x => x.CurrentPaymentMethod).HasMaxLength(50);
            e.Ignore(x => x.CanQuery); // computed property, not persisted
        });

        // UserPing
        mb.Entity<UserPing>(e => {
            e.HasKey(x => x.Id);
            e.HasOne(x => x.User).WithMany(x => x.Pings).HasForeignKey(x => x.UserId);
        });

        // UserDeviceToken
        mb.Entity<UserDeviceToken>(e => {
            e.HasKey(x => x.Id);
            e.HasIndex(x => x.Token).IsUnique();
            e.Property(x => x.Platform).HasMaxLength(20);
            e.HasOne(x => x.User).WithMany(x => x.DeviceTokens).HasForeignKey(x => x.UserId);
        });

        // AdminUser
        mb.Entity<AdminUser>(e => {
            e.HasKey(x => x.Id);
            e.HasIndex(x => x.Email).IsUnique();
            e.Property(x => x.Email).HasMaxLength(255).IsRequired();
            e.Property(x => x.PasswordHash).IsRequired();
        });

        // GTFS Entities
        mb.Entity<GtfsAgency>(e => {
            e.HasKey(x => x.Id);
            e.Property(x => x.AgencyId).HasMaxLength(50).IsRequired();
            e.HasIndex(x => x.AgencyId).IsUnique();
        });

        mb.Entity<GtfsRoute>(e => {
            e.HasKey(x => x.Id);
            e.Property(x => x.RouteId).HasMaxLength(50).IsRequired();
            e.HasIndex(x => x.RouteId).IsUnique();
            e.Property(x => x.AgencyId).HasMaxLength(50).IsRequired();
            e.Property(x => x.RouteColor).HasMaxLength(6);
            e.Property(x => x.RouteTextColor).HasMaxLength(6);
        });

        mb.Entity<GtfsStop>(e => {
            e.HasKey(x => x.Id);
            e.Property(x => x.StopId).HasMaxLength(50).IsRequired();
            e.HasIndex(x => x.StopId).IsUnique();
            e.Property(x => x.Location).HasColumnType("geography(Point,4326)");
        });

        mb.Entity<GtfsTrip>(e => {
            e.HasKey(x => x.Id);
            e.Property(x => x.TripId).HasMaxLength(100).IsRequired();
            e.HasIndex(x => x.TripId).IsUnique();
            e.Property(x => x.RouteId).HasMaxLength(50).IsRequired();
        });

        mb.Entity<GtfsStopTime>(e => {
            e.HasKey(x => x.Id);
            e.Property(x => x.TripId).HasMaxLength(100).IsRequired();
            e.Property(x => x.StopId).HasMaxLength(50).IsRequired();
            e.HasIndex(x => new { x.TripId, x.StopSequence });
        });

        mb.Entity<GtfsCalendar>(e => {
            e.HasKey(x => x.Id);
            e.Property(x => x.ServiceId).HasMaxLength(50).IsRequired();
            e.HasIndex(x => x.ServiceId).IsUnique();
        });

        // City
        mb.Entity<City>(e => {
            e.HasKey(x => x.Id);
            e.Property(x => x.Name).HasMaxLength(100).IsRequired();
            e.Property(x => x.State).HasMaxLength(2).IsRequired();
            e.Property(x => x.Country).HasMaxLength(2).IsRequired();
            e.HasIndex(x => new { x.Name, x.State }).IsUnique();
        });

        // snake_case naming convention
        foreach (var entity in mb.Model.GetEntityTypes())
        {
            var tableName = entity.GetTableName();
            if (tableName != null)
                entity.SetTableName(ToSnakeCase(tableName));

            foreach (var prop in entity.GetProperties())
            {
                var colName = prop.GetColumnName();
                if (colName != null)
                    prop.SetColumnName(ToSnakeCase(colName));
            }
        }
    }

    private static string ToSnakeCase(string name) =>
        string.Concat(name.Select((c, i) =>
            i > 0 && char.IsUpper(c) ? "_" + char.ToLower(c) : char.ToLower(c).ToString()));
}
