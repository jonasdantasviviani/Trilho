using StackExchange.Redis;
using Trilho.Infrastructure.Workers;

namespace Trilho.API.Endpoints;

public static class TrainEndpoints
{
    public static IEndpointRouteBuilder MapTrainEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapGet("/api/trains/positions", GetTrainPositions)
            .WithName("GetTrainPositions")
            .WithTags("Trains")
            .AllowAnonymous();

        return app;
    }

    private static async Task<IResult> GetTrainPositions(
        IConnectionMultiplexer redis,
        CancellationToken ct)
    {
        var positions = await TrainPositionWorker.GetCachedPositionsAsync(redis, ct);

        var result = positions.Select(p => new TrainPositionDto(
            p.LineCode,
            p.Lat,
            p.Lng,
            p.UpdatedAt
        ));

        return Results.Ok(result);
    }

}

public record TrainPositionDto(
    string LineCode,
    double Lat,
    double Lng,
    DateTimeOffset UpdatedAt
);
