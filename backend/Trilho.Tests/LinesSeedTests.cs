using FluentAssertions;
using NetTopologySuite.Geometries;
using Trilho.Domain.Enums;
using Trilho.Infrastructure.Persistence.Seeds;
using Xunit;

namespace Trilho.Tests;

public class LinesSeedTests
{
    [Fact]
    public void Lines_ShouldContainAllSpMetroAndCptmLines()
    {
        var codes = LinesSeed.Lines.Select(l => l.Code).ToHashSet();

        // Metro SP
        codes.Should().Contain("1-AZUL");
        codes.Should().Contain("2-VERDE");
        codes.Should().Contain("3-VERMELHA");
        codes.Should().Contain("4-AMARELA");
        codes.Should().Contain("5-LILAS");
        codes.Should().Contain("15-PRATA");

        // CPTM
        codes.Should().Contain("7-RUBI");
        codes.Should().Contain("8-DIAMANTE");
        codes.Should().Contain("9-ESMERALDA");
        codes.Should().Contain("10-TURQUESA");
        codes.Should().Contain("11-CORAL");
        codes.Should().Contain("12-SAFIRA");
        codes.Should().Contain("13-JADE");
    }

    [Fact]
    public void Lines_MetroLinesShouldHaveCorrectType()
    {
        var metroLines = LinesSeed.Lines.Where(l => l.Code.StartsWith("1-") ||
                                                     l.Code.StartsWith("2-") ||
                                                     l.Code.StartsWith("3-") ||
                                                     l.Code.StartsWith("4-") ||
                                                     l.Code.StartsWith("5-") ||
                                                     l.Code.StartsWith("15-"));
        metroLines.Should().AllSatisfy(l => l.Type.Should().Be(LineType.Metro));
    }

    [Fact]
    public void Lines_CptmLinesShouldHaveCorrectType()
    {
        var cptmLines = LinesSeed.Lines.Where(l => l.Code.StartsWith("7-") ||
                                                    l.Code.StartsWith("8-") ||
                                                    l.Code.StartsWith("9-") ||
                                                    l.Code.StartsWith("10-") ||
                                                    l.Code.StartsWith("11-") ||
                                                    l.Code.StartsWith("12-") ||
                                                    l.Code.StartsWith("13-"));
        cptmLines.Should().AllSatisfy(l => l.Type.Should().Be(LineType.Cptm));
    }

    [Fact]
    public void Lines_AllHaveValidColorHex()
    {
        LinesSeed.Lines.Should().AllSatisfy(l =>
        {
            l.ColorHex.Should().HaveLength(6);
            l.ColorHex.Should().MatchRegex("^[0-9A-Fa-f]{6}$");
        });
    }

    [Fact]
    public void Lines_HeadwayPeakShouldBeShorterThanOffPeak()
    {
        LinesSeed.Lines.Should().AllSatisfy(l =>
            l.HeadwayPeakSec.Should().BeLessThanOrEqualTo(l.HeadwayOffPeakSec));
    }

    [Fact]
    public void CreateStations_ShouldReturnStationsForAllLines()
    {
        var lineIdsByCode = LinesSeed.Lines
            .Select((l, i) => new { l.Code, Id = i + 1 })
            .ToDictionary(x => x.Code, x => x.Id);

        var stations = LinesSeed.CreateStations(lineIdsByCode);

        stations.Should().NotBeEmpty();
        stations.Should().AllSatisfy(s =>
        {
            s.Name.Should().NotBeNullOrEmpty();
            s.Capacity.Should().BeGreaterThan(0);
            s.Sequence.Should().BeGreaterThan(0);
            s.Location.Should().NotBeNull();
        });
    }

    [Fact]
    public void CreateStations_LocationsShouldBeWithinSaoPauloBounds()
    {
        var lineIdsByCode = LinesSeed.Lines
            .Select((l, i) => new { l.Code, Id = i + 1 })
            .ToDictionary(x => x.Code, x => x.Id);

        var stations = LinesSeed.CreateStations(lineIdsByCode);

        // São Paulo metro area bounding box (approx)
        stations.Should().AllSatisfy(s =>
        {
            var point = (Point)s.Location;
            point.X.Should().BeInRange(-47.2, -46.3); // longitude
            point.Y.Should().BeInRange(-23.9, -23.3); // latitude
        });
    }

    [Fact]
    public void CreateStations_ShouldIncludeLuzStation()
    {
        var lineIdsByCode = LinesSeed.Lines
            .Select((l, i) => new { l.Code, Id = i + 1 })
            .ToDictionary(x => x.Code, x => x.Id);

        var stations = LinesSeed.CreateStations(lineIdsByCode);

        // Luz is a major interchange — should appear on multiple lines
        var luzStations = stations.Where(s => s.Name == "Luz").ToList();
        luzStations.Should().HaveCountGreaterThanOrEqualTo(2);
    }
}
