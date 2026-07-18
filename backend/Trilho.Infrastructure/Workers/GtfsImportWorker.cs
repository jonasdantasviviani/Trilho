using CsvHelper;
using CsvHelper.Configuration;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using NetTopologySuite.Geometries;
using System.Globalization;
using System.Text.Json;
using System.Text.Json.Serialization;
using Trilho.Domain.Entities;
using Trilho.Infrastructure.Persistence;

namespace Trilho.Infrastructure.Workers;

/// <summary>
/// Imports SPTrans GTFS feed data into the database.
///
/// Sources (in priority order)
/// ───────────────────────────
/// 1. Local folder  — set <c>Gtfs:LocalPath</c> in appsettings to an absolute or
///    relative path containing the extracted GTFS .txt files.
///    The worker checks every <see cref="LocalCheckInterval"/> whether any file in the
///    folder is newer than the last sync recorded in <c>.sync.json</c>; if so it
///    reimports automatically.
///
/// 2. URL download  — if no local path is configured (or the folder is empty), the
///    worker downloads from <c>Gtfs:Sources</c> (list of .zip URLs) once per
///    <see cref="UrlRefreshInterval"/>.
///
/// Import strategy
/// ───────────────
/// Each import is a *full replace*: all six GTFS tables are truncated first, then all
/// records are bulk-inserted.  This is orders of magnitude faster than the previous
/// per-row AnyAsync approach and guarantees a consistent snapshot.
///
/// Sync tracking
/// ─────────────
/// After every successful import the worker writes <c>.sync.json</c> next to the GTFS
/// files (or in the temp folder for URL imports).  The file records the timestamp, the
/// data source, the newest file mtime, and per-table record counts.
/// <c>GET /api/admin/gtfs/status</c> reads this file and returns the data.
/// </summary>
public class GtfsImportWorker(
    IServiceScopeFactory scopeFactory,
    IHttpClientFactory httpClientFactory,
    IConfiguration config,
    ILogger<GtfsImportWorker> logger) : BackgroundService
{
    // Re-check local folder every 10 min (cheap: only reads file mtimes).
    private static readonly TimeSpan LocalCheckInterval = TimeSpan.FromMinutes(10);

    // Re-download GTFS zip from URL once per week.
    private static readonly TimeSpan UrlRefreshInterval = TimeSpan.FromDays(7);

    // Default GTFS URL (fallback when no local path is configured).
    private const string DefaultGtfsUrl = "https://www.sptrans.com.br/desenvolvedores/files/v1/gtfs.zip";

    // Name of the sidecar file written after each successful import.
    public const string SyncFileName = ".sync.json";

    // Batch size for bulk inserts (stop_times can be large).
    private const int BulkBatchSize = 5_000;

    // ── Config helpers ─────────────────────────────────────────────────────────

    private string? ResolvedLocalPath
    {
        get
        {
            var raw = config["Gtfs:LocalPath"];
            if (string.IsNullOrWhiteSpace(raw)) return null;

            var resolved = Path.IsPathRooted(raw) ? raw
                : Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, raw));

            return Directory.Exists(resolved) ? resolved : null;
        }
    }

    private IReadOnlyList<string> GtfsSources =>
        config.GetSection("Gtfs:Sources").Get<string[]>() is { Length: > 0 } urls
            ? urls
            : [DefaultGtfsUrl];

    // ── BackgroundService ──────────────────────────────────────────────────────

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        logger.LogInformation("GtfsImportWorker started.");

        // Short startup delay so the DB is ready (migrations run first).
        await Task.Delay(TimeSpan.FromSeconds(30), stoppingToken);

        while (!stoppingToken.IsCancellationRequested)
        {
            try   { await TryImportIfNeededAsync(stoppingToken); }
            catch (OperationCanceledException) { break; }
            catch (Exception ex) { logger.LogError(ex, "GtfsImportWorker unhandled error."); }

            var delay = ResolvedLocalPath is not null ? LocalCheckInterval : UrlRefreshInterval;
            await Task.Delay(delay, stoppingToken);
        }
    }

    // ── Import decision ────────────────────────────────────────────────────────

    private async Task TryImportIfNeededAsync(CancellationToken ct)
    {
        var localPath = ResolvedLocalPath;

        if (localPath is not null)
        {
            if (await IsLocalFolderNewerThanLastSyncAsync(localPath))
            {
                logger.LogInformation("GtfsImportWorker: local GTFS folder has newer files, starting import.");
                await ImportFromFolderAsync(localPath, ct);
            }
            else
            {
                logger.LogDebug("GtfsImportWorker: local GTFS folder is up to date, skipping.");
            }
        }
        else
        {
            if (await IsUrlRefreshDueAsync())
            {
                logger.LogInformation("GtfsImportWorker: URL refresh due, downloading GTFS.");
                foreach (var url in GtfsSources)
                    await ImportFromUrlAsync(url, ct);
            }
        }
    }

    // ── Local folder ──────────────────────────────────────────────────────────

    private static async Task<bool> IsLocalFolderNewerThanLastSyncAsync(string folderPath)
    {
        var syncFile = Path.Combine(folderPath, SyncFileName);
        if (!File.Exists(syncFile)) return true;   // never synced

        var syncInfo = await ReadSyncFileAsync(syncFile);
        if (syncInfo is null) return true;

        var newestMtime = GetNewestFileMtime(folderPath);
        return newestMtime > syncInfo.FileModifiedAt;
    }

    private async Task ImportFromFolderAsync(string folderPath, CancellationToken ct)
    {
        logger.LogInformation("GtfsImportWorker: importing from local folder {Path}", folderPath);

        using var scope = scopeFactory.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();

        var counts = await RunFullImportAsync(db, folderPath, ct);

        var syncInfo = new GtfsSyncInfo
        {
            SyncedAt       = DateTime.UtcNow,
            Source         = folderPath,
            FileModifiedAt = GetNewestFileMtime(folderPath),
            Counts         = counts
        };
        await WriteSyncFileAsync(Path.Combine(folderPath, SyncFileName), syncInfo);

        logger.LogInformation(
            "GtfsImportWorker: local import done — {Stops} stops, {Routes} routes, {Trips} trips, {StopTimes} stop_times.",
            counts.Stops, counts.Routes, counts.Trips, counts.StopTimes);
    }

    // ── URL download ───────────────────────────────────────────────────────────

    private async Task<bool> IsUrlRefreshDueAsync()
    {
        // Look for a .sync.json in the temp GTFS dir or AppContext.BaseDirectory
        var syncFile = Path.Combine(AppContext.BaseDirectory, SyncFileName);
        if (!File.Exists(syncFile)) return true;

        var info = await ReadSyncFileAsync(syncFile);
        return info is null || (DateTime.UtcNow - info.SyncedAt) >= UrlRefreshInterval;
    }

    private async Task ImportFromUrlAsync(string url, CancellationToken ct)
    {
        logger.LogInformation("GtfsImportWorker: downloading GTFS from {Url}", url);

        var tempZip     = Path.GetTempFileName();
        var extractPath = Path.Combine(Path.GetTempPath(), $"gtfs_{Guid.NewGuid()}");

        try
        {
            var http = httpClientFactory.CreateClient("gtfs");
            var resp = await http.GetAsync(url, ct);
            resp.EnsureSuccessStatusCode();

            await using (var fs = new FileStream(tempZip, FileMode.Create, FileAccess.Write, FileShare.None, 81920, true))
                await resp.Content.CopyToAsync(fs, ct);

            System.IO.Compression.ZipFile.ExtractToDirectory(tempZip, extractPath);

            using var scope = scopeFactory.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();

            var counts = await RunFullImportAsync(db, extractPath, ct);

            var syncInfo = new GtfsSyncInfo
            {
                SyncedAt       = DateTime.UtcNow,
                Source         = url,
                FileModifiedAt = GetNewestFileMtime(extractPath),
                Counts         = counts
            };
            await WriteSyncFileAsync(Path.Combine(AppContext.BaseDirectory, SyncFileName), syncInfo);

            logger.LogInformation(
                "GtfsImportWorker: URL import done from {Url} — {Stops} stops, {Routes} routes, {Trips} trips, {StopTimes} stop_times.",
                url, counts.Stops, counts.Routes, counts.Trips, counts.StopTimes);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "GtfsImportWorker: failed to import from {Url}", url);
        }
        finally
        {
            if (Directory.Exists(extractPath)) Directory.Delete(extractPath, true);
            if (File.Exists(tempZip)) File.Delete(tempZip);
        }
    }

    // ── Core import ────────────────────────────────────────────────────────────

    /// <summary>
    /// Full-replace import: truncates all six GTFS tables, then bulk-inserts from the
    /// txt files found in <paramref name="folderPath"/>.
    /// Returns record counts for each table.
    /// </summary>
    private async Task<GtfsCounts> RunFullImportAsync(
        AppDbContext db, string folderPath, CancellationToken ct)
    {
        // ── Truncate in dependency order (no FK constraints between GTFS tables) ──
        logger.LogDebug("GtfsImportWorker: truncating GTFS tables…");
        await db.Database.ExecuteSqlRawAsync(
            "TRUNCATE TABLE gtfs_stop_times, gtfs_trips, gtfs_calendars, gtfs_stops, gtfs_routes, gtfs_agencies",
            ct);

        int agencies  = await ImportAgenciesBulkAsync(db, folderPath, ct);
        int routes    = await ImportRoutesBulkAsync(db, folderPath, ct);
        int stops     = await ImportStopsBulkAsync(db, folderPath, ct);
        int trips     = await ImportTripsBulkAsync(db, folderPath, ct);
        int calendars = await ImportCalendarBulkAsync(db, folderPath, ct);
        int stopTimes = await ImportStopTimesBulkAsync(db, folderPath, ct);

        return new GtfsCounts(agencies, routes, stops, trips, calendars, stopTimes);
    }

    // ── Per-table bulk import ─────────────────────────────────────────────────

    private static async Task<int> ImportAgenciesBulkAsync(
        AppDbContext db, string dir, CancellationToken ct)
    {
        var path = Path.Combine(dir, "agency.txt");
        if (!File.Exists(path)) return 0;

        var records = ReadCsv<GtfsAgencyCsv>(path)
            .Select(r => new GtfsAgency
            {
                AgencyId       = r.agency_id,
                AgencyName     = r.agency_name,
                AgencyUrl      = r.agency_url,
                AgencyTimezone = r.agency_timezone
            }).ToList();

        db.GtfsAgencies.AddRange(records);
        await db.SaveChangesAsync(ct);
        return records.Count;
    }

    private static async Task<int> ImportRoutesBulkAsync(
        AppDbContext db, string dir, CancellationToken ct)
    {
        var path = Path.Combine(dir, "routes.txt");
        if (!File.Exists(path)) return 0;

        var records = ReadCsv<GtfsRouteCsv>(path)
            .Select(r => new GtfsRoute
            {
                RouteId        = r.route_id,
                AgencyId       = r.agency_id,
                RouteShortName = r.route_short_name,
                RouteLongName  = r.route_long_name,
                RouteColor     = r.route_color     ?? string.Empty,
                RouteTextColor = r.route_text_color ?? string.Empty
            }).ToList();

        db.GtfsRoutes.AddRange(records);
        await db.SaveChangesAsync(ct);
        return records.Count;
    }

    private static async Task<int> ImportStopsBulkAsync(
        AppDbContext db, string dir, CancellationToken ct)
    {
        var path = Path.Combine(dir, "stops.txt");
        if (!File.Exists(path)) return 0;

        var records = ReadCsv<GtfsStopCsv>(path)
            .Select(r => new GtfsStop
            {
                StopId   = r.stop_id,
                StopName = r.stop_name,
                StopLat  = r.stop_lat,
                StopLon  = r.stop_lon,
                StopCode = r.stop_code,
                Location = new Point(r.stop_lon, r.stop_lat) { SRID = 4326 }
            }).ToList();

        db.GtfsStops.AddRange(records);
        await db.SaveChangesAsync(ct);
        return records.Count;
    }

    private static async Task<int> ImportTripsBulkAsync(
        AppDbContext db, string dir, CancellationToken ct)
    {
        var path = Path.Combine(dir, "trips.txt");
        if (!File.Exists(path)) return 0;

        var records = ReadCsv<GtfsTripCsv>(path)
            .Select(r => new GtfsTrip
            {
                TripId       = r.trip_id,
                RouteId      = r.route_id,
                ServiceId    = r.service_id,
                TripHeadsign = r.trip_headsign,
                DirectionId  = r.direction_id == "1"
            }).ToList();

        db.GtfsTrips.AddRange(records);
        await db.SaveChangesAsync(ct);
        return records.Count;
    }

    private static async Task<int> ImportCalendarBulkAsync(
        AppDbContext db, string dir, CancellationToken ct)
    {
        var path = Path.Combine(dir, "calendar.txt");
        if (!File.Exists(path)) return 0;

        var records = ReadCsv<GtfsCalendarCsv>(path)
            .Select(r => new GtfsCalendar
            {
                ServiceId = r.service_id,
                Monday    = r.monday    == "1",
                Tuesday   = r.tuesday   == "1",
                Wednesday = r.wednesday == "1",
                Thursday  = r.thursday  == "1",
                Friday    = r.friday    == "1",
                Saturday  = r.saturday  == "1",
                Sunday    = r.sunday    == "1",
                StartDate = ParseGtfsDate(r.start_date),
                EndDate   = ParseGtfsDate(r.end_date)
            }).ToList();

        db.GtfsCalendars.AddRange(records);
        await db.SaveChangesAsync(ct);
        return records.Count;
    }

    /// <summary>
    /// Stop times can be very large — stream them in batches of <see cref="BulkBatchSize"/>
    /// to avoid loading the entire file into memory.
    /// </summary>
    private static async Task<int> ImportStopTimesBulkAsync(
        AppDbContext db, string dir, CancellationToken ct)
    {
        var path = Path.Combine(dir, "stop_times.txt");
        if (!File.Exists(path)) return 0;

        var csvConfig = new CsvConfiguration(CultureInfo.InvariantCulture)
        {
            HeaderValidated  = null,
            MissingFieldFound = null
        };

        int total = 0;
        var batch = new List<GtfsStopTime>(BulkBatchSize);

        using var reader = new StreamReader(path);
        using var csv    = new CsvReader(reader, csvConfig);

        await foreach (var r in csv.GetRecordsAsync<GtfsStopTimeCsv>())
        {
            batch.Add(new GtfsStopTime
            {
                TripId        = r.trip_id,
                StopId        = r.stop_id,
                StopSequence  = r.stop_sequence,
                ArrivalTime   = r.arrival_time,
                DepartureTime = r.departure_time
            });

            if (batch.Count >= BulkBatchSize)
            {
                db.GtfsStopTimes.AddRange(batch);
                await db.SaveChangesAsync(ct);
                total += batch.Count;
                batch.Clear();
                db.ChangeTracker.Clear();   // release tracked entities from memory
            }
        }

        if (batch.Count > 0)
        {
            db.GtfsStopTimes.AddRange(batch);
            await db.SaveChangesAsync(ct);
            total += batch.Count;
        }

        return total;
    }

    // ── Sync file helpers ──────────────────────────────────────────────────────

    private static readonly JsonSerializerOptions SyncJsonOptions = new()
    {
        WriteIndented          = true,
        PropertyNamingPolicy   = JsonNamingPolicy.CamelCase,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
    };

    private static async Task WriteSyncFileAsync(string path, GtfsSyncInfo info)
    {
        var json = JsonSerializer.Serialize(info, SyncJsonOptions);
        await File.WriteAllTextAsync(path, json);
    }

    public static async Task<GtfsSyncInfo?> ReadSyncFileAsync(string path)
    {
        if (!File.Exists(path)) return null;
        try
        {
            var json = await File.ReadAllTextAsync(path);
            return JsonSerializer.Deserialize<GtfsSyncInfo>(json, SyncJsonOptions);
        }
        catch { return null; }
    }

    /// <summary>Returns the path to the .sync.json for the configured source.</summary>
    public string? SyncFilePath
    {
        get
        {
            var local = ResolvedLocalPath;
            if (local is not null) return Path.Combine(local, SyncFileName);
            return Path.Combine(AppContext.BaseDirectory, SyncFileName);
        }
    }

    // ── Utility ────────────────────────────────────────────────────────────────

    private static DateTime GetNewestFileMtime(string folderPath) =>
        Directory.GetFiles(folderPath, "*.txt")
            .Select(f => File.GetLastWriteTimeUtc(f))
            .DefaultIfEmpty(DateTime.MinValue)
            .Max();

    private static IEnumerable<T> ReadCsv<T>(string path)
    {
        var config = new CsvConfiguration(CultureInfo.InvariantCulture)
        {
            HeaderValidated   = null,
            MissingFieldFound = null
        };
        using var reader = new StreamReader(path);
        using var csv    = new CsvReader(reader, config);
        return csv.GetRecords<T>().ToList(); // materialise inside using
    }

    private static DateTime ParseGtfsDate(string? yyyymmdd)
    {
        if (yyyymmdd is { Length: 8 } &&
            int.TryParse(yyyymmdd[..4], out var y) &&
            int.TryParse(yyyymmdd[4..6], out var m) &&
            int.TryParse(yyyymmdd[6..8], out var d))
            return new DateTime(y, m, d, 0, 0, 0, DateTimeKind.Utc);
        return DateTime.MinValue;
    }
}

