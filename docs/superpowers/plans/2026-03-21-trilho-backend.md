# Trilho Backend Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the complete .NET 8 backend for Trilho — a public transit crowding inference engine with REST API, SignalR real-time push, background workers for scraping/polling, and PostgreSQL persistence.

**Architecture:** Clean layered solution: Domain (entities/interfaces/enums) → Infrastructure (EF Core, scrapers, workers, Redis) → API (Minimal API endpoints + SignalR hub). Background workers run on fixed intervals using .NET `BackgroundService`. Crowding is inferred from historical demand × operational status weight.

**Tech Stack:** .NET 8, ASP.NET Core Minimal API, EF Core 8 + Npgsql + PostGIS, Redis (StackExchange.Redis), SignalR, HtmlAgilityPack, Polly, Docker Compose.

**Working directory:** `C:/Users/jonas/OneDrive/Documentos/Projetos/Transit`

---

## Chunk 1: Scaffolding + Domain Layer

### Task 1: Create Solution & Projects

**Files:**
- Create: `backend/Trilho.sln`
- Create: `backend/Trilho.Domain/Trilho.Domain.csproj`
- Create: `backend/Trilho.Infrastructure/Trilho.Infrastructure.csproj`
- Create: `backend/Trilho.API/Trilho.API.csproj`
- Create: `backend/Trilho.Tests/Trilho.Tests.csproj`

- [ ] **Step 1: Scaffold solution**

```bash
cd C:/Users/jonas/OneDrive/Documentos/Projetos/Transit/backend
dotnet new sln -n Trilho
dotnet new classlib -n Trilho.Domain --framework net8.0
dotnet new classlib -n Trilho.Infrastructure --framework net8.0
dotnet new webapi -n Trilho.API --framework net8.0 --no-openapi false
dotnet new xunit -n Trilho.Tests --framework net8.0
dotnet sln add Trilho.Domain/Trilho.Domain.csproj
dotnet sln add Trilho.Infrastructure/Trilho.Infrastructure.csproj
dotnet sln add Trilho.API/Trilho.API.csproj
dotnet sln add Trilho.Tests/Trilho.Tests.csproj
```

- [ ] **Step 2: Add project references**

```bash
cd C:/Users/jonas/OneDrive/Documentos/Projetos/Transit/backend
dotnet add Trilho.Infrastructure/Trilho.Infrastructure.csproj reference Trilho.Domain/Trilho.Domain.csproj
dotnet add Trilho.API/Trilho.API.csproj reference Trilho.Domain/Trilho.Domain.csproj
dotnet add Trilho.API/Trilho.API.csproj reference Trilho.Infrastructure/Trilho.Infrastructure.csproj
dotnet add Trilho.Tests/Trilho.Tests.csproj reference Trilho.Domain/Trilho.Domain.csproj
dotnet add Trilho.Tests/Trilho.Tests.csproj reference Trilho.Infrastructure/Trilho.Infrastructure.csproj
```

- [ ] **Step 3: Add NuGet packages to Infrastructure**

```bash
cd C:/Users/jonas/OneDrive/Documentos/Projetos/Transit/backend/Trilho.Infrastructure
dotnet add package Microsoft.EntityFrameworkCore --version 8.*
dotnet add package Npgsql.EntityFrameworkCore.PostgreSQL --version 8.*
dotnet add package NetTopologySuite --version 2.5.0
dotnet add package HtmlAgilityPack --version 1.11.*
dotnet add package StackExchange.Redis --version 2.7.*
dotnet add package Microsoft.Extensions.Http.Polly --version 8.*
dotnet add package Microsoft.Extensions.Hosting --version 8.*
dotnet add package Microsoft.EntityFrameworkCore.Design --version 8.*
```

- [ ] **Step 4: Add NuGet packages to API**

```bash
cd C:/Users/jonas/OneDrive/Documentos/Projetos/Transit/backend/Trilho.API
dotnet add package Microsoft.AspNetCore.SignalR --version 1.1.0
dotnet add package Microsoft.EntityFrameworkCore.Design --version 8.*
dotnet add package Npgsql.EntityFrameworkCore.PostgreSQL --version 8.*
dotnet add package Microsoft.AspNetCore.Authentication.JwtBearer --version 8.*
dotnet add package System.IdentityModel.Tokens.Jwt --version 7.*
```

- [ ] **Step 5: Add NuGet packages to Tests**

```bash
cd C:/Users/jonas/OneDrive/Documentos/Projetos/Transit/backend/Trilho.Tests
dotnet add package Microsoft.EntityFrameworkCore.InMemory --version 8.*
dotnet add package Moq --version 4.*
dotnet add package FluentAssertions --version 6.*
```

- [ ] **Step 6: Delete boilerplate generated files**

```bash
rm -f C:/Users/jonas/OneDrive/Documentos/Projetos/Transit/backend/Trilho.Domain/Class1.cs
rm -f C:/Users/jonas/OneDrive/Documentos/Projetos/Transit/backend/Trilho.Infrastructure/Class1.cs
rm -f C:/Users/jonas/OneDrive/Documentos/Projetos/Transit/backend/Trilho.API/WeatherForecast.cs
```

---

### Task 2: Domain Entities & Enums

**Files:**
- Create: `backend/Trilho.Domain/Entities/Line.cs`
- Create: `backend/Trilho.Domain/Entities/Station.cs`
- Create: `backend/Trilho.Domain/Entities/CrowdSnapshot.cs`
- Create: `backend/Trilho.Domain/Entities/LineStatus.cs`
- Create: `backend/Trilho.Domain/Entities/HistoricalDemand.cs`
- Create: `backend/Trilho.Domain/Entities/User.cs`
- Create: `backend/Trilho.Domain/Entities/UserPing.cs`
- Create: `backend/Trilho.Domain/Enums/LineType.cs`
- Create: `backend/Trilho.Domain/Enums/OperationalStatus.cs`
- Create: `backend/Trilho.Domain/Enums/DensityLevel.cs`
- Create: `backend/Trilho.Domain/Enums/DayType.cs`
- Create: `backend/Trilho.Domain/Enums/CrowdSource.cs`

- [ ] **Step 1: Create enums**

`backend/Trilho.Domain/Enums/LineType.cs`:
```csharp
namespace Trilho.Domain.Enums;

public enum LineType { Metro, Cptm, Bus }
```

`backend/Trilho.Domain/Enums/OperationalStatus.cs`:
```csharp
namespace Trilho.Domain.Enums;

public enum OperationalStatus { Normal, ReducedSpeed, Partial, Suspended }
```

`backend/Trilho.Domain/Enums/DensityLevel.cs`:
```csharp
namespace Trilho.Domain.Enums;

public enum DensityLevel { Low, Medium, High, Packed }
```

`backend/Trilho.Domain/Enums/DayType.cs`:
```csharp
namespace Trilho.Domain.Enums;

public enum DayType { Weekday, Saturday, Sunday }
```

`backend/Trilho.Domain/Enums/CrowdSource.cs`:
```csharp
namespace Trilho.Domain.Enums;

public enum CrowdSource { Historical, UserPing, Operational }
```

- [ ] **Step 2: Create entity Line**

`backend/Trilho.Domain/Entities/Line.cs`:
```csharp
using Trilho.Domain.Enums;

namespace Trilho.Domain.Entities;

public class Line
{
    public int Id { get; set; }
    public string Code { get; set; } = string.Empty;      // "1-AZUL", "7-RUBI"
    public string Name { get; set; } = string.Empty;
    public LineType Type { get; set; }
    public string ColorHex { get; set; } = string.Empty;  // 6 chars, no #
    public int HeadwayPeakSec { get; set; } = 180;
    public int HeadwayOffPeakSec { get; set; } = 360;

    public ICollection<Station> Stations { get; set; } = [];
    public ICollection<LineStatusEntry> StatusHistory { get; set; } = [];
}
```

- [ ] **Step 3: Create entity Station**

`backend/Trilho.Domain/Entities/Station.cs`:
```csharp
using NetTopologySuite.Geometries;

namespace Trilho.Domain.Entities;

public class Station
{
    public int Id { get; set; }
    public string? ExternalId { get; set; }
    public string Name { get; set; } = string.Empty;
    public int LineId { get; set; }
    public Line Line { get; set; } = null!;
    public int Sequence { get; set; }
    public Point Location { get; set; } = null!;   // GEOGRAPHY(POINT, 4326)
    public int Capacity { get; set; } = 1000;

    public ICollection<CrowdSnapshot> CrowdSnapshots { get; set; } = [];
    public ICollection<HistoricalDemand> HistoricalDemands { get; set; } = [];
}
```

- [ ] **Step 4: Create remaining entities**

`backend/Trilho.Domain/Entities/CrowdSnapshot.cs`:
```csharp
using Trilho.Domain.Enums;

namespace Trilho.Domain.Entities;

public class CrowdSnapshot
{
    public long Id { get; set; }
    public int StationId { get; set; }
    public Station Station { get; set; } = null!;
    public int UserCount { get; set; } = 0;
    public decimal InferredDensity { get; set; }   // 0.00–1.00
    public DensityLevel DensityLevel { get; set; }
    public CrowdSource Source { get; set; }
    public DateTimeOffset CapturedAt { get; set; } = DateTimeOffset.UtcNow;
}
```

`backend/Trilho.Domain/Entities/LineStatusEntry.cs`:
```csharp
using Trilho.Domain.Enums;

namespace Trilho.Domain.Entities;

public class LineStatusEntry
{
    public long Id { get; set; }
    public int LineId { get; set; }
    public Line Line { get; set; } = null!;
    public OperationalStatus Status { get; set; }
    public string? Message { get; set; }
    public string? SourceUrl { get; set; }
    public DateTimeOffset CapturedAt { get; set; } = DateTimeOffset.UtcNow;
}
```

`backend/Trilho.Domain/Entities/HistoricalDemand.cs`:
```csharp
using Trilho.Domain.Enums;

namespace Trilho.Domain.Entities;

public class HistoricalDemand
{
    public int StationId { get; set; }
    public Station Station { get; set; } = null!;
    public DayType DayType { get; set; }
    public short Hour { get; set; }       // 0–23
    public int AvgPassengers { get; set; }
}
```

