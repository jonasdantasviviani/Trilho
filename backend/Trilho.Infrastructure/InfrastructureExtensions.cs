using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Polly;
using Polly.Extensions.Http;
using StackExchange.Redis;
using Trilho.Domain.Interfaces;
using Trilho.Infrastructure.DataSources;
using Trilho.Infrastructure.Persistence;
using Trilho.Infrastructure.Persistence.Seeds;
using Trilho.Infrastructure.Services;
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

        // DataSource health registry (singleton — shared by all workers)
        services.AddSingleton<DataSourceHealthRegistry>();

        // Redis — abortConnect=false allows the server to start even when Redis
        // is temporarily unavailable (e.g. during local dev without Docker).
        // The multiplexer retries in the background and reconnects automatically.
        services.AddSingleton<IConnectionMultiplexer>(_ =>
            ConnectionMultiplexer.Connect($"{config["Redis:Connection"]},abortConnect=false"));

        // OlhoVivo
        services.Configure<OlhoVivoOptions>(config.GetSection("OlhoVivo"));
        services.AddHttpClient<OlhoVivoClient>(c =>
            c.BaseAddress = new Uri("https://api.olhovivo.sptrans.com.br/v2.1/"))
            .AddPolicyHandler(HttpPolicyExtensions
                .HandleTransientHttpError()
                .WaitAndRetryAsync(3, attempt => TimeSpan.FromSeconds(Math.Pow(2, attempt))))
            .AddPolicyHandler(HttpPolicyExtensions
                .HandleTransientHttpError()
                .CircuitBreakerAsync(5, TimeSpan.FromMinutes(2)));

        // Unified Metro/CPTM status scraper — single JSON API covers all lines (1–15).
        // Circuit breaker: 5 failures → open for 2 min (avoids hammering the endpoint).
        services.AddHttpClient<LinhasMetroApiScraper>()
            .AddPolicyHandler(HttpPolicyExtensions
                .HandleTransientHttpError()
                .WaitAndRetryAsync(3, attempt => TimeSpan.FromSeconds(Math.Pow(2, attempt))))
            .AddPolicyHandler(HttpPolicyExtensions
                .HandleTransientHttpError()
                .CircuitBreakerAsync(5, TimeSpan.FromMinutes(2)));

        services.AddScoped<ILineStatusScraper, LinhasMetroApiScraper>();

        // GTFS train positions (schedule-based interpolation)
        services.AddHttpClient("gtfs")
            .AddPolicyHandler(HttpPolicyExtensions
                .HandleTransientHttpError()
                .WaitAndRetryAsync(3, attempt => TimeSpan.FromSeconds(Math.Pow(2, attempt))));
        services.AddScoped<ITrainPositionProvider, GtfsTrainPositionProvider>();

        // Google Places (real-time crowd popularity)
        services.AddHttpClient<IGooglePlacesService, GooglePlacesService>();
        services.AddHostedService<GoogleCrowdWorker>();

        // AbacatePay (payments)
        services.AddHttpClient<IAbacatePayService, AbacatePayService>();

        // Firebase Token Validator
        services.AddSingleton<IFirebaseTokenValidator, FirebaseTokenValidator>();

        // Firebase Cloud Messaging (Push Notifications)
        services.AddSingleton<IFcmService, FcmService>();

        // Background Workers
        services.AddHostedService<LineStatusWorker>();
        services.AddHostedService<CrowdInferenceWorker>();
        services.AddHostedService<CrowdDensityWorker>();
        services.AddHostedService<BusPositionWorker>();
        services.AddHostedService<TrainPositionWorker>();
        services.AddHostedService<UserPingCleanupWorker>();
        // GtfsImportWorker registered as singleton so AdminEndpoints can inject it directly
        // (to read SyncFilePath / force re-import) while still running as a hosted service.
        services.AddSingleton<GtfsImportWorker>();
        services.AddHostedService(sp => sp.GetRequiredService<GtfsImportWorker>());
        services.AddHostedService<GtfsHistoricalDemandWorker>();
        services.AddHostedService<NotificationWorker>();
        services.AddHostedService<BusArrivalCacheWorker>();

        return services;
    }
}
