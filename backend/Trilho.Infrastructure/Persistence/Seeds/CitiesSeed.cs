using Trilho.Domain.Entities;

namespace Trilho.Infrastructure.Persistence.Seeds;

public static class CitiesSeed
{
    public static readonly City SaoPaulo = new()
    {
        Id = 1,
        Name = "São Paulo",
        State = "SP",
        Country = "BR",
        Latitude = -23.5505,
        Longitude = -46.6333,
        IsActive = true
    };

    public static readonly City RioDeJaneiro = new()
    {
        Id = 2,
        Name = "Rio de Janeiro",
        State = "RJ",
        Country = "BR",
        Latitude = -22.9068,
        Longitude = -43.1729,
        IsActive = false
    };

    public static readonly City BeloHorizonte = new()
    {
        Id = 3,
        Name = "Belo Horizonte",
        State = "MG",
        Country = "BR",
        Latitude = -19.9167,
        Longitude = -43.9345,
        IsActive = false
    };

    public static readonly City Curitiba = new()
    {
        Id = 4,
        Name = "Curitiba",
        State = "PR",
        Country = "BR",
        Latitude = -25.4284,
        Longitude = -49.2733,
        IsActive = false
    };

    public static List<City> All => [SaoPaulo, RioDeJaneiro, BeloHorizonte, Curitiba];
}