`backend/Trilho.Domain/Entities/User.cs`:
```csharp
namespace Trilho.Domain.Entities;

public class User
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public bool IsPremium { get; set; } = false;
    public int DailyQueriesUsed { get; set; } = 0;
    public DateOnly QueriesResetAt { get; set; } = DateOnly.FromDateTime(DateTime.UtcNow);
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;

    public ICollection<UserPing> Pings { get; set; } = [];
}
```

`backend/Trilho.Domain/Entities/UserPing.cs`:
```csharp
namespace Trilho.Domain.Entities;

public class UserPing
{
    public long Id { get; set; }
    public Guid UserId { get; set; }
    public User User { get; set; } = null!;
    public int StationId { get; set; }
    public Station Station { get; set; } = null!;
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
}
```

- [ ] **Step 5: Create domain interfaces**

`backend/Trilho.Domain/Interfaces/ITrainPositionProvider.cs`:
```csharp
namespace Trilho.Domain.Interfaces;

public record TrainPosition(int LineId, string LineCode, double Lat, double Lng, DateTimeOffset UpdatedAt);

public interface ITrainPositionProvider
{
    Task<IEnumerable<TrainPosition>> GetPositionsAsync(CancellationToken ct = default);
}
```

`backend/Trilho.Domain/Interfaces/ILineStatusScraper.cs`:
```csharp
using Trilho.Domain.Enums;

namespace Trilho.Domain.Interfaces;

public record ScrapedLineStatus(string LineCode, OperationalStatus Status, string? Message);

public interface ILineStatusScraper
{
    Task<IEnumerable<ScrapedLineStatus>> ScrapeAsync(CancellationToken ct = default);
}
```

- [ ] **Step 6: Verify Domain builds**

```bash
cd C:/Users/jonas/OneDrive/Documentos/Projetos/Transit/backend
dotnet build Trilho.Domain/Trilho.Domain.csproj
```
Expected: Build succeeded with 0 errors.

---

### Task 3: Infrastructure — EF DbContext & Migrations

**Files:**
- Create: `backend/Trilho.Infrastructure/Persistence/AppDbContext.cs`
- Create: `backend/Trilho.Infrastructure/Persistence/Configurations/*.cs`

- [ ] **Step 1: Create AppDbContext**

`backend/Trilho.Infrastructure/Persistence/AppDbContext.cs`:
```csharp
using Microsoft.EntityFrameworkCore;
using NetTopologySuite.Geometries;
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

    protected override void OnModelCreating(ModelBuilder mb)
    {
        // Line
        mb.Entity<Line>(e => {
            e.HasKey(x => x.Id);
            e.HasIndex(x => x.Code).IsUnique();
            e.Property(x => x.Code).HasMaxLength(10).IsRequired();
            e.Property(x => x.Name).HasMaxLength(100).IsRequired();
            e.Property(x => x.Type).HasConversion<string>();
            e.Property(x => x.ColorHex).HasColumnType("char(6)").IsRequired();
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
        });

        // UserPing
        mb.Entity<UserPing>(e => {
            e.HasKey(x => x.Id);
            e.HasOne(x => x.User).WithMany(x => x.Pings).HasForeignKey(x => x.UserId);
        });

        // Apply snake_case naming convention
        foreach (var entity in mb.Model.GetEntityTypes())
        {
            entity.SetTableName(ToSnakeCase(entity.GetTableName()!));
            foreach (var prop in entity.GetProperties())
                prop.SetColumnName(ToSnakeCase(prop.GetColumnName()!));
            foreach (var key in entity.GetKeys())
                key.SetName(ToSnakeCase(key.GetName()!));
            foreach (var idx in entity.GetIndexes())
                idx.SetDatabaseName(ToSnakeCase(idx.GetDatabaseName()!));
            foreach (var fk in entity.GetForeignKeys())
                fk.SetConstraintName(ToSnakeCase(fk.GetConstraintName()!));
        }
    }

    private static string ToSnakeCase(string name) =>
        string.Concat(name.Select((c, i) => i > 0 && char.IsUpper(c) ? "_" + c : c.ToString())).ToLower();
}
```

- [ ] **Step 2: Create DesignTimeDbContextFactory for migrations**

`backend/Trilho.Infrastructure/Persistence/AppDbContextFactory.cs`:
```csharp
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;
using Npgsql.EntityFrameworkCore.PostgreSQL.Infrastructure;

namespace Trilho.Infrastructure.Persistence;

public class AppDbContextFactory : IDesignTimeDbContextFactory<AppDbContext>
{
    public AppDbContext CreateDbContext(string[] args)
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseNpgsql(
                "Host=localhost;Database=trilho;Username=postgres;Password=postgres",
                o => o.UseNetTopologySuite())
            .Options;
        return new AppDbContext(options);
    }
}
```

- [ ] **Step 3: Create seed data file for SP lines**

