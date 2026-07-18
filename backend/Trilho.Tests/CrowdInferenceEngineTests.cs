using FluentAssertions;
using Trilho.Domain.Enums;
using Trilho.Infrastructure.Workers;
using Xunit;

namespace Trilho.Tests;

public class CrowdInferenceEngineTests
{
    [Theory]
    [InlineData(100, 1000, OperationalStatus.Normal, DensityLevel.Low)]     // 10% → Low
    [InlineData(400, 1000, OperationalStatus.Normal, DensityLevel.Medium)]  // 40% → Medium
    [InlineData(700, 1000, OperationalStatus.Normal, DensityLevel.High)]    // 70% → High
    [InlineData(900, 1000, OperationalStatus.Normal, DensityLevel.Packed)]  // 90% → Packed
    public void Infer_NormalStatus_ReturnsExpectedLevel(
        int avgPassengers, int capacity, OperationalStatus status, DensityLevel expected)
    {
        var result = CrowdInferenceEngine.Infer(avgPassengers, capacity, status);
        result.Level.Should().Be(expected);
    }

    [Fact]
    public void Infer_ReducedSpeed_InflatesCrowdingBy1_4x()
    {
        // 40% occupancy × 1.4 = 56% → still Medium, but close to boundary
        var normal = CrowdInferenceEngine.Infer(400, 1000, OperationalStatus.Normal);
        var reduced = CrowdInferenceEngine.Infer(400, 1000, OperationalStatus.ReducedSpeed);

        reduced.Score.Should().BeGreaterThan(normal.Score);
        reduced.Score.Should().Be(normal.Score * 1.4m);
    }

    [Fact]
    public void Infer_Partial_PushesModerateOccupancyToHigh()
    {
        // 40% × 1.8 = 72% → High (crosses the 0.60 boundary)
        var result = CrowdInferenceEngine.Infer(400, 1000, OperationalStatus.Partial);
        result.Level.Should().Be(DensityLevel.High);
    }

    [Fact]
    public void Infer_Suspended_MaxesOutAtPacked()
    {
        // 40% × 2.5 = 100% → Packed, capped at 1.0
        var result = CrowdInferenceEngine.Infer(400, 1000, OperationalStatus.Suspended);
        result.Level.Should().Be(DensityLevel.Packed);
        result.Score.Should().Be(1.0m);
    }

    [Fact]
    public void Infer_ZeroCapacity_ReturnsLowWithZeroScore()
    {
        var result = CrowdInferenceEngine.Infer(100, 0, OperationalStatus.Normal);
        result.Score.Should().Be(0m);
        result.Level.Should().Be(DensityLevel.Low);
    }

    [Fact]
    public void Infer_FullCapacity_NormalStatus_ReturnsPacked()
    {
        var result = CrowdInferenceEngine.Infer(1000, 1000, OperationalStatus.Normal);
        result.Score.Should().Be(1.0m);
        result.Level.Should().Be(DensityLevel.Packed);
    }

    [Fact]
    public void Infer_ScoreNeverExceedsOne()
    {
        // 200% occupancy with suspension weight 2.5 should still cap at 1.0
        var result = CrowdInferenceEngine.Infer(2000, 1000, OperationalStatus.Suspended);
        result.Score.Should().Be(1.0m);
    }
}
