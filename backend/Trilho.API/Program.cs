using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using Trilho.API.Endpoints;
using Trilho.API.Hubs;
using Trilho.Infrastructure;
using Trilho.Infrastructure.Persistence.Seeds;

var builder = WebApplication.CreateBuilder(args);

// In non-Production environments, keep the host running even if a background
// worker loses its DB/Redis connection — useful for local dev without Docker.
if (!builder.Environment.IsProduction())
{
    builder.Services.Configure<HostOptions>(opts =>
        opts.BackgroundServiceExceptionBehavior =
            BackgroundServiceExceptionBehavior.Ignore);
}

// Infrastructure (DB, Redis, Workers, Scrapers)
builder.Services.AddInfrastructure(builder.Configuration);

// JWT Auth
var jwtSecret = builder.Configuration["Jwt:Secret"]
    ?? throw new InvalidOperationException("Jwt:Secret not configured.");

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(opts => opts.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuer           = true,
        ValidateAudience         = true,
        ValidIssuer              = "trilho",
        ValidAudience            = "trilho",
        IssuerSigningKey         = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtSecret)),
        ValidateLifetime         = true,
        ClockSkew                = TimeSpan.Zero
    });
builder.Services.AddAuthorization();

// SignalR — with Redis backplane for multi-instance scaling
var redisConnStr = builder.Configuration.GetConnectionString("Redis");
var signalR = builder.Services.AddSignalR();
if (!string.IsNullOrWhiteSpace(redisConnStr))
{
    signalR.AddStackExchangeRedis(redisConnStr, options =>
        options.Configuration.ChannelPrefix = StackExchange.Redis.RedisChannel.Literal("trilho"));
}

// CORS (for Flutter web / debug)
builder.Services.AddCors(o => o.AddDefaultPolicy(p =>
    p.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod()));

// Health checks
builder.Services.AddHealthChecks();

// OpenAPI / Swagger
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c => c.SwaggerDoc("v1", new() { Title = "Trilho API", Version = "v1" }));

var app = builder.Build();

// Auto-migrate + seed on startup (skip in Testing environment)
if (!app.Environment.IsEnvironment("Testing"))
{
    using var scope = app.Services.CreateScope();
    var seeder = scope.ServiceProvider.GetRequiredService<DatabaseSeeder>();
    await seeder.SeedAsync();
}

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseCors();
app.UseAuthentication();
app.UseAuthorization();

// Endpoints
app.MapStationEndpoints();
app.MapLineEndpoints();
app.MapUserEndpoints();
app.MapAdminEndpoints();
app.MapPingEndpoints();
app.MapTrainEndpoints();
app.MapPaymentEndpoints();
app.MapNotificationEndpoints();
app.MapHealthEndpoints();
app.MapWebhookEndpoints();

// SignalR hub
app.MapHub<CrowdHub>("/hubs/crowd");

// Health check
app.MapHealthChecks("/health");

app.Run();

public partial class Program { }