`backend/Trilho.Infrastructure/Persistence/Seeds/LinesSeed.cs`:
```csharp
using NetTopologySuite.Geometries;
using Trilho.Domain.Entities;
using Trilho.Domain.Enums;

namespace Trilho.Infrastructure.Persistence.Seeds;

public static class LinesSeed
{
    private static readonly GeometryFactory GeoFactory =
        NetTopologySuite.NtsGeometryServices.Instance.CreateGeometryFactory(srid: 4326);

    public static readonly Line[] Lines =
    [
        new() { Code = "1-AZUL",  Name = "Linha 1 - Azul",    Type = LineType.Metro, ColorHex = "0044AA", HeadwayPeakSec = 120, HeadwayOffPeakSec = 300 },
        new() { Code = "2-VERDE", Name = "Linha 2 - Verde",   Type = LineType.Metro, ColorHex = "007A4D", HeadwayPeakSec = 120, HeadwayOffPeakSec = 300 },
        new() { Code = "3-VERMELHA", Name = "Linha 3 - Vermelha", Type = LineType.Metro, ColorHex = "EE1C25", HeadwayPeakSec = 90, HeadwayOffPeakSec = 270 },
        new() { Code = "4-AMARELA", Name = "Linha 4 - Amarela", Type = LineType.Metro, ColorHex = "FFD400", HeadwayPeakSec = 120, HeadwayOffPeakSec = 300 },
        new() { Code = "5-LILAS",  Name = "Linha 5 - Lilás",  Type = LineType.Metro, ColorHex = "9B2990", HeadwayPeakSec = 150, HeadwayOffPeakSec = 360 },
        new() { Code = "15-PRATA", Name = "Linha 15 - Prata", Type = LineType.Metro, ColorHex = "9E9E9E", HeadwayPeakSec = 180, HeadwayOffPeakSec = 420 },
        new() { Code = "7-RUBI",   Name = "Linha 7 - Rubi",   Type = LineType.Cptm,  ColorHex = "EE1C25", HeadwayPeakSec = 240, HeadwayOffPeakSec = 600 },
        new() { Code = "8-DIAMANTE", Name = "Linha 8 - Diamante", Type = LineType.Cptm, ColorHex = "9E9E9E", HeadwayPeakSec = 240, HeadwayOffPeakSec = 600 },
        new() { Code = "9-ESMERALDA", Name = "Linha 9 - Esmeralda", Type = LineType.Cptm, ColorHex = "007A4D", HeadwayPeakSec = 240, HeadwayOffPeakSec = 600 },
        new() { Code = "10-TURQUESA", Name = "Linha 10 - Turquesa", Type = LineType.Cptm, ColorHex = "008080", HeadwayPeakSec = 300, HeadwayOffPeakSec = 720 },
        new() { Code = "11-CORAL",  Name = "Linha 11 - Coral",  Type = LineType.Cptm, ColorHex = "F7941D", HeadwayPeakSec = 300, HeadwayOffPeakSec = 720 },
        new() { Code = "12-SAFIRA", Name = "Linha 12 - Safira", Type = LineType.Cptm, ColorHex = "003DA5", HeadwayPeakSec = 300, HeadwayOffPeakSec = 720 },
        new() { Code = "13-JADE",   Name = "Linha 13 - Jade",   Type = LineType.Cptm, ColorHex = "00A859", HeadwayPeakSec = 600, HeadwayOffPeakSec = 900 },
    ];

    /// <summary>
    /// Key stations per line with approximate coordinates (lat, lng).
    /// Extend this list with full station data from GTFS import.
    /// </summary>
    public static Station[] CreateStations(IReadOnlyDictionary<string, int> lineIdsByCode) =>
    [
        // Linha 1 - Azul (Tucuruvi → Jabaquara)
        new() { Name = "Tucuruvi",    LineId = lineIdsByCode["1-AZUL"],  Sequence = 1,  Location = GeoFactory.CreatePoint(new Coordinate(-46.6103, -23.4730)), Capacity = 1200 },
        new() { Name = "Parada Inglesa", LineId = lineIdsByCode["1-AZUL"], Sequence = 2, Location = GeoFactory.CreatePoint(new Coordinate(-46.6142, -23.4811)), Capacity = 900 },
        new() { Name = "Jardim São Paulo", LineId = lineIdsByCode["1-AZUL"], Sequence = 3, Location = GeoFactory.CreatePoint(new Coordinate(-46.6128, -23.4863)), Capacity = 900 },
        new() { Name = "Santana",     LineId = lineIdsByCode["1-AZUL"],  Sequence = 4,  Location = GeoFactory.CreatePoint(new Coordinate(-46.6280, -23.4979)), Capacity = 1400 },
        new() { Name = "Carandiru",   LineId = lineIdsByCode["1-AZUL"],  Sequence = 5,  Location = GeoFactory.CreatePoint(new Coordinate(-46.6281, -23.5082)), Capacity = 1000 },
        new() { Name = "Portuguesa-Tietê", LineId = lineIdsByCode["1-AZUL"], Sequence = 6, Location = GeoFactory.CreatePoint(new Coordinate(-46.6281, -23.5147)), Capacity = 1100 },
        new() { Name = "Armênia",     LineId = lineIdsByCode["1-AZUL"],  Sequence = 7,  Location = GeoFactory.CreatePoint(new Coordinate(-46.6281, -23.5195)), Capacity = 900 },
        new() { Name = "Tiradentes",  LineId = lineIdsByCode["1-AZUL"],  Sequence = 8,  Location = GeoFactory.CreatePoint(new Coordinate(-46.6358, -23.5325)), Capacity = 1000 },
        new() { Name = "Luz",         LineId = lineIdsByCode["1-AZUL"],  Sequence = 9,  Location = GeoFactory.CreatePoint(new Coordinate(-46.6336, -23.5358)), Capacity = 2500 },
        new() { Name = "São Bento",   LineId = lineIdsByCode["1-AZUL"],  Sequence = 10, Location = GeoFactory.CreatePoint(new Coordinate(-46.6336, -23.5434)), Capacity = 2000 },
        new() { Name = "Sé",          LineId = lineIdsByCode["1-AZUL"],  Sequence = 11, Location = GeoFactory.CreatePoint(new Coordinate(-46.6336, -23.5497)), Capacity = 3500 },
        new() { Name = "Liberdade",   LineId = lineIdsByCode["1-AZUL"],  Sequence = 12, Location = GeoFactory.CreatePoint(new Coordinate(-46.6336, -23.5577)), Capacity = 2000 },
        new() { Name = "São Judas",   LineId = lineIdsByCode["1-AZUL"],  Sequence = 13, Location = GeoFactory.CreatePoint(new Coordinate(-46.6336, -23.5651)), Capacity = 1100 },
        new() { Name = "Saúde",       LineId = lineIdsByCode["1-AZUL"],  Sequence = 14, Location = GeoFactory.CreatePoint(new Coordinate(-46.6335, -23.5731)), Capacity = 1200 },
        new() { Name = "Praça da Árvore", LineId = lineIdsByCode["1-AZUL"], Sequence = 15, Location = GeoFactory.CreatePoint(new Coordinate(-46.6334, -23.5821)), Capacity = 1000 },
        new() { Name = "Santa Cruz",  LineId = lineIdsByCode["1-AZUL"],  Sequence = 16, Location = GeoFactory.CreatePoint(new Coordinate(-46.6334, -23.5916)), Capacity = 1400 },
        new() { Name = "Chácara Klabin", LineId = lineIdsByCode["1-AZUL"], Sequence = 17, Location = GeoFactory.CreatePoint(new Coordinate(-46.6254, -23.5967)), Capacity = 1100 },
        new() { Name = "Ana Rosa",    LineId = lineIdsByCode["1-AZUL"],  Sequence = 18, Location = GeoFactory.CreatePoint(new Coordinate(-46.6474, -23.5941)), Capacity = 2000 },
        new() { Name = "Paraíso",     LineId = lineIdsByCode["1-AZUL"],  Sequence = 19, Location = GeoFactory.CreatePoint(new Coordinate(-46.6533, -23.5888)), Capacity = 2200 },
        new() { Name = "Brigadeiro",  LineId = lineIdsByCode["1-AZUL"],  Sequence = 20, Location = GeoFactory.CreatePoint(new Coordinate(-46.6533, -23.5820)), Capacity = 1800 },
        new() { Name = "Trianon-Masp", LineId = lineIdsByCode["1-AZUL"], Sequence = 21, Location = GeoFactory.CreatePoint(new Coordinate(-46.6533, -23.5658)), Capacity = 1500 },
        new() { Name = "Consolação",  LineId = lineIdsByCode["1-AZUL"],  Sequence = 22, Location = GeoFactory.CreatePoint(new Coordinate(-46.6533, -23.5570)), Capacity = 1600 },
        new() { Name = "Paulista",    LineId = lineIdsByCode["1-AZUL"],  Sequence = 23, Location = GeoFactory.CreatePoint(new Coordinate(-46.6472, -23.5622)), Capacity = 2800 },
        new() { Name = "Jabaquara",   LineId = lineIdsByCode["1-AZUL"],  Sequence = 24, Location = GeoFactory.CreatePoint(new Coordinate(-46.6334, -23.6678)), Capacity = 2000 },

        // Linha 3 - Vermelha (key stations only — extend with GTFS)
        new() { Name = "Palmeiras-Barra Funda", LineId = lineIdsByCode["3-VERMELHA"], Sequence = 1, Location = GeoFactory.CreatePoint(new Coordinate(-46.6541, -23.5268)), Capacity = 2500 },
        new() { Name = "Marechal Deodoro", LineId = lineIdsByCode["3-VERMELHA"], Sequence = 2, Location = GeoFactory.CreatePoint(new Coordinate(-46.6456, -23.5319)), Capacity = 1400 },
        new() { Name = "Santa Cecília", LineId = lineIdsByCode["3-VERMELHA"], Sequence = 3, Location = GeoFactory.CreatePoint(new Coordinate(-46.6418, -23.5352)), Capacity = 1300 },
        new() { Name = "República",   LineId = lineIdsByCode["3-VERMELHA"], Sequence = 4,  Location = GeoFactory.CreatePoint(new Coordinate(-46.6393, -23.5435)), Capacity = 3000 },
        new() { Name = "Pedro II",    LineId = lineIdsByCode["3-VERMELHA"], Sequence = 5,  Location = GeoFactory.CreatePoint(new Coordinate(-46.6358, -23.5469)), Capacity = 1500 },
        new() { Name = "Brás",        LineId = lineIdsByCode["3-VERMELHA"], Sequence = 6,  Location = GeoFactory.CreatePoint(new Coordinate(-46.6180, -23.5471)), Capacity = 2000 },
        new() { Name = "Belém",       LineId = lineIdsByCode["3-VERMELHA"], Sequence = 7,  Location = GeoFactory.CreatePoint(new Coordinate(-46.5956, -23.5477)), Capacity = 1200 },
        new() { Name = "Tatuapé",     LineId = lineIdsByCode["3-VERMELHA"], Sequence = 8,  Location = GeoFactory.CreatePoint(new Coordinate(-46.5764, -23.5471)), Capacity = 2200 },
        new() { Name = "Carrão",      LineId = lineIdsByCode["3-VERMELHA"], Sequence = 9,  Location = GeoFactory.CreatePoint(new Coordinate(-46.5601, -23.5471)), Capacity = 1200 },
        new() { Name = "Penha",       LineId = lineIdsByCode["3-VERMELHA"], Sequence = 10, Location = GeoFactory.CreatePoint(new Coordinate(-46.5446, -23.5290)), Capacity = 1400 },
        new() { Name = "Guilhermina-Esperança", LineId = lineIdsByCode["3-VERMELHA"], Sequence = 11, Location = GeoFactory.CreatePoint(new Coordinate(-46.5341, -23.5196)), Capacity = 1000 },
        new() { Name = "Patriarca",   LineId = lineIdsByCode["3-VERMELHA"], Sequence = 12, Location = GeoFactory.CreatePoint(new Coordinate(-46.5241, -23.5100)), Capacity = 1000 },
        new() { Name = "Artur Alvim", LineId = lineIdsByCode["3-VERMELHA"], Sequence = 13, Location = GeoFactory.CreatePoint(new Coordinate(-46.5133, -23.5023)), Capacity = 1100 },
        new() { Name = "Corinthians-Itaquera", LineId = lineIdsByCode["3-VERMELHA"], Sequence = 14, Location = GeoFactory.CreatePoint(new Coordinate(-46.4968, -23.5448)), Capacity = 3000 },

        // Linha 2 - Verde (key stations)
        new() { Name = "Vila Madalena", LineId = lineIdsByCode["2-VERDE"], Sequence = 1, Location = GeoFactory.CreatePoint(new Coordinate(-46.6924, -23.5567)), Capacity = 1400 },
        new() { Name = "Sumaré",      LineId = lineIdsByCode["2-VERDE"], Sequence = 2,  Location = GeoFactory.CreatePoint(new Coordinate(-46.6793, -23.5512)), Capacity = 1000 },
        new() { Name = "Clínicas",    LineId = lineIdsByCode["2-VERDE"], Sequence = 3,  Location = GeoFactory.CreatePoint(new Coordinate(-46.6691, -23.5559)), Capacity = 1200 },
        new() { Name = "Consolação",  LineId = lineIdsByCode["2-VERDE"], Sequence = 4,  Location = GeoFactory.CreatePoint(new Coordinate(-46.6533, -23.5570)), Capacity = 1600 },
        new() { Name = "Trianon-Masp", LineId = lineIdsByCode["2-VERDE"], Sequence = 5, Location = GeoFactory.CreatePoint(new Coordinate(-46.6533, -23.5658)), Capacity = 1500 },
        new() { Name = "Brigadeiro",  LineId = lineIdsByCode["2-VERDE"], Sequence = 6,  Location = GeoFactory.CreatePoint(new Coordinate(-46.6533, -23.5820)), Capacity = 1800 },
        new() { Name = "Paraíso",     LineId = lineIdsByCode["2-VERDE"], Sequence = 7,  Location = GeoFactory.CreatePoint(new Coordinate(-46.6533, -23.5888)), Capacity = 2200 },
        new() { Name = "Ana Rosa",    LineId = lineIdsByCode["2-VERDE"], Sequence = 8,  Location = GeoFactory.CreatePoint(new Coordinate(-46.6474, -23.5941)), Capacity = 2000 },
        new() { Name = "Chácara Klabin", LineId = lineIdsByCode["2-VERDE"], Sequence = 9, Location = GeoFactory.CreatePoint(new Coordinate(-46.6254, -23.5967)), Capacity = 1100 },
        new() { Name = "Alto do Ipiranga", LineId = lineIdsByCode["2-VERDE"], Sequence = 10, Location = GeoFactory.CreatePoint(new Coordinate(-46.6096, -23.5936)), Capacity = 1000 },
        new() { Name = "Sacomã",      LineId = lineIdsByCode["2-VERDE"], Sequence = 11, Location = GeoFactory.CreatePoint(new Coordinate(-46.5996, -23.5976)), Capacity = 1200 },
        new() { Name = "Tamanduateí", LineId = lineIdsByCode["2-VERDE"], Sequence = 12, Location = GeoFactory.CreatePoint(new Coordinate(-46.5812, -23.5917)), Capacity = 1400 },
        new() { Name = "Vila Prudente", LineId = lineIdsByCode["2-VERDE"], Sequence = 13, Location = GeoFactory.CreatePoint(new Coordinate(-46.5704, -23.5858)), Capacity = 1200 },
    ];
}
```

- [ ] **Step 4: Create database seeder service**

