namespace Trilho.Domain.Interfaces;

public record TrainPosition(int LineId, string LineCode, double Lat, double Lng, DateTimeOffset UpdatedAt);

public interface ITrainPositionProvider
{
    Task<IEnumerable<TrainPosition>> GetPositionsAsync(CancellationToken ct = default);
}
