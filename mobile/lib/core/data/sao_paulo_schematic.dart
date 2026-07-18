// mobile/lib/core/data/sao_paulo_schematic.dart
//
// Coordenadas em espaço de PIXEL: canvas 1500 × 1000.
// X → esquerda-direita, Y → topo-baixo.
//
import 'package:flutter/painting.dart';
import '../models/schematic_model.dart';

const TransitSchematic saoPauloSchematic = TransitSchematic(
  canvasSize: Size(1500, 1000),
  lines: _lines,
  stations: _stations,
);

// ─────────────────────────────────────────────────────────────────────────────
// LINHAS
// ─────────────────────────────────────────────────────────────────────────────
const List<SchematicLine> _lines = [

  // L1 – Azul (vertical x=600)
  SchematicLine(
    lineCode: 'L1',
    points: [Offset(600, 80), Offset(600, 430), Offset(600, 625)],
    stationIds: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17],
  ),

  // L2 – Verde (diagonal NO→SE)
  SchematicLine(
    lineCode: 'L2',
    points: [Offset(325, 340), Offset(600, 560), Offset(760, 660)],
    stationIds: [25, 26, 27, 28, 29, 30, 15, 16, 33, 34, 35],
  ),

  // L3 – Vermelha (horizontal y=430)
  SchematicLine(
    lineCode: 'L3',
    points: [Offset(385, 430), Offset(600, 430), Offset(1020, 430)],
    stationIds: [36, 37, 38, 39, 40, 11, 42, 43, 44, 45, 46, 47, 48, 49],
  ),

  // L4 – Amarela (diagonal SO→NE até Luz)
  SchematicLine(
    lineCode: 'L4',
    points: [Offset(300, 725), Offset(517, 540), Offset(600, 360)],
    stationIds: [50, 51, 52, 53, 54, 9],
  ),

  // L5 – Lilás (horizontal sul)
  SchematicLine(
    lineCode: 'L5',
    points: [Offset(280, 735), Offset(620, 735), Offset(790, 650)],
    stationIds: [60, 62, 64, 66, 68, 70, 72, 73, 75, 76],
  ),

  // L7 – Rubi  (forma de "L" invertido)
  // Jundiaí ─── horizontal ─── corner(430,80) ─── diagonal ↘ ─── PBF ─── Luz
  SchematicLine(
    lineCode: 'L7',
    points: [
      Offset(100, 80),   // Jundiaí
      Offset(430, 80),   // corner (Baltazar Fidélis)
      Offset(385, 430),  // Palmeiras-Barra Funda
      Offset(600, 360),  // Luz
    ],
    stationIds: [
      209, 210, 211, 212, 207, 208, // horizontal: Jundiaí→Baltazar Fidélis
      206, 214, 213, 205, 204, 203, // diagonal: Franco da Rocha→Lapa
      36,                           // PBF
      9,                            // Luz
    ],
  ),

  // L8 – Diamante (horizontal: Júlio Prestes → PBF → oeste)
  SchematicLine(
    lineCode: 'L8',
    points: [Offset(600, 415), Offset(385, 430), Offset(50, 440)],
    stationIds: [220, 221, 223, 36, 224, 225, 226, 227, 228, 229, 230, 231, 232],
  ),

  // L9 – Esmeralda (diagonal NO→SO via Pinheiros)
  SchematicLine(
    lineCode: 'L9',
    points: [Offset(385, 430), Offset(517, 540), Offset(245, 700)],
    stationIds: [240, 241, 242, 243, 53, 245, 246, 247, 248, 249],
  ),

  // L10 – Turquesa (SE a partir de Brás)
  SchematicLine(
    lineCode: 'L10',
    points: [Offset(670, 430), Offset(785, 640), Offset(870, 865)],
    stationIds: [43, 261, 262, 263, 264, 265, 266, 267, 268],
  ),

  // L11 – Coral (leste: Luz/Brás/Tatuapé/Corinthians→Mogi)
  SchematicLine(
    lineCode: 'L11',
    points: [
      Offset(600, 360),
      Offset(670, 430),
      Offset(820, 430),
      Offset(1290, 320),
    ],
    stationIds: [9, 43, 46, 49, 284, 285, 286, 287, 288, 289, 290, 291],
  ),

  // L12 – Safira (SE de Brás/Tatuapé)
  SchematicLine(
    lineCode: 'L12',
    points: [Offset(670, 430), Offset(820, 430), Offset(1245, 548)],
    stationIds: [43, 46, 302, 303, 304, 305, 306, 307, 308, 309, 310],
  ),

  // L13 – Jade (NE → Aeroporto-Guarulhos)
  SchematicLine(
    lineCode: 'L13',
    points: [Offset(600, 360), Offset(840, 195), Offset(1250, 60)],
    stationIds: [9, 321, 322, 323, 324],
  ),

  // L15 – Prata (Vila Prudente → São Mateus)
  SchematicLine(
    lineCode: 'L15',
    points: [Offset(760, 660), Offset(990, 548), Offset(1120, 625)],
    stationIds: [35, 102, 103, 104, 105, 106, 107, 108, 109, 110, 101],
  ),

  // L17 – Ouro (AGV, área SO)
  SchematicLine(
    lineCode: 'L17',
    points: [Offset(535, 720), Offset(588, 635), Offset(625, 545)],
    stationIds: [340, 341, 342, 343, 344, 345],
  ),

  // LA – Santos-Jundiaí (SE de Brás)
  SchematicLine(
    lineCode: 'LA',
    points: [Offset(670, 430), Offset(820, 578), Offset(1010, 698)],
    stationIds: [43, 361, 362, 363, 364, 365, 366],
  ),

  // LB – Expresso Diamante (paralelo a L8, oeste)
  SchematicLine(
    lineCode: 'LB',
    points: [Offset(600, 415), Offset(385, 430), Offset(50, 420)],
    stationIds: [220, 36, 382, 383, 384],
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// ESTAÇÕES  (1500 × 1000)
// ─────────────────────────────────────────────────────────────────────────────
const List<SchematicStation> _stations = [

  // ── L1 Azul (vertical x=600) ─────────────────────────────────────────────
  SchematicStation(stationId: 1,  name: 'Tucuruvi',                    position: Offset(600,  80), labelSide: LabelSide.right),
  SchematicStation(stationId: 2,  name: 'Parada Inglesa',              position: Offset(600, 118), labelSide: LabelSide.right),
  SchematicStation(stationId: 3,  name: 'Jd. São Paulo-Ayrton Senna', position: Offset(600, 153), labelSide: LabelSide.right),
  SchematicStation(stationId: 4,  name: 'Santana',                     position: Offset(600, 187), labelSide: LabelSide.right),
  SchematicStation(stationId: 5,  name: 'Carandiru',                   position: Offset(600, 220), labelSide: LabelSide.right),
  SchematicStation(stationId: 6,  name: 'Portuguesa-Tietê',            position: Offset(600, 253), labelSide: LabelSide.right),
  SchematicStation(stationId: 7,  name: 'Armênia',                     position: Offset(600, 287), labelSide: LabelSide.right),
  SchematicStation(stationId: 8,  name: 'Tiradentes',                  position: Offset(600, 322), labelSide: LabelSide.right),
  SchematicStation(stationId: 9,  name: 'Luz',
    position: Offset(600, 360),
    isInterchange: true,
    lineCodes: ['L1', 'L4', 'L7', 'L11', 'L13'],
    maxCapacity: 3000,
    labelSide: LabelSide.right),
  SchematicStation(stationId: 10, name: 'São Bento',                   position: Offset(600, 396), labelSide: LabelSide.right),
  SchematicStation(stationId: 11, name: 'Sé',
    position: Offset(600, 430),
    isInterchange: true,
    lineCodes: ['L1', 'L3'],
    maxCapacity: 2500,
    labelSide: LabelSide.right),
  SchematicStation(stationId: 12, name: 'Liberdade',                   position: Offset(600, 464), labelSide: LabelSide.right),
  SchematicStation(stationId: 13, name: 'São Joaquim',                 position: Offset(600, 497), labelSide: LabelSide.right),
  SchematicStation(stationId: 14, name: 'Vergueiro',                   position: Offset(600, 528), labelSide: LabelSide.right),
  SchematicStation(stationId: 15, name: 'Paraíso',
    position: Offset(600, 558),
    isInterchange: true,
    lineCodes: ['L1', 'L2'],
    maxCapacity: 2000,
    labelSide: LabelSide.right),
  SchematicStation(stationId: 16, name: 'Ana Rosa',
    position: Offset(600, 588),
    isInterchange: true,
    lineCodes: ['L1', 'L2'],
    maxCapacity: 2000,
    labelSide: LabelSide.right),
  SchematicStation(stationId: 17, name: 'Vila Mariana',                position: Offset(600, 625), labelSide: LabelSide.right),

  // ── L2 Verde (diagonal NO→SE) ─────────────────────────────────────────────
  SchematicStation(stationId: 25, name: 'Vila Madalena',               position: Offset(325, 340), labelSide: LabelSide.above),
  SchematicStation(stationId: 26, name: 'Sumaré',                      position: Offset(385, 378), labelSide: LabelSide.above),
  SchematicStation(stationId: 27, name: 'Clínicas',                    position: Offset(440, 402), labelSide: LabelSide.above),
  SchematicStation(stationId: 28, name: 'Consolação',                  position: Offset(490, 416), labelSide: LabelSide.above),
  SchematicStation(stationId: 29, name: 'Trianon-Masp',                position: Offset(530, 424), labelSide: LabelSide.above),
  SchematicStation(stationId: 30, name: 'Brigadeiro',                  position: Offset(566, 428), labelSide: LabelSide.above),
  SchematicStation(stationId: 33, name: 'Chácara Klabin',              position: Offset(648, 615), labelSide: LabelSide.right),
  SchematicStation(stationId: 34, name: 'Santos-Imigrantes',           position: Offset(706, 638), labelSide: LabelSide.right),
  SchematicStation(stationId: 35, name: 'Vila Prudente',
    position: Offset(760, 660),
    isInterchange: true,
    lineCodes: ['L2', 'L15'],
    maxCapacity: 1800,
    labelSide: LabelSide.right),

  // ── L3 Vermelha (horizontal y=430) ───────────────────────────────────────
  SchematicStation(stationId: 36, name: 'Palmeiras-Barra Funda',
    position: Offset(385, 430),
    isInterchange: true,
    lineCodes: ['L3', 'L7', 'L8', 'LB'],
    maxCapacity: 2500,
    labelSide: LabelSide.below),
  SchematicStation(stationId: 37, name: 'Marechal Deodoro',            position: Offset(440, 430), labelSide: LabelSide.below),
  SchematicStation(stationId: 38, name: 'Santa Cecília',               position: Offset(488, 430), labelSide: LabelSide.below),
  SchematicStation(stationId: 39, name: 'República',                   position: Offset(532, 430), labelSide: LabelSide.below),
  SchematicStation(stationId: 40, name: 'Anhangabaú',                  position: Offset(564, 430), labelSide: LabelSide.above),
  SchematicStation(stationId: 42, name: 'Pedro II',                    position: Offset(634, 430), labelSide: LabelSide.above),
  SchematicStation(stationId: 43, name: 'Brás',
    position: Offset(672, 430),
    isInterchange: true,
    lineCodes: ['L3', 'L10', 'L11', 'L12', 'LA'],
    maxCapacity: 3000,
    labelSide: LabelSide.below),
  SchematicStation(stationId: 44, name: 'Bresser-Mooca',               position: Offset(734, 430), labelSide: LabelSide.above),
  SchematicStation(stationId: 45, name: 'Belém',                       position: Offset(780, 430), labelSide: LabelSide.below),
  SchematicStation(stationId: 46, name: 'Tatuapé',
    position: Offset(820, 430),
    isInterchange: true,
    lineCodes: ['L3', 'L11', 'L12'],
    maxCapacity: 2000,
    labelSide: LabelSide.above),
  SchematicStation(stationId: 47, name: 'Carrão',                      position: Offset(875, 430), labelSide: LabelSide.below),
  SchematicStation(stationId: 48, name: 'Penha',                       position: Offset(928, 430), labelSide: LabelSide.above),
  SchematicStation(stationId: 49, name: 'Corinthians-Itaquera',
    position: Offset(1020, 430),
    isInterchange: true,
    lineCodes: ['L3', 'L11'],
    maxCapacity: 2500,
    labelSide: LabelSide.below),

  // ── L4 Amarela (diagonal SO→NE) ──────────────────────────────────────────
  SchematicStation(stationId: 50, name: 'Vila Sônia',                  position: Offset(300, 725), labelSide: LabelSide.below),
  SchematicStation(stationId: 51, name: 'São Paulo-Morumbi',           position: Offset(368, 662), labelSide: LabelSide.left),
  SchematicStation(stationId: 52, name: 'Butantã',                     position: Offset(432, 602), labelSide: LabelSide.left),
  SchematicStation(stationId: 53, name: 'Pinheiros',
    position: Offset(517, 540),
    isInterchange: true,
    lineCodes: ['L4', 'L9'],
    maxCapacity: 2000,
    labelSide: LabelSide.left),
  SchematicStation(stationId: 54, name: 'Faria Lima',                  position: Offset(558, 503), labelSide: LabelSide.left),

  // ── L5 Lilás (horizontal sul) ─────────────────────────────────────────────
  SchematicStation(stationId: 60, name: 'Capão Redondo',               position: Offset(280, 735), labelSide: LabelSide.below),
  SchematicStation(stationId: 62, name: 'Campo Limpo',                 position: Offset(358, 735), labelSide: LabelSide.below),
  SchematicStation(stationId: 64, name: 'Vila das Belezas',            position: Offset(420, 735), labelSide: LabelSide.below),
  SchematicStation(stationId: 66, name: 'Giovanni Gronchi',            position: Offset(480, 735), labelSide: LabelSide.below),
  SchematicStation(stationId: 68, name: 'Socorro',                     position: Offset(537, 735), labelSide: LabelSide.below),
  SchematicStation(stationId: 70, name: 'Adolfo Pinheiro',             position: Offset(592, 735), labelSide: LabelSide.below),
  SchematicStation(stationId: 72, name: 'Alto da Boa Vista',           position: Offset(635, 715), labelSide: LabelSide.below),
  SchematicStation(stationId: 73, name: 'Brooklin',                    position: Offset(676, 695), labelSide: LabelSide.below),
  SchematicStation(stationId: 75, name: 'Eucaliptos',                  position: Offset(718, 675), labelSide: LabelSide.below),
  SchematicStation(stationId: 76, name: 'Moema',
    position: Offset(760, 655),
    isInterchange: true,
    lineCodes: ['L5', 'L17'],
    maxCapacity: 1800,
    labelSide: LabelSide.right),

  // ── L7 Rubi — seção horizontal NO (Y=80) ────────────────────────────────
  SchematicStation(stationId: 209, name: 'Jundiaí',                    position: Offset(100,  80), labelSide: LabelSide.above),
  SchematicStation(stationId: 210, name: 'Várzea Paulista',            position: Offset(165,  80), labelSide: LabelSide.above),
  SchematicStation(stationId: 211, name: 'Campo Limpo Paulista',       position: Offset(230,  80), labelSide: LabelSide.above),
  SchematicStation(stationId: 212, name: 'Botujuru',                   position: Offset(295,  80), labelSide: LabelSide.above),
  SchematicStation(stationId: 207, name: 'Francisco Morato',           position: Offset(358,  80), labelSide: LabelSide.above),
  SchematicStation(stationId: 208, name: 'Baltazar Fidélis',           position: Offset(430,  80), labelSide: LabelSide.right),

  // ── L7 Rubi — seção diagonal (corner→PBF) ────────────────────────────────
  SchematicStation(stationId: 206, name: 'Franco da Rocha',            position: Offset(424, 130), labelSide: LabelSide.right),
  SchematicStation(stationId: 214, name: 'Caieiras',                   position: Offset(417, 180), labelSide: LabelSide.right),
  SchematicStation(stationId: 213, name: 'Perus',                      position: Offset(411, 230), labelSide: LabelSide.right),
  SchematicStation(stationId: 205, name: 'Jaraguá',                    position: Offset(405, 280), labelSide: LabelSide.right),
  SchematicStation(stationId: 204, name: 'Pirituba',                   position: Offset(398, 330), labelSide: LabelSide.right),
  SchematicStation(stationId: 203, name: 'Lapa',
    position: Offset(392, 379),
    isInterchange: true,
    lineCodes: ['L7', 'L8'],
    maxCapacity: 1800,
    labelSide: LabelSide.right),

  // ── L8 Diamante (horizontal leste→oeste, y≈420) ──────────────────────────
  SchematicStation(stationId: 220, name: 'Júlio Prestes',
    position: Offset(600, 415),
    isInterchange: true,
    lineCodes: ['L8', 'LB'],
    maxCapacity: 2000,
    labelSide: LabelSide.above),
  SchematicStation(stationId: 221, name: 'Marechal Deodoro',           position: Offset(548, 418), labelSide: LabelSide.above),
  SchematicStation(stationId: 223, name: 'Lapa',                       position: Offset(460, 425), labelSide: LabelSide.above),
  SchematicStation(stationId: 224, name: 'Antônio João',               position: Offset(335, 434), labelSide: LabelSide.above),
  SchematicStation(stationId: 225, name: 'Amador Bueno',               position: Offset(278, 436), labelSide: LabelSide.above),
  SchematicStation(stationId: 226, name: 'Osasco',                     position: Offset(222, 437), labelSide: LabelSide.above),
  SchematicStation(stationId: 227, name: 'Presidente Altino',          position: Offset(168, 438), labelSide: LabelSide.above),
  SchematicStation(stationId: 228, name: 'Carapicuíba',                position: Offset(124, 439), labelSide: LabelSide.above),
  SchematicStation(stationId: 229, name: 'Santa Terezinha',            position: Offset( 93, 439), labelSide: LabelSide.above),
  SchematicStation(stationId: 230, name: 'Barueri',                    position: Offset( 68, 440), labelSide: LabelSide.above),
  SchematicStation(stationId: 231, name: 'Amador Bueno',               position: Offset( 54, 440), labelSide: LabelSide.below),
  SchematicStation(stationId: 232, name: 'Júlio de Mesquita',          position: Offset( 40, 440), labelSide: LabelSide.below),

  // ── L9 Esmeralda (diagonal NO→SO via Pinheiros) ───────────────────────────
  SchematicStation(stationId: 240, name: 'Osasco',                     position: Offset(328, 468), labelSide: LabelSide.left),
  SchematicStation(stationId: 241, name: 'Presidente Altino',          position: Offset(362, 495), labelSide: LabelSide.left),
  SchematicStation(stationId: 242, name: 'Ceasa',                      position: Offset(410, 517), labelSide: LabelSide.left),
  SchematicStation(stationId: 243, name: 'Villa-Lobos-Jaguaré',        position: Offset(460, 530), labelSide: LabelSide.left),
  SchematicStation(stationId: 245, name: 'Hebraica-Rebouças',          position: Offset(462, 562), labelSide: LabelSide.left),
  SchematicStation(stationId: 246, name: 'Cidade Jardim',              position: Offset(408, 598), labelSide: LabelSide.left),
  SchematicStation(stationId: 247, name: 'Granja Julieta',             position: Offset(352, 632), labelSide: LabelSide.left),
  SchematicStation(stationId: 248, name: 'Santo André-Saladino',       position: Offset(302, 658), labelSide: LabelSide.left),
  SchematicStation(stationId: 249, name: 'Jurubatuba',                 position: Offset(245, 700), labelSide: LabelSide.left),

  // ── L10 Turquesa (SE de Brás) ─────────────────────────────────────────────
  SchematicStation(stationId: 261, name: 'Tamanduateí',                position: Offset(720, 505), labelSide: LabelSide.right),
  SchematicStation(stationId: 262, name: 'Ipiranga',                   position: Offset(752, 572), labelSide: LabelSide.right),
  SchematicStation(stationId: 263, name: 'Utinga',                     position: Offset(778, 635), labelSide: LabelSide.right),
  SchematicStation(stationId: 264, name: 'Prefeito Celso Daniel',      position: Offset(800, 695), labelSide: LabelSide.right),
  SchematicStation(stationId: 265, name: 'Capuava',                    position: Offset(820, 748), labelSide: LabelSide.right),
  SchematicStation(stationId: 266, name: 'Mauá',                       position: Offset(838, 795), labelSide: LabelSide.right),
  SchematicStation(stationId: 267, name: 'Guapituba',                  position: Offset(852, 830), labelSide: LabelSide.right),
  SchematicStation(stationId: 268, name: 'Ribeirão Pires',             position: Offset(865, 865), labelSide: LabelSide.right),

  // ── L11 Coral (leste: Luz→Brás→Tatuapé→Corinthians→Mogi) ─────────────────
  SchematicStation(stationId: 284, name: 'Dom Bosco',                  position: Offset(1060, 420), labelSide: LabelSide.above),
  SchematicStation(stationId: 285, name: 'José Bonifácio',             position: Offset(1095, 405), labelSide: LabelSide.above),
  SchematicStation(stationId: 286, name: 'Guaianases',                 position: Offset(1130, 390), labelSide: LabelSide.above),
  SchematicStation(stationId: 287, name: 'Antônio Gianetti Neto',      position: Offset(1163, 375), labelSide: LabelSide.above),
  SchematicStation(stationId: 288, name: 'Ferraz de Vasconcelos',      position: Offset(1195, 360), labelSide: LabelSide.above),
  SchematicStation(stationId: 289, name: 'Poá',                        position: Offset(1222, 348), labelSide: LabelSide.above),
  SchematicStation(stationId: 290, name: 'Suzano',                     position: Offset(1248, 336), labelSide: LabelSide.above),
  SchematicStation(stationId: 291, name: 'Mogi das Cruzes',            position: Offset(1290, 320), labelSide: LabelSide.above),

  // ── L12 Safira (SE de Brás/Tatuapé) ──────────────────────────────────────
  SchematicStation(stationId: 302, name: 'Engenheiro Goulart',         position: Offset( 878, 455), labelSide: LabelSide.below),
  SchematicStation(stationId: 303, name: 'USP Leste',                  position: Offset( 935, 468), labelSide: LabelSide.below),
  SchematicStation(stationId: 304, name: 'Itaim Paulista',             position: Offset( 990, 482), labelSide: LabelSide.below),
  SchematicStation(stationId: 305, name: 'Jardim Romano',              position: Offset(1040, 495), labelSide: LabelSide.below),
  SchematicStation(stationId: 306, name: 'Engenheiro Manoel Feio',     position: Offset(1085, 508), labelSide: LabelSide.below),
  SchematicStation(stationId: 307, name: 'Calmon Viana',               position: Offset(1125, 520), labelSide: LabelSide.below),
  SchematicStation(stationId: 308, name: 'Poá',                        position: Offset(1162, 530), labelSide: LabelSide.below),
  SchematicStation(stationId: 309, name: 'Suzano',                     position: Offset(1195, 538), labelSide: LabelSide.below),
  SchematicStation(stationId: 310, name: 'Jundiapeba',                 position: Offset(1245, 548), labelSide: LabelSide.below),

  // ── L13 Jade (NE → Aeroporto) ────────────────────────────────────────────
  SchematicStation(stationId: 321, name: 'Guarulhos-Cecap',            position: Offset( 718, 277), labelSide: LabelSide.right),
  SchematicStation(stationId: 322, name: 'Guarulhos-Pimentas',         position: Offset( 840, 195), labelSide: LabelSide.right),
  SchematicStation(stationId: 323, name: 'Cumbica',                    position: Offset( 980, 118), labelSide: LabelSide.right),
  SchematicStation(stationId: 324, name: 'Aeroporto-Guarulhos',        position: Offset(1250,  60), labelSide: LabelSide.right),

  // ── L15 Prata (Vila Prudente → São Mateus) ───────────────────────────────
  SchematicStation(stationId: 101, name: 'São Mateus',                 position: Offset(1120, 625), labelSide: LabelSide.right),
  SchematicStation(stationId: 102, name: 'São Lucas',                  position: Offset(1050, 585), labelSide: LabelSide.above),
  SchematicStation(stationId: 103, name: 'Camilo Haddad',              position: Offset( 990, 548), labelSide: LabelSide.above),
  SchematicStation(stationId: 104, name: 'Vila Tolstói',               position: Offset( 930, 517), labelSide: LabelSide.above),
  SchematicStation(stationId: 105, name: 'Vila União',                 position: Offset( 875, 490), labelSide: LabelSide.above),
  SchematicStation(stationId: 106, name: 'Jardim Planalto',            position: Offset( 825, 468), labelSide: LabelSide.above),
  SchematicStation(stationId: 107, name: 'Sapopemba',                  position: Offset( 800, 455), labelSide: LabelSide.above),
  SchematicStation(stationId: 108, name: 'Fazenda da Juta',            position: Offset( 785, 448), labelSide: LabelSide.above),
  SchematicStation(stationId: 109, name: 'São Paulo-Morumbi',          position: Offset( 772, 443), labelSide: LabelSide.below),
  SchematicStation(stationId: 110, name: 'Oratório',                   position: Offset( 908, 530), labelSide: LabelSide.above),

  // ── L17 Ouro (AGV, área SO) ───────────────────────────────────────────────
  SchematicStation(stationId: 340, name: 'Congonhas',                  position: Offset(535, 720), labelSide: LabelSide.below),
  SchematicStation(stationId: 341, name: 'Santa Cruz',                 position: Offset(562, 672), labelSide: LabelSide.left),
  SchematicStation(stationId: 342, name: 'Borba Gato',                 position: Offset(574, 636), labelSide: LabelSide.left),
  SchematicStation(stationId: 343, name: 'Morumbi',                    position: Offset(594, 600), labelSide: LabelSide.left),
  SchematicStation(stationId: 344, name: 'Brooklin',                   position: Offset(610, 565), labelSide: LabelSide.left),
  SchematicStation(stationId: 345, name: 'Eucaliptos',                 position: Offset(625, 545), labelSide: LabelSide.left),

  // ── LA Santos-Jundiaí (SE de Brás) ───────────────────────────────────────
  SchematicStation(stationId: 361, name: 'Mooca',                      position: Offset( 710, 508), labelSide: LabelSide.right),
  SchematicStation(stationId: 362, name: 'São Caetano do Sul',         position: Offset( 820, 578), labelSide: LabelSide.right),
  SchematicStation(stationId: 363, name: 'Santo André',                position: Offset( 910, 638), labelSide: LabelSide.right),
  SchematicStation(stationId: 364, name: 'São Bernardo',               position: Offset(1010, 698), labelSide: LabelSide.right),
  SchematicStation(stationId: 365, name: 'Diadema',                    position: Offset( 637, 888), labelSide: LabelSide.below),
  SchematicStation(stationId: 366, name: 'Santos',                     position: Offset( 713, 888), labelSide: LabelSide.below),

  // ── LB Expresso Diamante (paralelo a L8, oeste) ──────────────────────────
  SchematicStation(stationId: 382, name: 'Osasco',                     position: Offset(222, 420), labelSide: LabelSide.above),
  SchematicStation(stationId: 383, name: 'Carapicuíba',                position: Offset(124, 420), labelSide: LabelSide.above),
  SchematicStation(stationId: 384, name: 'Amador Bueno',               position: Offset( 50, 420), labelSide: LabelSide.above),
];