`backend/Trilho.Infrastructure/Persistence/Seeds/DatabaseSeeder.cs`:
```csharp
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Trilho.Domain.Enums;

namespace Trilho.Infrastructure.Persistence.Seeds;

public class DatabaseSeeder(AppDbContext db, ILogger<DatabaseSeeder> logger)
{
    public async Task SeedAsync(CancellationToken ct = default)
    {
        await db.Database.MigrateAsync(ct);

        if (await db.Lines.AnyAsync(ct))
        {
            logger.LogInformation("Database already seeded, skipping.");
            return;
        }

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
        var demands = new List<Trilho.Domain.Entities.HistoricalDemand>();
        var rng = new Random(42);

        foreach (var station in stations)
        {
            foreach (DayType dayType in Enum.GetValues<DayType>())
            {
                for (short hour = 0; hour <= 23; hour++)
                {
                    // Rough passenger curve based on transit patterns
                    double peakFactor = dayType switch
                    {
                        DayType.Weekday => HourlyWeekdayFactor(hour),
                        DayType.Saturday => HourlySaturdayFactor(hour),
                        _ => HourlySundayFactor(hour)
                    };
                    int avg = (int)(station.Capacity * peakFactor * (0.85 + rng.NextDouble() * 0.3));
                    demands.Add(new()
                    {
                        StationId = station.Id,
                        DayType = dayType,
                        Hour = hour,
                        AvgPassengers = Math.Min(avg, station.Capacity)
                    });
                }
            }
        }

        db.HistoricalDemands.AddRange(demands);
        await db.SaveChangesAsync(ct);
    }

    private static double HourlyWeekdayFactor(short h) => h switch
    {
        >= 6 and <= 9   => 0.75 + (h - 6) * 0.08,   // morning peak
        >= 10 and <= 16 => 0.55,                       // off-peak
        >= 17 and <= 20 => 0.85,                       // evening peak
        >= 21 and <= 23 => 0.35,
        _               => 0.10
    };

    private static double HourlySaturdayFactor(short h) => h switch
    {
        >= 8 and <= 20 => 0.55,
        _              => 0.15
    };

    private static double HourlySundayFactor(short h) => h switch
    {
        >= 9 and <= 19 => 0.40,
        _              => 0.10
    };
}
```

- [ ] **Step 5: Create initial EF migration** (requires PostGIS running — skip if no DB yet; migration file is generated)

```bash
cd C:/Users/jonas/OneDrive/Documentos/Projetos/Transit/backend
dotnet ef migrations add InitialCreate --project Trilho.Infrastructure --startup-project Trilho.API --output-dir Persistence/Migrations
```

Note: If PostGIS is not running locally, use `--no-build` and set connection string env var to a running instance, or run Docker first (Chunk 2 Task 8).

- [ ] **Step 6: Commit scaffolding + domain**

```bash
cd C:/Users/jonas/OneDrive/Documentos/Projetos/Transit
git add backend/
git commit -m "feat: scaffold Trilho backend solution with domain entities and EF context"
```

---

## Chunk 2: Infrastructure — Workers, Scrapers & Data Sources

### Task 4: OlhoVivo HTTP Client

**Files:**
- Create: `backend/Trilho.Infrastructure/DataSources/OlhoVivoClient.cs`
- Create: `backend/Trilho.Infrastructure/DataSources/OlhoVivoModels.cs`

- [ ] **Step 1: Write test for OlhoVivoClient auth retry**

`backend/Trilho.Tests/DataSources/OlhoVivoClientTests.cs`:
```csharp
using FluentAssertions;
using Trilho.Infrastructure.DataSources;
using Xunit;

namespace Trilho.Tests.DataSources;

public class OlhoVivoClientTests
{
    [Fact]
    public void ParseVehiclePosition_ValidJson_ReturnsPositions()
    {
        const string json = """
        {
          "hr": "10:30",
          "l": [
            {
              "c": "8000",
              "cl": 34041,
              "sl": 1,
              "lt0": "PCA.SE",
              "lt1": "TERM.LAPA",
              "qv": 2,
              "vs": [
                { "p": 123456, "a": true, "ta": "2024-01-01 10:30:00", "py": -23.5505, "px": -46.6333 }
              ]
            }
          ]
        }
        """;

        var positions = OlhoVivoClient.ParsePositions(json);

        positions.Should().HaveCount(1);
        positions[0].LineCode.Should().Be("8000");
        positions[0].Lat.Should().BeApproximately(-23.5505, 0.0001);
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd C:/Users/jonas/OneDrive/Documentos/Projetos/Transit/backend
dotnet test Trilho.Tests --filter "OlhoVivoClientTests" -v minimal
```
Expected: FAIL (OlhoVivoClient not defined yet)

- [ ] **Step 3: Implement OlhoVivoModels**

`backend/Trilho.Infrastructure/DataSources/OlhoVivoModels.cs`:
```csharp
using System.Text.Json.Serialization;

namespace Trilho.Infrastructure.DataSources;

public record OlhoVivoPosition(
    [property: JsonPropertyName("p")] int VehicleId,
    [property: JsonPropertyName("a")] bool Accessible,
    [property: JsonPropertyName("py")] double Lat,
    [property: JsonPropertyName("px")] double Lng,
    [property: JsonPropertyName("ta")] string UpdatedAt
);

public record OlhoVivoLine(
    [property: JsonPropertyName("c")]  string LineCode,
    [property: JsonPropertyName("cl")] int LineId,
    [property: JsonPropertyName("qv")] int VehicleCount,
    [property: JsonPropertyName("vs")] List<OlhoVivoPosition> Vehicles
);

public record OlhoVivoPositionResponse(
    [property: JsonPropertyName("hr")] string Hour,
    [property: JsonPropertyName("l")]  List<OlhoVivoLine> Lines
);

public record BusVehiclePosition(string LineCode, int VehicleId, double Lat, double Lng, DateTimeOffset UpdatedAt);
```

- [ ] **Step 4: Implement OlhoVivoClient**

`backend/Trilho.Infrastructure/DataSources/OlhoVivoClient.cs`:
```csharp
using System.Net;
using System.Text.Json;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace Trilho.Infrastructure.DataSources;

public class OlhoVivoOptions
{
    public string Token { get; set; } = string.Empty;
    public string BaseUrl { get; set; } = "https://api.olhovivo.sptrans.com.br/v2.1";
}

public class OlhoVivoClient(
    HttpClient http,
    IOptions<OlhoVivoOptions> opts,
    ILogger<OlhoVivoClient> logger)
{
    private bool _authenticated = false;

    public async Task<List<BusVehiclePosition>> GetAllVehiclePositionsAsync(CancellationToken ct = default)
    {
        if (!_authenticated)
            await AuthenticateAsync(ct);

        var response = await http.GetAsync("/Posicao", ct);

        if (response.StatusCode == HttpStatusCode.Unauthorized)
        {
            _authenticated = false;
            await AuthenticateAsync(ct);
            response = await http.GetAsync("/Posicao", ct);
        }

        response.EnsureSuccessStatusCode();
        var json = await response.Content.ReadAsStringAsync(ct);
        return ParsePositions(json);
    }

    private async Task AuthenticateAsync(CancellationToken ct)
    {
        var url = $"/Login/Autenticar?token={opts.Value.Token}";
        var resp = await http.PostAsync(url, null, ct);
        resp.EnsureSuccessStatusCode();
        _authenticated = true;
        logger.LogInformation("OlhoVivo authenticated successfully.");
    }

    public static List<BusVehiclePosition> ParsePositions(string json)
    {
        var root = JsonSerializer.Deserialize<OlhoVivoPositionResponse>(json);
        if (root?.Lines is null) return [];

        return root.Lines
            .SelectMany(line => line.Vehicles.Select(v => new BusVehiclePosition(
                line.LineCode,
                v.VehicleId,
                v.Lat,
                v.Lng,
                DateTimeOffset.TryParse(v.UpdatedAt, out var dt) ? dt : DateTimeOffset.UtcNow
            )))
            .ToList();
    }
}
```

- [ ] **Step 5: Run test to verify it passes**

```bash
cd C:/Users/jonas/OneDrive/Documentos/Projetos/Transit/backend
dotnet test Trilho.Tests --filter "OlhoVivoClientTests" -v minimal
```
Expected: PASS

---

### Task 5: Metrô SP & CPTM Scrapers

**Files:**
- Create: `backend/Trilho.Infrastructure/DataSources/MetroSpScraper.cs`
- Create: `backend/Trilho.Infrastructure/DataSources/CptmScraper.cs`

- [ ] **Step 1: Write scraper tests**

`backend/Trilho.Tests/DataSources/ScraperTests.cs`:
```csharp
using FluentAssertions;
using Trilho.Domain.Enums;
using Trilho.Infrastructure.DataSources;
using Xunit;

namespace Trilho.Tests.DataSources;

public class MetroSpScraperTests
{
    [Fact]
    public void ParseStatus_NormalStatus_ReturnsNormal()
    {
        // Simplified HTML that matches Metro SP structure
        const string html = """
        <div class="linha-status">
          <span class="linha">1-AZUL</span>
          <span class="status">Operação Normal</span>
        </div>
        """;

        var result = MetroSpScraper.ParseHtml(html);

        result.Should().NotBeEmpty();
    }

    [Fact]
    public void MapStatus_OperacaoNormal_ReturnsNormal()
    {
        var status = MetroSpScraper.MapStatus("Operação Normal");
        status.Should().Be(OperationalStatus.Normal);
    }

    [Fact]
    public void MapStatus_VelocidadeReduzida_ReturnsReducedSpeed()
    {
        var status = MetroSpScraper.MapStatus("Velocidade Reduzida");
        status.Should().Be(OperationalStatus.ReducedSpeed);
    }

    [Fact]
    public void MapStatus_Paralisada_ReturnsSuspended()
    {
        var status = MetroSpScraper.MapStatus("Paralisada");
        status.Should().Be(OperationalStatus.Suspended);
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd C:/Users/jonas/OneDrive/Documentos/Projetos/Transit/backend
dotnet test Trilho.Tests --filter "MetroSpScraperTests" -v minimal
```
Expected: FAIL

- [ ] **Step 3: Implement MetroSpScraper**

