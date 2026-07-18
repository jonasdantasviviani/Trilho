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
        new() { Code = "1-AZUL",      Name = "Linha 1 - Azul",       Type = LineType.Metro, ColorHex = "0044AA", HeadwayPeakSec = 120, HeadwayOffPeakSec = 300, CityId = 1 },
        new() { Code = "2-VERDE",     Name = "Linha 2 - Verde",       Type = LineType.Metro, ColorHex = "007A4D", HeadwayPeakSec = 120, HeadwayOffPeakSec = 300, CityId = 1 },
        new() { Code = "3-VERMELHA",  Name = "Linha 3 - Vermelha",    Type = LineType.Metro, ColorHex = "EE1C25", HeadwayPeakSec = 90,  HeadwayOffPeakSec = 270, CityId = 1 },
        new() { Code = "4-AMARELA",   Name = "Linha 4 - Amarela",     Type = LineType.Metro, ColorHex = "FFD400", HeadwayPeakSec = 120, HeadwayOffPeakSec = 300, CityId = 1 },
        new() { Code = "5-LILAS",     Name = "Linha 5 - Lilás",       Type = LineType.Metro, ColorHex = "9B2990", HeadwayPeakSec = 150, HeadwayOffPeakSec = 360, CityId = 1 },
        new() { Code = "15-PRATA",    Name = "Linha 15 - Prata",      Type = LineType.Metro, ColorHex = "9E9E9E", HeadwayPeakSec = 180, HeadwayOffPeakSec = 420, CityId = 1 },
        new() { Code = "7-RUBI",      Name = "Linha 7 - Rubi",        Type = LineType.Cptm,  ColorHex = "EE1C25", HeadwayPeakSec = 240, HeadwayOffPeakSec = 600, CityId = 1 },
        new() { Code = "8-DIAMANTE",  Name = "Linha 8 - Diamante",    Type = LineType.Cptm,  ColorHex = "9E9E9E", HeadwayPeakSec = 240, HeadwayOffPeakSec = 600, CityId = 1 },
        new() { Code = "9-ESMERALDA", Name = "Linha 9 - Esmeralda",   Type = LineType.Cptm,  ColorHex = "007A4D", HeadwayPeakSec = 240, HeadwayOffPeakSec = 600, CityId = 1 },
        new() { Code = "10-TURQUESA", Name = "Linha 10 - Turquesa",   Type = LineType.Cptm,  ColorHex = "008080", HeadwayPeakSec = 300, HeadwayOffPeakSec = 720, CityId = 1 },
        new() { Code = "11-CORAL",    Name = "Linha 11 - Coral",      Type = LineType.Cptm,  ColorHex = "F7941D", HeadwayPeakSec = 300, HeadwayOffPeakSec = 720, CityId = 1 },
        new() { Code = "12-SAFIRA",   Name = "Linha 12 - Safira",     Type = LineType.Cptm,  ColorHex = "003DA5", HeadwayPeakSec = 300, HeadwayOffPeakSec = 720, CityId = 1 },
        new() { Code = "13-JADE",     Name = "Linha 13 - Jade",       Type = LineType.Cptm,  ColorHex = "00A859", HeadwayPeakSec = 600, HeadwayOffPeakSec = 900, CityId = 1 },
    ];

    public static Station[] CreateStations(IReadOnlyDictionary<string, int> lineIdsByCode) =>
    [
        // Linha 1 - Azul
        new() { Name = "Tucuruvi",             LineId = lineIdsByCode["1-AZUL"],  Sequence = 1,  Location = GeoFactory.CreatePoint(new Coordinate(-46.6103, -23.4730)), Capacity = 1200 },
        new() { Name = "Parada Inglesa",        LineId = lineIdsByCode["1-AZUL"],  Sequence = 2,  Location = GeoFactory.CreatePoint(new Coordinate(-46.6142, -23.4811)), Capacity = 900  },
        new() { Name = "Jardim São Paulo",      LineId = lineIdsByCode["1-AZUL"],  Sequence = 3,  Location = GeoFactory.CreatePoint(new Coordinate(-46.6128, -23.4863)), Capacity = 900  },
        new() { Name = "Santana",               LineId = lineIdsByCode["1-AZUL"],  Sequence = 4,  Location = GeoFactory.CreatePoint(new Coordinate(-46.6280, -23.4979)), Capacity = 1400 },
        new() { Name = "Carandiru",             LineId = lineIdsByCode["1-AZUL"],  Sequence = 5,  Location = GeoFactory.CreatePoint(new Coordinate(-46.6281, -23.5082)), Capacity = 1000 },
        new() { Name = "Portuguesa-Tietê",      LineId = lineIdsByCode["1-AZUL"],  Sequence = 6,  Location = GeoFactory.CreatePoint(new Coordinate(-46.6281, -23.5147)), Capacity = 1100 },
        new() { Name = "Armênia",               LineId = lineIdsByCode["1-AZUL"],  Sequence = 7,  Location = GeoFactory.CreatePoint(new Coordinate(-46.6281, -23.5195)), Capacity = 900  },
        new() { Name = "Tiradentes",            LineId = lineIdsByCode["1-AZUL"],  Sequence = 8,  Location = GeoFactory.CreatePoint(new Coordinate(-46.6358, -23.5325)), Capacity = 1000 },
        new() { Name = "Luz",                   LineId = lineIdsByCode["1-AZUL"],  Sequence = 9,  Location = GeoFactory.CreatePoint(new Coordinate(-46.6336, -23.5358)), Capacity = 2500 },
        new() { Name = "São Bento",             LineId = lineIdsByCode["1-AZUL"],  Sequence = 10, Location = GeoFactory.CreatePoint(new Coordinate(-46.6336, -23.5434)), Capacity = 2000 },
        new() { Name = "Sé",                    LineId = lineIdsByCode["1-AZUL"],  Sequence = 11, Location = GeoFactory.CreatePoint(new Coordinate(-46.6336, -23.5497)), Capacity = 3500 },
        new() { Name = "Liberdade",             LineId = lineIdsByCode["1-AZUL"],  Sequence = 12, Location = GeoFactory.CreatePoint(new Coordinate(-46.6336, -23.5577)), Capacity = 2000 },
        new() { Name = "São Judas",             LineId = lineIdsByCode["1-AZUL"],  Sequence = 13, Location = GeoFactory.CreatePoint(new Coordinate(-46.6336, -23.5651)), Capacity = 1100 },
        new() { Name = "Saúde",                 LineId = lineIdsByCode["1-AZUL"],  Sequence = 14, Location = GeoFactory.CreatePoint(new Coordinate(-46.6335, -23.5731)), Capacity = 1200 },
        new() { Name = "Praça da Árvore",       LineId = lineIdsByCode["1-AZUL"],  Sequence = 15, Location = GeoFactory.CreatePoint(new Coordinate(-46.6334, -23.5821)), Capacity = 1000 },
        new() { Name = "Santa Cruz",            LineId = lineIdsByCode["1-AZUL"],  Sequence = 16, Location = GeoFactory.CreatePoint(new Coordinate(-46.6334, -23.5916)), Capacity = 1400 },
        new() { Name = "Chácara Klabin",        LineId = lineIdsByCode["1-AZUL"],  Sequence = 17, Location = GeoFactory.CreatePoint(new Coordinate(-46.6254, -23.5967)), Capacity = 1100 },
        new() { Name = "Ana Rosa",              LineId = lineIdsByCode["1-AZUL"],  Sequence = 18, Location = GeoFactory.CreatePoint(new Coordinate(-46.6474, -23.5941)), Capacity = 2000 },
        new() { Name = "Paraíso",               LineId = lineIdsByCode["1-AZUL"],  Sequence = 19, Location = GeoFactory.CreatePoint(new Coordinate(-46.6533, -23.5888)), Capacity = 2200 },
        new() { Name = "Brigadeiro",            LineId = lineIdsByCode["1-AZUL"],  Sequence = 20, Location = GeoFactory.CreatePoint(new Coordinate(-46.6533, -23.5820)), Capacity = 1800 },
        new() { Name = "Trianon-Masp",          LineId = lineIdsByCode["1-AZUL"],  Sequence = 21, Location = GeoFactory.CreatePoint(new Coordinate(-46.6533, -23.5658)), Capacity = 1500 },
        new() { Name = "Consolação",            LineId = lineIdsByCode["1-AZUL"],  Sequence = 22, Location = GeoFactory.CreatePoint(new Coordinate(-46.6533, -23.5570)), Capacity = 1600 },
        new() { Name = "Paulista",              LineId = lineIdsByCode["1-AZUL"],  Sequence = 23, Location = GeoFactory.CreatePoint(new Coordinate(-46.6472, -23.5622)), Capacity = 2800 },
        new() { Name = "Jabaquara",             LineId = lineIdsByCode["1-AZUL"],  Sequence = 24, Location = GeoFactory.CreatePoint(new Coordinate(-46.6334, -23.6678)), Capacity = 2000 },

        // Linha 2 - Verde
        new() { Name = "Vila Madalena",         LineId = lineIdsByCode["2-VERDE"], Sequence = 1,  Location = GeoFactory.CreatePoint(new Coordinate(-46.6924, -23.5567)), Capacity = 1400 },
        new() { Name = "Sumaré",                LineId = lineIdsByCode["2-VERDE"], Sequence = 2,  Location = GeoFactory.CreatePoint(new Coordinate(-46.6793, -23.5512)), Capacity = 1000 },
        new() { Name = "Clínicas",              LineId = lineIdsByCode["2-VERDE"], Sequence = 3,  Location = GeoFactory.CreatePoint(new Coordinate(-46.6691, -23.5559)), Capacity = 1200 },
        new() { Name = "Consolação",            LineId = lineIdsByCode["2-VERDE"], Sequence = 4,  Location = GeoFactory.CreatePoint(new Coordinate(-46.6533, -23.5570)), Capacity = 1600 },
        new() { Name = "Paraíso",               LineId = lineIdsByCode["2-VERDE"], Sequence = 5,  Location = GeoFactory.CreatePoint(new Coordinate(-46.6533, -23.5888)), Capacity = 2200 },
        new() { Name = "Ana Rosa",              LineId = lineIdsByCode["2-VERDE"], Sequence = 6,  Location = GeoFactory.CreatePoint(new Coordinate(-46.6474, -23.5941)), Capacity = 2000 },
        new() { Name = "Chácara Klabin",        LineId = lineIdsByCode["2-VERDE"], Sequence = 7,  Location = GeoFactory.CreatePoint(new Coordinate(-46.6254, -23.5967)), Capacity = 1100 },
        new() { Name = "Alto do Ipiranga",      LineId = lineIdsByCode["2-VERDE"], Sequence = 8,  Location = GeoFactory.CreatePoint(new Coordinate(-46.6096, -23.5936)), Capacity = 1000 },
        new() { Name = "Sacomã",                LineId = lineIdsByCode["2-VERDE"], Sequence = 9,  Location = GeoFactory.CreatePoint(new Coordinate(-46.5996, -23.5976)), Capacity = 1200 },
        new() { Name = "Tamanduateí",           LineId = lineIdsByCode["2-VERDE"], Sequence = 10, Location = GeoFactory.CreatePoint(new Coordinate(-46.5812, -23.5917)), Capacity = 1400 },
        new() { Name = "Vila Prudente",         LineId = lineIdsByCode["2-VERDE"], Sequence = 11, Location = GeoFactory.CreatePoint(new Coordinate(-46.5704, -23.5858)), Capacity = 1200 },

        // Linha 3 - Vermelha
        new() { Name = "Palmeiras-Barra Funda", LineId = lineIdsByCode["3-VERMELHA"], Sequence = 1,  Location = GeoFactory.CreatePoint(new Coordinate(-46.6541, -23.5268)), Capacity = 2500 },
        new() { Name = "Marechal Deodoro",      LineId = lineIdsByCode["3-VERMELHA"], Sequence = 2,  Location = GeoFactory.CreatePoint(new Coordinate(-46.6456, -23.5319)), Capacity = 1400 },
        new() { Name = "Santa Cecília",         LineId = lineIdsByCode["3-VERMELHA"], Sequence = 3,  Location = GeoFactory.CreatePoint(new Coordinate(-46.6418, -23.5352)), Capacity = 1300 },
        new() { Name = "República",             LineId = lineIdsByCode["3-VERMELHA"], Sequence = 4,  Location = GeoFactory.CreatePoint(new Coordinate(-46.6393, -23.5435)), Capacity = 3000 },
        new() { Name = "Pedro II",              LineId = lineIdsByCode["3-VERMELHA"], Sequence = 5,  Location = GeoFactory.CreatePoint(new Coordinate(-46.6358, -23.5469)), Capacity = 1500 },
        new() { Name = "Brás",                  LineId = lineIdsByCode["3-VERMELHA"], Sequence = 6,  Location = GeoFactory.CreatePoint(new Coordinate(-46.6180, -23.5471)), Capacity = 2000 },
        new() { Name = "Belém",                 LineId = lineIdsByCode["3-VERMELHA"], Sequence = 7,  Location = GeoFactory.CreatePoint(new Coordinate(-46.5956, -23.5477)), Capacity = 1200 },
        new() { Name = "Tatuapé",               LineId = lineIdsByCode["3-VERMELHA"], Sequence = 8,  Location = GeoFactory.CreatePoint(new Coordinate(-46.5764, -23.5471)), Capacity = 2200 },
        new() { Name = "Carrão",                LineId = lineIdsByCode["3-VERMELHA"], Sequence = 9,  Location = GeoFactory.CreatePoint(new Coordinate(-46.5601, -23.5471)), Capacity = 1200 },
        new() { Name = "Penha",                 LineId = lineIdsByCode["3-VERMELHA"], Sequence = 10, Location = GeoFactory.CreatePoint(new Coordinate(-46.5446, -23.5290)), Capacity = 1400 },
        new() { Name = "Guilhermina-Esperança", LineId = lineIdsByCode["3-VERMELHA"], Sequence = 11, Location = GeoFactory.CreatePoint(new Coordinate(-46.5341, -23.5196)), Capacity = 1000 },
        new() { Name = "Patriarca",             LineId = lineIdsByCode["3-VERMELHA"], Sequence = 12, Location = GeoFactory.CreatePoint(new Coordinate(-46.5241, -23.5100)), Capacity = 1000 },
        new() { Name = "Artur Alvim",           LineId = lineIdsByCode["3-VERMELHA"], Sequence = 13, Location = GeoFactory.CreatePoint(new Coordinate(-46.5133, -23.5023)), Capacity = 1100 },
        new() { Name = "Corinthians-Itaquera",  LineId = lineIdsByCode["3-VERMELHA"], Sequence = 14, Location = GeoFactory.CreatePoint(new Coordinate(-46.4968, -23.5448)), Capacity = 3000 },

        // Linha 4 - Amarela (key stations)
        new() { Name = "Luz",                   LineId = lineIdsByCode["4-AMARELA"], Sequence = 1,  Location = GeoFactory.CreatePoint(new Coordinate(-46.6336, -23.5358)), Capacity = 2500 },
        new() { Name = "República",             LineId = lineIdsByCode["4-AMARELA"], Sequence = 2,  Location = GeoFactory.CreatePoint(new Coordinate(-46.6393, -23.5435)), Capacity = 3000 },
        new() { Name = "Higienópolis-Mackenzie",LineId = lineIdsByCode["4-AMARELA"], Sequence = 3,  Location = GeoFactory.CreatePoint(new Coordinate(-46.6530, -23.5392)), Capacity = 1500 },
        new() { Name = "Paulista",              LineId = lineIdsByCode["4-AMARELA"], Sequence = 4,  Location = GeoFactory.CreatePoint(new Coordinate(-46.6472, -23.5622)), Capacity = 2800 },
        new() { Name = "Fradique Coutinho",     LineId = lineIdsByCode["4-AMARELA"], Sequence = 5,  Location = GeoFactory.CreatePoint(new Coordinate(-46.6872, -23.5624)), Capacity = 1200 },
        new() { Name = "Faria Lima",            LineId = lineIdsByCode["4-AMARELA"], Sequence = 6,  Location = GeoFactory.CreatePoint(new Coordinate(-46.6934, -23.5673)), Capacity = 2000 },
        new() { Name = "Pinheiros",             LineId = lineIdsByCode["4-AMARELA"], Sequence = 7,  Location = GeoFactory.CreatePoint(new Coordinate(-46.7002, -23.5684)), Capacity = 1800 },
        new() { Name = "Butantã",               LineId = lineIdsByCode["4-AMARELA"], Sequence = 8,  Location = GeoFactory.CreatePoint(new Coordinate(-46.7175, -23.5727)), Capacity = 1400 },
        new() { Name = "São Paulo-Morumbi",     LineId = lineIdsByCode["4-AMARELA"], Sequence = 9,  Location = GeoFactory.CreatePoint(new Coordinate(-46.7253, -23.6023)), Capacity = 1200 },
        new() { Name = "Vila Sônia",            LineId = lineIdsByCode["4-AMARELA"], Sequence = 10, Location = GeoFactory.CreatePoint(new Coordinate(-46.7381, -23.6059)), Capacity = 1100 },

        // Linha 5 - Lilás (key stations)
        new() { Name = "Capão Redondo",         LineId = lineIdsByCode["5-LILAS"], Sequence = 1,  Location = GeoFactory.CreatePoint(new Coordinate(-46.7784, -23.6594)), Capacity = 1400 },
        new() { Name = "Campo Limpo",           LineId = lineIdsByCode["5-LILAS"], Sequence = 2,  Location = GeoFactory.CreatePoint(new Coordinate(-46.7659, -23.6443)), Capacity = 1200 },
        new() { Name = "Vila das Belezas",      LineId = lineIdsByCode["5-LILAS"], Sequence = 3,  Location = GeoFactory.CreatePoint(new Coordinate(-46.7508, -23.6328)), Capacity = 1000 },
        new() { Name = "Giovanni Gronchi",      LineId = lineIdsByCode["5-LILAS"], Sequence = 4,  Location = GeoFactory.CreatePoint(new Coordinate(-46.7406, -23.6268)), Capacity = 1100 },
        new() { Name = "Santo Amaro",           LineId = lineIdsByCode["5-LILAS"], Sequence = 5,  Location = GeoFactory.CreatePoint(new Coordinate(-46.7173, -23.6536)), Capacity = 2000 },
        new() { Name = "Largo Treze",           LineId = lineIdsByCode["5-LILAS"], Sequence = 6,  Location = GeoFactory.CreatePoint(new Coordinate(-46.7080, -23.6476)), Capacity = 1300 },
        new() { Name = "Adolfo Pinheiro",       LineId = lineIdsByCode["5-LILAS"], Sequence = 7,  Location = GeoFactory.CreatePoint(new Coordinate(-46.6982, -23.6378)), Capacity = 1100 },
        new() { Name = "Alto da Boa Vista",     LineId = lineIdsByCode["5-LILAS"], Sequence = 8,  Location = GeoFactory.CreatePoint(new Coordinate(-46.6891, -23.6264)), Capacity = 1000 },
        new() { Name = "Borba Gato",            LineId = lineIdsByCode["5-LILAS"], Sequence = 9,  Location = GeoFactory.CreatePoint(new Coordinate(-46.6820, -23.6191)), Capacity = 1100 },
        new() { Name = "Brooklin",              LineId = lineIdsByCode["5-LILAS"], Sequence = 10, Location = GeoFactory.CreatePoint(new Coordinate(-46.6924, -23.6126)), Capacity = 1200 },
        new() { Name = "Campo Belo",            LineId = lineIdsByCode["5-LILAS"], Sequence = 11, Location = GeoFactory.CreatePoint(new Coordinate(-46.6671, -23.6179)), Capacity = 1300 },
        new() { Name = "Eucaliptos",            LineId = lineIdsByCode["5-LILAS"], Sequence = 12, Location = GeoFactory.CreatePoint(new Coordinate(-46.6573, -23.6133)), Capacity = 1100 },
        new() { Name = "Moema",                 LineId = lineIdsByCode["5-LILAS"], Sequence = 13, Location = GeoFactory.CreatePoint(new Coordinate(-46.6595, -23.5999)), Capacity = 1400 },
        new() { Name = "AACD-Servidor",         LineId = lineIdsByCode["5-LILAS"], Sequence = 14, Location = GeoFactory.CreatePoint(new Coordinate(-46.6614, -23.5907)), Capacity = 1200 },
        new() { Name = "Hospital São Paulo",    LineId = lineIdsByCode["5-LILAS"], Sequence = 15, Location = GeoFactory.CreatePoint(new Coordinate(-46.6616, -23.5852)), Capacity = 1300 },
        new() { Name = "Santa Cruz",            LineId = lineIdsByCode["5-LILAS"], Sequence = 16, Location = GeoFactory.CreatePoint(new Coordinate(-46.6334, -23.5916)), Capacity = 1400 },
        new() { Name = "Chácara Klabin",        LineId = lineIdsByCode["5-LILAS"], Sequence = 17, Location = GeoFactory.CreatePoint(new Coordinate(-46.6254, -23.5967)), Capacity = 1100 },

        // Linha 7 - Rubi (key stations)
        new() { Name = "Luz",                   LineId = lineIdsByCode["7-RUBI"],  Sequence = 1,  Location = GeoFactory.CreatePoint(new Coordinate(-46.6336, -23.5358)), Capacity = 2500 },
        new() { Name = "Palmeiras-Barra Funda", LineId = lineIdsByCode["7-RUBI"],  Sequence = 2,  Location = GeoFactory.CreatePoint(new Coordinate(-46.6541, -23.5268)), Capacity = 2500 },
        new() { Name = "Pirituba",              LineId = lineIdsByCode["7-RUBI"],  Sequence = 3,  Location = GeoFactory.CreatePoint(new Coordinate(-46.7294, -23.4854)), Capacity = 1500 },
        new() { Name = "Caieiras",              LineId = lineIdsByCode["7-RUBI"],  Sequence = 4,  Location = GeoFactory.CreatePoint(new Coordinate(-46.7411, -23.3633)), Capacity = 1200 },
        new() { Name = "Franco da Rocha",       LineId = lineIdsByCode["7-RUBI"],  Sequence = 5,  Location = GeoFactory.CreatePoint(new Coordinate(-46.7252, -23.3227)), Capacity = 1100 },

        // Linha 8 - Diamante (key stations)
        new() { Name = "Júlio Prestes",         LineId = lineIdsByCode["8-DIAMANTE"], Sequence = 1,  Location = GeoFactory.CreatePoint(new Coordinate(-46.6396, -23.5365)), Capacity = 2000 },
        new() { Name = "Palmeiras-Barra Funda", LineId = lineIdsByCode["8-DIAMANTE"], Sequence = 2,  Location = GeoFactory.CreatePoint(new Coordinate(-46.6541, -23.5268)), Capacity = 2500 },
        new() { Name = "Lapa",                  LineId = lineIdsByCode["8-DIAMANTE"], Sequence = 3,  Location = GeoFactory.CreatePoint(new Coordinate(-46.7012, -23.5229)), Capacity = 1800 },
        new() { Name = "Osasco",                LineId = lineIdsByCode["8-DIAMANTE"], Sequence = 4,  Location = GeoFactory.CreatePoint(new Coordinate(-46.7919, -23.5324)), Capacity = 2000 },
        new() { Name = "Amador Bueno",          LineId = lineIdsByCode["8-DIAMANTE"], Sequence = 5,  Location = GeoFactory.CreatePoint(new Coordinate(-46.8289, -23.5306)), Capacity = 1200 },

        // Linha 9 - Esmeralda (key stations)
        new() { Name = "Osasco",                LineId = lineIdsByCode["9-ESMERALDA"], Sequence = 1, Location = GeoFactory.CreatePoint(new Coordinate(-46.7919, -23.5324)), Capacity = 2000 },
        new() { Name = "Presidente Altino",     LineId = lineIdsByCode["9-ESMERALDA"], Sequence = 2, Location = GeoFactory.CreatePoint(new Coordinate(-46.7713, -23.5297)), Capacity = 1300 },
        new() { Name = "Ceasa",                 LineId = lineIdsByCode["9-ESMERALDA"], Sequence = 3, Location = GeoFactory.CreatePoint(new Coordinate(-46.7438, -23.5296)), Capacity = 1200 },
        new() { Name = "Villa-Lobos-Jaguaré",   LineId = lineIdsByCode["9-ESMERALDA"], Sequence = 4, Location = GeoFactory.CreatePoint(new Coordinate(-46.7272, -23.5353)), Capacity = 1100 },
        new() { Name = "Cidade Universitária",  LineId = lineIdsByCode["9-ESMERALDA"], Sequence = 5, Location = GeoFactory.CreatePoint(new Coordinate(-46.7234, -23.5601)), Capacity = 1300 },
        new() { Name = "Pinheiros",             LineId = lineIdsByCode["9-ESMERALDA"], Sequence = 6, Location = GeoFactory.CreatePoint(new Coordinate(-46.7002, -23.5684)), Capacity = 1800 },
        new() { Name = "Hebraica-Rebouças",     LineId = lineIdsByCode["9-ESMERALDA"], Sequence = 7, Location = GeoFactory.CreatePoint(new Coordinate(-46.6799, -23.5638)), Capacity = 1400 },
        new() { Name = "Cidade Jardim",         LineId = lineIdsByCode["9-ESMERALDA"], Sequence = 8, Location = GeoFactory.CreatePoint(new Coordinate(-46.6951, -23.5768)), Capacity = 1200 },
        new() { Name = "Santo Amaro",           LineId = lineIdsByCode["9-ESMERALDA"], Sequence = 9, Location = GeoFactory.CreatePoint(new Coordinate(-46.7173, -23.6536)), Capacity = 2000 },
        new() { Name = "Jurubatuba",            LineId = lineIdsByCode["9-ESMERALDA"], Sequence = 10, Location = GeoFactory.CreatePoint(new Coordinate(-46.7107, -23.6700)), Capacity = 1300 },
        new() { Name = "Autódromo",             LineId = lineIdsByCode["9-ESMERALDA"], Sequence = 11, Location = GeoFactory.CreatePoint(new Coordinate(-46.6981, -23.6872)), Capacity = 1100 },
        new() { Name = "Primavera-Interlagos",  LineId = lineIdsByCode["9-ESMERALDA"], Sequence = 12, Location = GeoFactory.CreatePoint(new Coordinate(-46.6883, -23.6993)), Capacity = 1000 },
        new() { Name = "Grajaú",                LineId = lineIdsByCode["9-ESMERALDA"], Sequence = 13, Location = GeoFactory.CreatePoint(new Coordinate(-46.6871, -23.7196)), Capacity = 1400 },

        // Linha 11 - Coral (key stations)
        new() { Name = "Luz",                   LineId = lineIdsByCode["11-CORAL"], Sequence = 1,  Location = GeoFactory.CreatePoint(new Coordinate(-46.6336, -23.5358)), Capacity = 2500 },
        new() { Name = "Brás",                  LineId = lineIdsByCode["11-CORAL"], Sequence = 2,  Location = GeoFactory.CreatePoint(new Coordinate(-46.6180, -23.5471)), Capacity = 2000 },
        new() { Name = "Tatuapé",               LineId = lineIdsByCode["11-CORAL"], Sequence = 3,  Location = GeoFactory.CreatePoint(new Coordinate(-46.5764, -23.5471)), Capacity = 2200 },
        new() { Name = "Corinthians-Itaquera",  LineId = lineIdsByCode["11-CORAL"], Sequence = 4,  Location = GeoFactory.CreatePoint(new Coordinate(-46.4968, -23.5448)), Capacity = 3000 },
        new() { Name = "Guaianases",            LineId = lineIdsByCode["11-CORAL"], Sequence = 5,  Location = GeoFactory.CreatePoint(new Coordinate(-46.4279, -23.5368)), Capacity = 1500 },

        // Linha 12 - Safira (key stations)
        new() { Name = "Brás",                  LineId = lineIdsByCode["12-SAFIRA"], Sequence = 1, Location = GeoFactory.CreatePoint(new Coordinate(-46.6180, -23.5471)), Capacity = 2000 },
        new() { Name = "Tatuapé",               LineId = lineIdsByCode["12-SAFIRA"], Sequence = 2, Location = GeoFactory.CreatePoint(new Coordinate(-46.5764, -23.5471)), Capacity = 2200 },
        new() { Name = "Engenheiro Goulart",    LineId = lineIdsByCode["12-SAFIRA"], Sequence = 3, Location = GeoFactory.CreatePoint(new Coordinate(-46.5329, -23.5138)), Capacity = 1300 },
        new() { Name = "Guarulhos-Cecap",       LineId = lineIdsByCode["12-SAFIRA"], Sequence = 4, Location = GeoFactory.CreatePoint(new Coordinate(-46.5161, -23.4629)), Capacity = 1400 },

        // Linha 13 - Jade (key stations)
        new() { Name = "Engenheiro Goulart",    LineId = lineIdsByCode["13-JADE"], Sequence = 1, Location = GeoFactory.CreatePoint(new Coordinate(-46.5329, -23.5138)), Capacity = 1300 },
        new() { Name = "Aeroporto-Guarulhos",   LineId = lineIdsByCode["13-JADE"], Sequence = 2, Location = GeoFactory.CreatePoint(new Coordinate(-46.4736, -23.4319)), Capacity = 2500 },
    ];
}
