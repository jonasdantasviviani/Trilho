using Trilho.Domain.Enums;

namespace Trilho.Infrastructure.Workers;

public record InferenceResult(decimal Score, DensityLevel Level);

public static class CrowdInferenceEngine
{
    public static InferenceResult Infer(int avgPassengers, int capacity, OperationalStatus status)
    {
        double baseRatio = capacity > 0 ? (double)avgPassengers / capacity : 0;

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