`backend/Trilho.Infrastructure/DataSources/MetroSpScraper.cs`:
```csharp
using HtmlAgilityPack;
using Microsoft.Extensions.Logging;
using Trilho.Domain.Enums;
using Trilho.Domain.Interfaces;

namespace Trilho.Infrastructure.DataSources;

public class MetroSpScraper(HttpClient http, ILogger<MetroSpScraper> logger) : ILineStatusScraper
{
    private const string Url = "https://www.metro.sp.gov.br/sistemas/direto-do-metro-via4/index.aspx";

    public async Task<IEnumerable<ScrapedLineStatus>> ScrapeAsync(CancellationToken ct = default)
    {
        try
        {
            var html = await http.GetStringAsync(Url, ct);
            return ParseHtml(html);
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Failed to scrape Metrô SP status page.");
            return [];
        }
    }

    public static IEnumerable<ScrapedLineStatus> ParseHtml(string html)
    {
        var doc = new HtmlDocument();
        doc.LoadHtml(html);

        var results = new List<ScrapedLineStatus>();

        // The Metro SP page uses a table with line statuses.
        // We look for elements containing line codes and status text.
        var nodes = doc.DocumentNode
            .SelectNodes("//div[contains(@class,'linha-status') or contains(@class,'status-linha')]");

        if (nodes is null) return results;

        foreach (var node in nodes)
        {
            var linhaNode = node.SelectSingleNode(".//span[contains(@class,'linha') or contains(@class,'numero')]");
            var statusNode = node.SelectSingleNode(".//span[contains(@class,'status') or contains(@class,'situacao')]");
            var msgNode = node.SelectSingleNode(".//span[contains(@class,'message') or contains(@class,'descricao')]");

            if (linhaNode is null || statusNode is null) continue;

            var lineCode = NormalizeLineCode(linhaNode.InnerText.Trim());
            var status = MapStatus(statusNode.InnerText.Trim());
            var message = msgNode?.InnerText.Trim();

            if (!string.IsNullOrEmpty(lineCode))
                results.Add(new ScrapedLineStatus(lineCode, status, message));
        }

        return results;
    }

    public static OperationalStatus MapStatus(string text) =>
        text.ToLower() switch
        {
            var t when t.Contains("normal")     => OperationalStatus.Normal,
            var t when t.Contains("reduzida")   => OperationalStatus.ReducedSpeed,
            var t when t.Contains("parcial")    => OperationalStatus.Partial,
            var t when t.Contains("paralisada") || t.Contains("interrompida") => OperationalStatus.Suspended,
            _                                   => OperationalStatus.Normal
        };

    private static string NormalizeLineCode(string raw)
    {
        // Accept formats like "Linha 1 - Azul", "1-AZUL", "1 - Azul"
        var map = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        {
            ["1"] = "1-AZUL", ["2"] = "2-VERDE", ["3"] = "3-VERMELHA",
            ["4"] = "4-AMARELA", ["5"] = "5-LILAS", ["15"] = "15-PRATA"
        };
        foreach (var (key, code) in map)
            if (raw.Contains(key)) return code;
        return string.Empty;
    }
}
```

- [ ] **Step 4: Implement CptmScraper**

`backend/Trilho.Infrastructure/DataSources/CptmScraper.cs`:
```csharp
using HtmlAgilityPack;
using Microsoft.Extensions.Logging;
using Trilho.Domain.Enums;
using Trilho.Domain.Interfaces;

namespace Trilho.Infrastructure.DataSources;

public class CptmScraper(HttpClient http, ILogger<CptmScraper> logger) : ILineStatusScraper
{
    private const string Url = "https://www.cptm.sp.gov.br/sua-viagem/Pages/operacao.aspx";

    public async Task<IEnumerable<ScrapedLineStatus>> ScrapeAsync(CancellationToken ct = default)
    {
        try
        {
            var html = await http.GetStringAsync(Url, ct);
            return ParseHtml(html);
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Failed to scrape CPTM status page.");
            return [];
        }
    }

    public static IEnumerable<ScrapedLineStatus> ParseHtml(string html)
    {
        var doc = new HtmlDocument();
        doc.LoadHtml(html);

        var results = new List<ScrapedLineStatus>();

        var nodes = doc.DocumentNode
            .SelectNodes("//div[contains(@class,'linha') or contains(@class,'line-status')]");

        if (nodes is null) return results;

        foreach (var node in nodes)
        {
            var text = node.InnerText;
            var lineCode = ExtractCptmLine(text);
            if (string.IsNullOrEmpty(lineCode)) continue;

            var status = MetroSpScraper.MapStatus(text);
            results.Add(new ScrapedLineStatus(lineCode, status, null));
        }

        return results;
    }

    private static string ExtractCptmLine(string text)
    {
        var codes = new[] { "7", "8", "9", "10", "11", "12", "13" };
        var names = new Dictionary<string, string>
        {
            ["7"] = "7-RUBI", ["8"] = "8-DIAMANTE", ["9"] = "9-ESMERALDA",
            ["10"] = "10-TURQUESA", ["11"] = "11-CORAL", ["12"] = "12-SAFIRA", ["13"] = "13-JADE"
        };
        foreach (var code in codes)
            if (text.Contains($"Linha {code}") || text.Contains($"{code}-"))
                return names[code];
        return string.Empty;
    }
}
```

- [ ] **Step 5: Add Cittamobi placeholder**

`backend/Trilho.Infrastructure/DataSources/CitamobiProvider.cs`:
```csharp
using Microsoft.Extensions.Logging;
using Trilho.Domain.Interfaces;

namespace Trilho.Infrastructure.DataSources;

/// <summary>
/// TODO: Reverse-engineer Cittamobi API via mitmproxy to discover real CPTM train position endpoints.
/// Cittamobi has official CPTM partnership since March 2025.
/// Fallback: returns empty collection, causing CrowdInference to use GTFS schedule + status weight.
/// </summary>
public class CitamobiProvider(ILogger<CitamobiProvider> logger) : ITrainPositionProvider
{
    public Task<IEnumerable<TrainPosition>> GetPositionsAsync(CancellationToken ct = default)
    {
        // TODO: implement after mitmproxy reverse engineering
        logger.LogDebug("CitamobiProvider: not yet implemented, returning empty positions.");
        return Task.FromResult(Enumerable.Empty<TrainPosition>());
    }
}
```

- [ ] **Step 6: Run all scraper tests**

```bash
cd C:/Users/jonas/OneDrive/Documentos/Projetos/Transit/backend
dotnet test Trilho.Tests --filter "ScraperTests" -v minimal
```
Expected: PASS

---

### Task 6: Background Workers

**Files:**
- Create: `backend/Trilho.Infrastructure/Workers/LineStatusWorker.cs`
- Create: `backend/Trilho.Infrastructure/Workers/BusPositionWorker.cs`
- Create: `backend/Trilho.Infrastructure/Workers/CrowdInferenceWorker.cs`
- Create: `backend/Trilho.Infrastructure/Workers/UserPingCleanupWorker.cs`

- [ ] **Step 1: Write test for CrowdInference logic**

`backend/Trilho.Tests/Workers/CrowdInferenceTests.cs`:
```csharp
using FluentAssertions;
using Trilho.Domain.Enums;
using Trilho.Infrastructure.Workers;
using Xunit;

namespace Trilho.Tests.Workers;

public class CrowdInferenceTests
{
    [Theory]
    [InlineData(200, 1000, OperationalStatus.Normal,       DensityLevel.Low)]
    [InlineData(550, 1000, OperationalStatus.Normal,       DensityLevel.Medium)]
    [InlineData(700, 1000, OperationalStatus.Normal,       DensityLevel.High)]
    [InlineData(900, 1000, OperationalStatus.Normal,       DensityLevel.Packed)]
    [InlineData(500, 1000, OperationalStatus.ReducedSpeed, DensityLevel.High)]   // 0.5 * 1.4 = 0.70
    [InlineData(400, 1000, OperationalStatus.Suspended,    DensityLevel.Packed)] // 0.4 * 2.5 = 1.00
    public void Infer_GivenInputs_ReturnsExpectedLevel(
        int avgPassengers, int capacity, OperationalStatus opStatus, DensityLevel expected)
    {
        var result = CrowdInferenceEngine.Infer(avgPassengers, capacity, opStatus);
        result.Level.Should().Be(expected);
    }

    [Fact]
    public void Infer_ScoreNeverExceedsOne()
    {
        var result = CrowdInferenceEngine.Infer(1000, 1000, OperationalStatus.Suspended);
        result.Score.Should().BeLessOrEqualTo(1.0m);
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd C:/Users/jonas/OneDrive/Documentos/Projetos/Transit/backend
dotnet test Trilho.Tests --filter "CrowdInferenceTests" -v minimal
```
Expected: FAIL

- [ ] **Step 3: Implement CrowdInferenceEngine**

`backend/Trilho.Infrastructure/Workers/CrowdInferenceEngine.cs`:
```csharp
using Trilho.Domain.Enums;

namespace Trilho.Infrastructure.Workers;

public record InferenceResult(decimal Score, DensityLevel Level);

public static class CrowdInferenceEngine
{
    public static InferenceResult Infer(int avgPassengers, int capacity, OperationalStatus status)
    {
        double baseRatio = (double)avgPassengers / capacity;

        double weight = status switch
        {
            OperationalStatus.ReducedSpeed => 1.4,
            OperationalStatus.Partial      => 1.8,
            OperationalStatus.Suspended    => 2.5,
            _                              => 1.0
        };

        decimal score = (decimal)Math.Min(baseRatio * weight, 1.0);

        DensityLevel level = score switch
        {
            < 0.30m => DensityLevel.Low,
            < 0.60m => DensityLevel.Medium,
            < 0.85m => DensityLevel.High,
            _       => DensityLevel.Packed
        };

        return new InferenceResult(score, level);
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd C:/Users/jonas/OneDrive/Documentos/Projetos/Transit/backend
dotnet test Trilho.Tests --filter "CrowdInferenceTests" -v minimal
```
Expected: PASS

- [ ] **Step 5: Implement LineStatusWorker**

`backend/Trilho.Infrastructure/Workers/LineStatusWorker.cs`:
```csharp
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Trilho.Domain.Entities;
using Trilho.Domain.Interfaces;
using Trilho.Infrastructure.Persistence;

namespace Trilho.Infrastructure.Workers;

public class LineStatusWorker(
    IServiceScopeFactory scopeFactory,
    IEnumerable<ILineStatusScraper> scrapers,
    ILogger<LineStatusWorker> logger) : BackgroundService
{
    private static readonly TimeSpan Interval = TimeSpan.FromMinutes(2);

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        logger.LogInformation("LineStatusWorker started.");
        while (!stoppingToken.IsCancellationRequested)
        {
            await RunAsync(stoppingToken);
            await Task.Delay(Interval, stoppingToken);
        }
    }

    private async Task RunAsync(CancellationToken ct)
    {
        using var scope = scopeFactory.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();

        var lines = await db.Lines.ToDictionaryAsync(l => l.Code, ct);

        foreach (var scraper in scrapers)
        {
            try
            {
                var statuses = await scraper.ScrapeAsync(ct);
                foreach (var s in statuses)
                {
                    if (!lines.TryGetValue(s.LineCode, out var line)) continue;
                    db.LineStatuses.Add(new LineStatusEntry
                    {
                        LineId = line.Id,
                        Status = s.Status,
                        Message = s.Message,
                        SourceUrl = null,
                        CapturedAt = DateTimeOffset.UtcNow
                    });
                }
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Error in scraper {Scraper}", scraper.GetType().Name);
            }
        }

        await db.SaveChangesAsync(ct);
        logger.LogDebug("LineStatusWorker: statuses updated at {Time}", DateTimeOffset.UtcNow);
    }
}
```