// ── Sync metadata ──────────────────────────────────────────────────────────────

public record GtfsCounts(
    int Agencies,
    int Routes,
    int Stops,
    int Trips,
    int Calendars,
    int StopTimes);

public class GtfsSyncInfo
{
    public DateTime   SyncedAt       { get; set; }
    public string     Source         { get; set; } = string.Empty;
    public DateTime   FileModifiedAt { get; set; }
    public GtfsCounts Counts         { get; set; } = new(0, 0, 0, 0, 0, 0);
}

// ── CSV record classes ─────────────────────────────────────────────────────────

internal class GtfsAgencyCsv
{
    public string agency_id       { get; set; } = string.Empty;
    public string agency_name     { get; set; } = string.Empty;
    public string agency_url      { get; set; } = string.Empty;
    public string agency_timezone { get; set; } = string.Empty;
}

internal class GtfsRouteCsv
{
    public string  route_id         { get; set; } = string.Empty;
    public string  agency_id        { get; set; } = string.Empty;
    public string  route_short_name { get; set; } = string.Empty;
    public string  route_long_name  { get; set; } = string.Empty;
    public string? route_color      { get; set; }
    public string? route_text_color { get; set; }
}

internal class GtfsStopCsv
{
    public string  stop_id   { get; set; } = string.Empty;
    public string  stop_name { get; set; } = string.Empty;
    public double  stop_lat  { get; set; }
    public double  stop_lon  { get; set; }
    public string? stop_code { get; set; }
}

internal class GtfsTripCsv
{
    public string  route_id      { get; set; } = string.Empty;
    public string  service_id    { get; set; } = string.Empty;
    public string  trip_id       { get; set; } = string.Empty;
    public string? trip_headsign { get; set; }
    public string? direction_id  { get; set; }
}

internal class GtfsCalendarCsv
{
    public string  service_id { get; set; } = string.Empty;
    public string  monday     { get; set; } = "0";
    public string  tuesday    { get; set; } = "0";
    public string  wednesday  { get; set; } = "0";
    public string  thursday   { get; set; } = "0";
    public string  friday     { get; set; } = "0";
    public string  saturday   { get; set; } = "0";
    public string  sunday     { get; set; } = "0";
    public string? start_date { get; set; }
    public string? end_date   { get; set; }
}

internal class GtfsStopTimeCsv
{
    public string  trip_id        { get; set; } = string.Empty;
    public string  stop_id        { get; set; } = string.Empty;
    public int     stop_sequence  { get; set; }
    public string? arrival_time   { get; set; }
    public string? departure_time { get; set; }
}
