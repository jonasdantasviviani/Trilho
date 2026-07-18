using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Trilho.Domain.Entities;
using Trilho.Domain.Enums;

namespace Trilho.Infrastructure.Persistence.Seeds;

public class DatabaseSeeder(AppDbContext db, ILogger<DatabaseSeeder> logger)
{
    public async Task SeedAsync(CancellationToken ct = default)
    {
        await db.Database.MigrateAsync(ct);

        if (await db.Cities.AnyAsync(ct))
        {
            logger.LogInformation("Database already seeded, skipping.");
            return;
        }

        logger.LogInformation("Seeding cities...");
        db.Cities.AddRange(CitiesSeed.All);
        await db.SaveChangesAsync(ct);

        logger.LogInformation("Seeding lines...");
        db.Lines.AddRange(LinesSeed.Lines);
        await db.SaveChangesAsync(ct);

        var lineIdsByCode = await db.Lines
            .ToDictionaryAsync(l => l.Code, l => l.Id, ct);

        logger.LogInformation("Seeding stations...");
        var stations = LinesSeed.CreateStations(lineIdsByCode);
        db.Stations.AddRange(stations);
        await db.SaveChangesAsync(ct);

        logger.LogInformation("Seeding historical demand...");
        await SeedHistoricalDemandAsync(ct);

        logger.LogInformation("Database seed complete.");
    }

    private async Task SeedHistoricalDemandAsync(CancellationToken ct)
    {
        var stations = await db.Stations.Include(s => s.Line).ToListAsync(ct);
        var demands = new List<HistoricalDemand>();
        var rng = new Random(42);

        foreach (var station in stations)
        {
            foreach (DayType dayType in Enum.GetValues<DayType>())
            {
                for (short hour = 0; hour <= 23; hour++)
                {
                    double peakFactor = dayType switch
                    {
                        DayType.Weekday  => HourlyWeekdayFactor(hour),
                        DayType.Saturday => HourlySaturdayFactor(hour),
                        _                => HourlySundayFactor(hour)
                    };
                    int avg = (int)(station.Capacity * peakFactor * (0.85 + rng.NextDouble() * 0.3));
                    demands.Add(new HistoricalDemand
                    {
                        StationId      = station.Id,
                        DayType        = dayType,
                        Hour           = hour,
                        AvgPassengers  = Math.Min(avg, station.Capacity)
                    });
                }
            }
        }

        db.HistoricalDemands.AddRange(demands);
        await db.SaveChangesAsync(ct);
    }

    // ── Hourly load curves — calibrated to Metro SP/CPTM published demand data ──
    //
    // Source: Metro SP — Pesquisa Origem-Destino 2017 + annual demand reports.
    // Values represent fraction of station capacity (0.0–1.0).
    // Morning peak: 07–09h; Evening peak: 17–19h; midday shoulder: 10–16h.
    //
    // NOTE: GtfsHistoricalDemandWorker overwrites these once GTFS data is imported.

    private static double HourlyWeekdayFactor(short h) => h switch
    {
        4              => 0.05,
        5              => 0.12,
        6              => 0.35,
        7              => 0.75, // morning peak starts
        8              => 0.90, // highest inbound peak
        9              => 0.70,
        10             => 0.55,
        11             => 0.50,
        12             => 0.55, // lunch shoulder
        13             => 0.52,
        14             => 0.50,
        15             => 0.55,
        16             => 0.68,
        17             => 0.88, // evening peak
        18             => 0.95, // absolute peak
        19             => 0.80,
        20             => 0.55,
        21             => 0.38,
        22             => 0.20,
        23             => 0.08,
        _              => 0.03  // midnight–03h
    };

    private static double HourlySaturdayFactor(short h) => h switch
    {
        5              => 0.05,
        6              => 0.12,
        7              => 0.22,
        8              => 0.35,
        9              => 0.48,
        10             => 0.58,
        11             => 0.65,
        12             => 0.68,
        13             => 0.65,
        14             => 0.62,
        15             => 0.60,
        16             => 0.62,
        17             => 0.65,
        18             => 0.60,
        19             => 0.50,
        20             => 0.38,
        21             => 0.28,
        22             => 0.15,
        23             => 0.07,
        _              => 0.02
    };

    private static double HourlySundayFactor(short h) => h switch
    {
        6              => 0.05,
        7              => 0.10,
        8              => 0.18,
        9              => 0.28,
        10             => 0.40,
        11             => 0.48,
        12             => 0.52,
        13             => 0.50,
        14             => 0.48,
        15             => 0.46,
        16             => 0.48,
        17             => 0.50,
        18             => 0.45,
        19             => 0.35,
        20             => 0.25,
        21             => 0.15,
        22             => 0.08,
        _              => 0.02
    };
}