- [ ] **Step 6: Implement CrowdInferenceWorker**

`backend/Trilho.Infrastructure/Workers/CrowdInferenceWorker.cs`:
```csharp
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Trilho.Domain.Entities;
using Trilho.Domain.Enums;
using Trilho.Infrastructure.Persistence;

namespace Trilho.Infrastructure.Workers;

public class CrowdInferenceWorker(
    IServiceScopeFactory scopeFactory,
    ILogger<CrowdInferenceWorker> logger) : BackgroundService
{
    private static readonly TimeSpan Interval = TimeSpan.FromMinutes(1);

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        logger.LogInformation("CrowdInferenceWorker started.");
        while (!stoppingToken.IsCancellationRequested)
        {
            await RunAsync(stoppingToken);
            await Task.Delay(Interval, stoppingToken);
        }
    }

    private async Task RunAsync(CancellationToken ct)
    {
        using var scope = scopeFactory.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();

        var now = DateTimeOffset.UtcNow;
        var dayType = now.DayOfWeek switch
        {
            DayOfWeek.Saturday => DayType.Saturday,
            DayOfWeek.Sunday   => DayType.Sunday,
            _                  => DayType.Weekday
        };
        short hour = (short)now.Hour;

        var stations = await db.Stations
            .Include(s => s.Line)
            .ToListAsync(ct);

        var latestStatusByLine = await db.LineStatuses
            .GroupBy(s => s.LineId)
            .Select(g => g.OrderByDescending(s => s.CapturedAt).First())
            .ToDictionaryAsync(s => s.LineId, ct);

        var historicalByStation = await db.HistoricalDemands
            .Where(h => h.DayType == dayType && h.Hour == hour)
            .ToDictionaryAsync(h => h.StationId, ct);

        var snapshots = new List<CrowdSnapshot>();

        foreach (var station in stations)
        {
            if (!historicalByStation.TryGetValue(station.Id, out var hist)) continue;

            var opStatus = latestStatusByLine.TryGetValue(station.LineId, out var ls)
                ? ls.Status
                : OperationalStatus.Normal;

            var result = CrowdInferenceEngine.Infer(hist.AvgPassengers, station.Capacity, opStatus);

            snapshots.Add(new CrowdSnapshot
            {
                StationId = station.Id,
                UserCount = 0,
                InferredDensity = result.Score,
                DensityLevel = result.Level,
                Source = CrowdSource.Historical,
                CapturedAt = now
            });
        }

        db.CrowdSnapshots.AddRange(snapshots);
        await db.SaveChangesAsync(ct);
        logger.LogDebug("CrowdInferenceWorker: {Count} snapshots written.", snapshots.Count);
    }
}
```

- [ ] **Step 7: Implement BusPositionWorker**

`backend/Trilho.Infrastructure/Workers/BusPositionWorker.cs`:
```csharp
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Trilho.Infrastructure.DataSources;
using StackExchange.Redis;

namespace Trilho.Infrastructure.Workers;

public class BusPositionWorker(
    OlhoVivoClient olhoVivo,
    IConnectionMultiplexer redis,
    ILogger<BusPositionWorker> logger) : BackgroundService
{
    private static readonly TimeSpan Interval = TimeSpan.FromSeconds(30);

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        logger.LogInformation("BusPositionWorker started.");
        while (!stoppingToken.IsCancellationRequested)
        {
            await RunAsync(stoppingToken);
            await Task.Delay(Interval, stoppingToken);
        }
    }

    private async Task RunAsync(CancellationToken ct)
    {
        try
        {
            var positions = await olhoVivo.GetAllVehiclePositionsAsync(ct);
            var db = redis.GetDatabase();

            foreach (var pos in positions)
            {
                var key = $"bus:pos:{pos.VehicleId}";
                var value = $"{pos.Lat},{pos.Lng},{pos.LineCode},{pos.UpdatedAt:O}";
                await db.StringSetAsync(key, value, TimeSpan.FromMinutes(2));
            }

            logger.LogDebug("BusPositionWorker: cached {Count} vehicle positions.", positions.Count);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "BusPositionWorker error.");
        }
    }
}
```

- [ ] **Step 8: Implement UserPingCleanupWorker**

`backend/Trilho.Infrastructure/Workers/UserPingCleanupWorker.cs`:
```csharp
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Trilho.Infrastructure.Persistence;

namespace Trilho.Infrastructure.Workers;

public class UserPingCleanupWorker(
    IServiceScopeFactory scopeFactory,
    ILogger<UserPingCleanupWorker> logger) : BackgroundService
{
    private static readonly TimeSpan Interval = TimeSpan.FromMinutes(5);
    private static readonly TimeSpan PingTtl   = TimeSpan.FromMinutes(10);

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            using var scope = scopeFactory.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var cutoff = DateTimeOffset.UtcNow - PingTtl;
            var deleted = await db.UserPings.Where(p => p.CreatedAt < cutoff).ExecuteDeleteAsync(stoppingToken);
            if (deleted > 0)
                logger.LogInformation("UserPingCleanupWorker: deleted {Count} old pings.", deleted);
            await Task.Delay(Interval, stoppingToken);
        }
    }
}
```

- [ ] **Step 9: Create InfrastructureExtensions for DI registration**

`backend/Trilho.Infrastructure/InfrastructureExtensions.cs`:
```csharp
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Polly;
using StackExchange.Redis;
using Trilho.Domain.Interfaces;
using Trilho.Infrastructure.DataSources;
using Trilho.Infrastructure.Persistence;
using Trilho.Infrastructure.Persistence.Seeds;
using Trilho.Infrastructure.Workers;

namespace Trilho.Infrastructure;

public static class InfrastructureExtensions
{
    public static IServiceCollection AddInfrastructure(
        this IServiceCollection services,
        IConfiguration config)
    {
        // PostgreSQL + PostGIS
        services.AddDbContext<AppDbContext>(opts =>
            opts.UseNpgsql(
                config.GetConnectionString("Default"),
                o => o.UseNetTopologySuite()));

        services.AddScoped<DatabaseSeeder>();

        // Redis
        services.AddSingleton<IConnectionMultiplexer>(_ =>
            ConnectionMultiplexer.Connect(config["Redis:Connection"]!));

        // OlhoVivo
        services.Configure<OlhoVivoOptions>(config.GetSection("OlhoVivo"));
        services.AddHttpClient<OlhoVivoClient>(c =>
        {
            c.BaseAddress = new Uri("https://api.olhovivo.sptrans.com.br/v2.1");
        })
        .AddTransientHttpErrorPolicy(p =>
            p.WaitAndRetryAsync(3, retry => TimeSpan.FromSeconds(Math.Pow(2, retry))));

        // Scrapers
        services.AddHttpClient<MetroSpScraper>()
            .AddTransientHttpErrorPolicy(p =>
                p.WaitAndRetryAsync(3, retry => TimeSpan.FromSeconds(Math.Pow(2, retry))));
        services.AddHttpClient<CptmScraper>()
            .AddTransientHttpErrorPolicy(p =>
                p.WaitAndRetryAsync(3, retry => TimeSpan.FromSeconds(Math.Pow(2, retry))));

        services.AddScoped<ILineStatusScraper, MetroSpScraper>();
        services.AddScoped<ILineStatusScraper, CptmScraper>();
        services.AddScoped<ITrainPositionProvider, CitamobiProvider>();

        // Background Workers
        services.AddHostedService<LineStatusWorker>();
        services.AddHostedService<CrowdInferenceWorker>();
        services.AddHostedService<BusPositionWorker>();
        services.AddHostedService<UserPingCleanupWorker>();

        return services;
    }
}
```

- [ ] **Step 10: Commit workers**

```bash
cd C:/Users/jonas/OneDrive/Documentos/Projetos/Transit
git add backend/
git commit -m "feat: add scrapers, OlhoVivo client, and background workers"
```

---

## Chunk 3: API Layer

### Task 7: Program.cs & JWT Auth

**Files:**
- Create/Modify: `backend/Trilho.API/Program.cs`
- Create: `backend/Trilho.API/appsettings.json`
- Create: `backend/Trilho.API/appsettings.Development.json`
- Create: `backend/Trilho.API/Hubs/CrowdHub.cs`
- Create: `backend/Trilho.API/Endpoints/StationEndpoints.cs`
- Create: `backend/Trilho.API/Endpoints/LineEndpoints.cs`
- Create: `backend/Trilho.API/Endpoints/UserEndpoints.cs`
- Create: `backend/Trilho.API/DTOs/*.cs`

- [ ] **Step 1: Create DTOs**

`backend/Trilho.API/DTOs/CrowdDto.cs`:
```csharp
using Trilho.Domain.Enums;

namespace Trilho.API.DTOs;

public record CrowdDto(
    int StationId,
    string StationName,
    decimal Density,
    string DensityLevel,
    string Source,
    DateTimeOffset CapturedAt,
    IEnumerable<CrowdHistoryPoint> History
);

public record CrowdHistoryPoint(decimal Density, string Level, DateTimeOffset CapturedAt);

public record ForecastDto(int Hour, int AvgPassengers, string ExpectedLevel);

public record LineDto(
    int Id,
    string Code,
    string Name,
    string Type,
    string ColorHex,
    string CurrentStatus,
    string? StatusMessage
);

public record LineStatusDto(
    string Code,
    string Status,
    string? Message,
    DateTimeOffset CapturedAt,
    IEnumerable<StationCrowdDto> Stations
);

public record StationCrowdDto(int Id, string Name, string DensityLevel, decimal Density);

public record VehiclePositionDto(int VehicleId, double Lat, double Lng, string LineCode, DateTimeOffset UpdatedAt);

public record RegisterResponseDto(Guid UserId, string Token);

public record UsageDto(int QueriesUsed, int QueriesLimit, bool IsPremium);
```

- [ ] **Step 2: Create CrowdHub**

`backend/Trilho.API/Hubs/CrowdHub.cs`:
```csharp
using Microsoft.AspNetCore.SignalR;

namespace Trilho.API.Hubs;

public class CrowdHub : Hub
{
    /// <summary>
    /// Clients call SubscribeLine to receive CrowdUpdated events for a specific line.
    /// </summary>
    public async Task SubscribeLine(string lineCode)
    {
        await Groups.AddToGroupAsync(Context.ConnectionId, $"line:{lineCode}");
    }

    public async Task UnsubscribeLine(string lineCode)
    {
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, $"line:{lineCode}");
    }
}
```

- [ ] **Step 3: Create StationEndpoints**

`backend/Trilho.API/Endpoints/StationEndpoints.cs`:
```csharp
using Microsoft.EntityFrameworkCore;
using Trilho.API.DTOs;
using Trilho.Infrastructure.Persistence;

namespace Trilho.API.Endpoints;

public static class StationEndpoints
{
    public static IEndpointRouteBuilder MapStationEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapGet("/api/stations/{id:int}/crowd", GetCrowdAsync)
            .WithName("GetStationCrowd")
            .RequireAuthorization();

        app.MapGet("/api/stations/{id:int}/forecast", GetForecastAsync)
            .WithName("GetStationForecast")
            .RequireAuthorization();

        return app;
    }

    private static async Task<IResult> GetCrowdAsync(int id, AppDbContext db, CancellationToken ct)
    {
        var station = await db.Stations.FindAsync([id], ct);
        if (station is null) return Results.NotFound();

        var history = await db.CrowdSnapshots
            .Where(s => s.StationId == id && s.CapturedAt >= DateTimeOffset.UtcNow.AddHours(-3))
            .OrderByDescending(s => s.CapturedAt)
            .Take(30)
            .ToListAsync(ct);

        var latest = history.FirstOrDefault();
        if (latest is null) return Results.NotFound("No crowd data yet.");

        var dto = new CrowdDto(
            id,
            station.Name,
            latest.InferredDensity,
            latest.DensityLevel.ToString(),
            latest.Source.ToString(),
            latest.CapturedAt,
            history.Skip(1).Select(h => new CrowdHistoryPoint(h.InferredDensity, h.DensityLevel.ToString(), h.CapturedAt))
        );

        return Results.Ok(dto);
    }

    private static async Task<IResult> GetForecastAsync(int id, AppDbContext db, CancellationToken ct)
    {
        var station = await db.Stations.FindAsync([id], ct);
        if (station is null) return Results.NotFound();

        var now = DateTimeOffset.UtcNow;
        var dayType = now.DayOfWeek switch
        {
            DayOfWeek.Saturday => "Saturday",
            DayOfWeek.Sunday   => "Sunday",
            _                  => "Weekday"
        };

        var forecast = await db.HistoricalDemands
            .Where(h => h.StationId == id && h.DayType.ToString() == dayType
                        && h.Hour >= now.Hour && h.Hour <= now.Hour + 2)
            .OrderBy(h => h.Hour)
            .ToListAsync(ct);

        var result = forecast.Select(h =>
        {
            double ratio = (double)h.AvgPassengers / station.Capacity;
            string level = ratio switch { < 0.3 => "Low", < 0.6 => "Medium", < 0.85 => "High", _ => "Packed" };
            return new ForecastDto(h.Hour, h.AvgPassengers, level);
        });

        return Results.Ok(result);
    }
}
```

- [ ] **Step 4: Create LineEndpoints**

`backend/Trilho.API/Endpoints/LineEndpoints.cs`:
```csharp
using Microsoft.EntityFrameworkCore;
using StackExchange.Redis;
using Trilho.API.DTOs;
using Trilho.Infrastructure.Persistence;

namespace Trilho.API.Endpoints;

public static class LineEndpoints
{
    public static IEndpointRouteBuilder MapLineEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapGet("/api/lines", GetAllLinesAsync).WithName("GetLines");
        app.MapGet("/api/lines/{code}/status", GetLineStatusAsync).WithName("GetLineStatus");
        app.MapGet("/api/lines/{code}/vehicles", GetLineVehiclesAsync).WithName("GetLineVehicles").RequireAuthorization();
        return app;
    }

    private static async Task<IResult> GetAllLinesAsync(AppDbContext db, CancellationToken ct)
    {
        var lines = await db.Lines.ToListAsync(ct);
        var latestStatuses = await db.LineStatuses
            .GroupBy(s => s.LineId)
            .Select(g => g.OrderByDescending(s => s.CapturedAt).First())
            .ToDictionaryAsync(s => s.LineId, ct);

        var dtos = lines.Select(l =>
        {
            latestStatuses.TryGetValue(l.Id, out var status);
            return new LineDto(l.Id, l.Code, l.Name, l.Type.ToString(), l.ColorHex,
                status?.Status.ToString() ?? "Normal", status?.Message);
        });

        return Results.Ok(dtos);
    }

    private static async Task<IResult> GetLineStatusAsync(string code, AppDbContext db, CancellationToken ct)
    {
        var line = await db.Lines.FirstOrDefaultAsync(l => l.Code == code, ct);
        if (line is null) return Results.NotFound();

        var status = await db.LineStatuses
            .Where(s => s.LineId == line.Id)
            .OrderByDescending(s => s.CapturedAt)
            .FirstOrDefaultAsync(ct);

        var stations = await db.Stations
            .Where(s => s.LineId == line.Id)
            .ToListAsync(ct);

        var stationIds = stations.Select(s => s.Id).ToList();
        var latestCrowd = await db.CrowdSnapshots
            .Where(c => stationIds.Contains(c.StationId))
            .GroupBy(c => c.StationId)
            .Select(g => g.OrderByDescending(c => c.CapturedAt).First())
            .ToDictionaryAsync(c => c.StationId, ct);

        var stationDtos = stations.Select(s =>
        {
            latestCrowd.TryGetValue(s.Id, out var crowd);
            return new StationCrowdDto(s.Id, s.Name,
                crowd?.DensityLevel.ToString() ?? "Low",
                crowd?.InferredDensity ?? 0);
        });

        var dto = new LineStatusDto(line.Code,
            status?.Status.ToString() ?? "Normal",
            status?.Message,
            status?.CapturedAt ?? DateTimeOffset.UtcNow,
            stationDtos);

        return Results.Ok(dto);
    }

    private static async Task<IResult> GetLineVehiclesAsync(
        string code, IConnectionMultiplexer redis, CancellationToken ct)
    {
        var db = redis.GetDatabase();
        var server = redis.GetServer(redis.GetEndPoints().First());
        var keys = server.Keys(pattern: "bus:pos:*").ToArray();

        var vehicles = new List<VehiclePositionDto>();
        foreach (var key in keys)
        {
            var val = await db.StringGetAsync(key);
            if (!val.HasValue) continue;
            var parts = val.ToString().Split(',');
            if (parts.Length < 4) continue;
            if (!parts[2].Equals(code, StringComparison.OrdinalIgnoreCase)) continue;

            if (double.TryParse(parts[0], out var lat) && double.TryParse(parts[1], out var lng))
            {
                var vid = int.TryParse(key.ToString().Split(':').Last(), out var v) ? v : 0;
                vehicles.Add(new VehiclePositionDto(vid, lat, lng, parts[2],
                    DateTimeOffset.TryParse(parts[3], out var dt) ? dt : DateTimeOffset.UtcNow));
            }
        }

        return Results.Ok(vehicles);
    }
}
```

- [ ] **Step 5: Create UserEndpoints**

`backend/Trilho.API/Endpoints/UserEndpoints.cs`:
```csharp
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Trilho.API.DTOs;
using Trilho.Domain.Entities;
using Trilho.Infrastructure.Persistence;

namespace Trilho.API.Endpoints;

public static class UserEndpoints
{
    public static IEndpointRouteBuilder MapUserEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapPost("/api/auth/register", RegisterAsync).WithName("Register");
        app.MapGet("/api/users/me/usage", GetUsageAsync).WithName("GetUsage").RequireAuthorization();
        app.MapPost("/api/users/premium/verify", VerifyPremiumAsync).WithName("VerifyPremium").RequireAuthorization();
        return app;
    }

    private static async Task<IResult> RegisterAsync(AppDbContext db, IConfiguration config, CancellationToken ct)
    {
        var user = new User();
        db.Users.Add(user);
        await db.SaveChangesAsync(ct);

        var token = GenerateJwt(user.Id, config);
        return Results.Ok(new RegisterResponseDto(user.Id, token));
    }

    private static async Task<IResult> GetUsageAsync(ClaimsPrincipal principal, AppDbContext db, CancellationToken ct)
    {
        var userId = GetUserId(principal);
        if (userId == Guid.Empty) return Results.Unauthorized();

        var user = await db.Users.FindAsync([userId], ct);
        if (user is null) return Results.NotFound();

        ResetDailyCountIfNeeded(user);
        await db.SaveChangesAsync(ct);

        return Results.Ok(new UsageDto(user.DailyQueriesUsed, user.IsPremium ? int.MaxValue : 3, user.IsPremium));
    }

    private static async Task<IResult> VerifyPremiumAsync(
        ClaimsPrincipal principal, AppDbContext db, CancellationToken ct)
    {
        // TODO: integrate RevenueCat webhook verification
        // For now, mark user as premium (to be secured with RevenueCat shared secret)
        var userId = GetUserId(principal);
        var user = await db.Users.FindAsync([userId], ct);
        if (user is null) return Results.NotFound();

        user.IsPremium = true;
        await db.SaveChangesAsync(ct);
        return Results.Ok();
    }

    private static void ResetDailyCountIfNeeded(User user)
    {
        var today = DateOnly.FromDateTime(DateTime.UtcNow);
        if (user.QueriesResetAt < today)
        {
            user.DailyQueriesUsed = 0;
            user.QueriesResetAt = today;
        }
    }

    private static string GenerateJwt(Guid userId, IConfiguration config)
    {
        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(config["Jwt:Secret"]!));
        var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);
        var token = new JwtSecurityToken(
            issuer: "trilho",
            audience: "trilho",
            claims: [new Claim(ClaimTypes.NameIdentifier, userId.ToString())],
            expires: DateTime.UtcNow.AddYears(1),
            signingCredentials: creds);
        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    private static Guid GetUserId(ClaimsPrincipal p)
    {
        var id = p.FindFirstValue(ClaimTypes.NameIdentifier);
        return Guid.TryParse(id, out var g) ? g : Guid.Empty;
    }
}
```

- [ ] **Step 6: Create Program.cs**

`backend/Trilho.API/Program.cs`:
```csharp
using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using Trilho.API.Endpoints;
using Trilho.API.Hubs;
using Trilho.Infrastructure;
using Trilho.Infrastructure.Persistence.Seeds;

var builder = WebApplication.CreateBuilder(args);

// Infrastructure (DB, Redis, Workers, Scrapers)
builder.Services.AddInfrastructure(builder.Configuration);

// JWT Auth
var jwtSecret = builder.Configuration["Jwt:Secret"]
    ?? throw new InvalidOperationException("Jwt:Secret not configured.");
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(opts => opts.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuer = true,
        ValidateAudience = true,
        ValidIssuer = "trilho",
        ValidAudience = "trilho",
        IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtSecret))
    });
builder.Services.AddAuthorization();

// SignalR
builder.Services.AddSignalR();

// CORS (for Flutter web / debug)
builder.Services.AddCors(o => o.AddDefaultPolicy(p =>
    p.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod()));

// OpenAPI
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

// Seed database
using (var scope = app.Services.CreateScope())
{
    var seeder = scope.ServiceProvider.GetRequiredService<DatabaseSeeder>();
    await seeder.SeedAsync();
}

app.UseSwagger();
app.UseSwaggerUI();
app.UseCors();
app.UseAuthentication();
app.UseAuthorization();

// Map endpoints
app.MapStationEndpoints();
app.MapLineEndpoints();
app.MapUserEndpoints();

// SignalR hub
app.MapHub<CrowdHub>("/hubs/crowd");

app.Run();
```

- [ ] **Step 7: Create appsettings files**

`backend/Trilho.API/appsettings.json`:
```json
{
  "ConnectionStrings": {
    "Default": "Host=db;Database=trilho;Username=postgres;Password=postgres"
  },
  "Redis": {
    "Connection": "redis:6379"
  },
  "OlhoVivo": {
    "Token": ""
  },
  "Jwt": {
    "Secret": "CHANGE_ME_IN_PRODUCTION_USE_ENV_VAR_32CHARS"
  },
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  }
}
```

`backend/Trilho.API/appsettings.Development.json`:
```json
{
  "ConnectionStrings": {
    "Default": "Host=localhost;Database=trilho;Username=postgres;Password=postgres"
  },
  "Redis": {
    "Connection": "localhost:6379"
  },
  "Logging": {
    "LogLevel": {
      "Default": "Debug",
      "Microsoft.AspNetCore": "Information"
    }
  }
}
```

- [ ] **Step 8: Build API to verify no errors**

```bash
cd C:/Users/jonas/OneDrive/Documentos/Projetos/Transit/backend
dotnet build Trilho.API/Trilho.API.csproj
```
Expected: Build succeeded with 0 errors.

- [ ] **Step 9: Run all backend tests**

```bash
cd C:/Users/jonas/OneDrive/Documentos/Projetos/Transit/backend
dotnet test Trilho.Tests -v minimal
```
Expected: All tests PASS.

- [ ] **Step 10: Commit API layer**

```bash
cd C:/Users/jonas/OneDrive/Documentos/Projetos/Transit
git add backend/
git commit -m "feat: add Minimal API endpoints, JWT auth, SignalR CrowdHub"
```

---

## Chunk 4: Docker Compose & Dockerfile

### Task 8: Docker Infrastructure

**Files:**
- Create: `docker-compose.yml`
- Create: `docker-compose.override.yml`
- Create: `backend/Trilho.API/Dockerfile`
- Create: `.env.example`
- Create: `ROADMAP.md`

- [ ] **Step 1: Create Dockerfile**

`backend/Trilho.API/Dockerfile`:
```dockerfile
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY Trilho.sln ./
COPY Trilho.Domain/Trilho.Domain.csproj Trilho.Domain/
COPY Trilho.Infrastructure/Trilho.Infrastructure.csproj Trilho.Infrastructure/
COPY Trilho.API/Trilho.API.csproj Trilho.API/
RUN dotnet restore Trilho.sln
COPY . .
RUN dotnet publish Trilho.API/Trilho.API.csproj -c Release -o /app/publish

FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app
COPY --from=build /app/publish .
EXPOSE 8080
ENTRYPOINT ["dotnet", "Trilho.API.dll"]
```

- [ ] **Step 2: Create docker-compose.yml**

`docker-compose.yml`:
```yaml
services:
  api:
    build:
      context: ./backend
      dockerfile: Trilho.API/Dockerfile
    ports:
      - "5000:8080"
    environment:
      - ConnectionStrings__Default=Host=db;Database=trilho;Username=postgres;Password=postgres
      - Redis__Connection=redis:6379
      - OlhoVivo__Token=${OLHOVIVO_TOKEN}
      - Jwt__Secret=${JWT_SECRET}
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_started
    restart: unless-stopped

  db:
    image: postgis/postgis:16-3.4
    environment:
      POSTGRES_DB: trilho
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    volumes:
      - pgdata:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 10

  redis:
    image: redis:7-alpine
    command: redis-server --save "" --appendonly no
    ports:
      - "6379:6379"

volumes:
  pgdata:
```

- [ ] **Step 3: Create docker-compose.override.yml**

`docker-compose.override.yml`:
```yaml
# Dev overrides — maps source for hot reload and exposes extra ports
services:
  api:
    build:
      target: build
    command: dotnet watch run --project Trilho.API/Trilho.API.csproj
    volumes:
      - ./backend:/src
    environment:
      - ASPNETCORE_ENVIRONMENT=Development
      - DOTNET_USE_POLLING_FILE_WATCHER=true
```

- [ ] **Step 4: Create .env.example**

`.env.example`:
```
OLHOVIVO_TOKEN=your_sptrans_token_here
JWT_SECRET=change_me_to_random_32_char_string_here
```

- [ ] **Step 5: Create ROADMAP.md**

`ROADMAP.md`:
```markdown
# Trilho — Roadmap

## Legenda
- ✅ Concluído
- 🚧 Em progresso
- ⏳ Pendente
- ❌ Bloqueado

---

## Fase 0 — Fundação (Backend MVP)
- ✅ Solução .NET 8 criada (Trilho.sln)
- ✅ Domain entities + enums + interfaces
- ✅ EF Core + PostGIS + migrations
- ✅ Seed de linhas e estações de SP
- ✅ Seed de historical_demand (curva horária sintética)
- ✅ Docker Compose funcional (API + PostGIS + Redis)
- ✅ Worker scraping Metrô SP (status das linhas, a cada 2min)
- ✅ Worker scraping CPTM (status das linhas, a cada 2min)
- ✅ Worker OlhoVivo polling ônibus (a cada 30s)
- ✅ Worker inferência de lotação (CrowdInferenceEngine, a cada 1min)
- ✅ Worker limpeza de UserPings (TTL 10min)
- ✅ Endpoints REST básicos (stations, lines, auth, usage)
- ✅ SignalR hub CrowdHub (subscribe por linha)
- ✅ JWT auth anônimo

## Fase 1 — App Flutter
- ✅ Scaffold Flutter (pubspec.yaml, estrutura de pastas)
- ✅ Models + Riverpod providers
- ✅ MapScreen com marcadores por densidade
- ✅ LineDetailScreen
- ✅ StationDetailScreen com gate freemium
- ✅ PaywallScreen RevenueCat
- ✅ SettingsScreen
- ✅ UsageTracker (Hive)
- ✅ AdMob banner + interstitial
- ✅ SignalR real-time via signalr_netcore

## Fase 2 — Crowdsourcing GPS
- ⏳ Geofencing por estação
- ⏳ Ping anônimo de localização
- ⏳ Ajuste do crowdScore com densidade de pings

## Fase 3 — Qualidade de Dados
- ⏳ Integração Cittamobi (posição real trens CPTM — pós mitmproxy)
- ⏳ GTFS-Realtime SPTrans
- ⏳ Dashboard admin de qualidade de dados

## Fase 4 — Expansão
- ⏳ Ônibus municipais completo (OlhoVivo)
- ⏳ Notificações push (FCM)
- ⏳ Widget iOS/Android
- ⏳ Outras cidades (RJ, BH, Curitiba)

---

## Sessões de Trabalho

### Sessão 1 — 2026-03-21
**O que foi feito:**
- Nome definido: Trilho (antes TransitSP)
- Backend completo gerado: Domain, Infrastructure (scrapers, workers), API (endpoints, SignalR)
- Flutter app completo gerado
- Docker Compose configurado

**Decisões técnicas:**
- Nome genérico "Trilho" para suportar qualquer cidade
- Scrapers com HtmlAgilityPack + Polly retry (3x exponential backoff)
- CitamobiProvider marcado como TODO (aguarda reverse engineering)
- JWT anônimo — sem PII, LGPD compliant
- Inferência de lotação: crowdScore = historical × operational_weight

**Pendências / próximos passos:**
- Cadastrar token OlhoVivo: sptrans.com.br/desenvolvedores
- Google Cloud: habilitar Maps SDK + gerar API key
- AdMob: criar IDs de banner e interstitial
- RevenueCat: configurar produto trilho_premium_monthly
- Inspecionar Cittamobi via mitmproxy

**Arquivos criados:**
- backend/Trilho.sln + 4 projetos
- backend/Trilho.Domain/ — entities, enums, interfaces
- backend/Trilho.Infrastructure/ — EF, scrapers, workers, seeds
- backend/Trilho.API/ — Program.cs, endpoints, hub, DTOs
- mobile/ — Flutter app completo
- docker-compose.yml
- ROADMAP.md
```

- [ ] **Step 6: Commit Docker + ROADMAP**

```bash
cd C:/Users/jonas/OneDrive/Documentos/Projetos/Transit
git add docker-compose.yml docker-compose.override.yml .env.example ROADMAP.md backend/Trilho.API/Dockerfile
git commit -m "feat: add Docker Compose, Dockerfile, ROADMAP"
```

---
