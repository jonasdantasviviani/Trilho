// Trilho Design System Generator
// Cria color styles, text styles e frames de documentação no Figma

async function main() {
  // ── Preload all fonts ──────────────────────────────────────────────────────
  await Promise.all([
    figma.loadFontAsync({ family: 'Inter', style: 'Regular' }),
    figma.loadFontAsync({ family: 'Inter', style: 'Medium' }),
    figma.loadFontAsync({ family: 'Inter', style: 'Bold' }),
    figma.loadFontAsync({ family: 'Inter', style: 'Extra Bold' }),
  ]);

  // ── Helpers ────────────────────────────────────────────────────────────────
  function hexToRgb(hex) {
    return {
      r: parseInt(hex.slice(1, 3), 16) / 255,
      g: parseInt(hex.slice(3, 5), 16) / 255,
      b: parseInt(hex.slice(5, 7), 16) / 255,
    };
  }

  function weightToStyle(w) {
    return { 400: 'Regular', 500: 'Medium', 700: 'Bold', 800: 'Extra Bold' }[w] || 'Regular';
  }

  function makeColorStyle(name, hexColor, opacity = 1) {
    const s = figma.createPaintStyle();
    s.name = name;
    s.paints = [{ type: 'SOLID', color: hexToRgb(hexColor), opacity }];
    return s;
  }

  function makeTextStyle(name, size, weight, letterSpacing = 0, lineHeight = { unit: 'AUTO' }) {
    const s = figma.createTextStyle();
    s.name = name;
    s.fontSize = size;
    s.fontName = { family: 'Inter', style: weightToStyle(weight) };
    s.letterSpacing = { value: letterSpacing, unit: 'PIXELS' };
    s.lineHeight = lineHeight;
    return s;
  }

  function addRect(parent, x, y, w, h, hexColor, opacity = 1, radius = 0) {
    const r = figma.createRectangle();
    r.x = x; r.y = y;
    r.resize(w, h);
    r.fills = [{ type: 'SOLID', color: hexToRgb(hexColor), opacity }];
    r.cornerRadius = radius;
    parent.appendChild(r);
    return r;
  }

  function addText(parent, content, x, y, size, weight, hexColor, maxWidth = 0) {
    const t = figma.createText();
    t.characters = content;
    t.fontSize = size;
    t.fontName = { family: 'Inter', style: weightToStyle(weight) };
    t.fills = [{ type: 'SOLID', color: hexToRgb(hexColor) }];
    t.x = x; t.y = y;
    if (maxWidth > 0) {
      t.textAutoResize = 'HEIGHT';
      t.resize(maxWidth, t.height);
    }
    parent.appendChild(t);
    return t;
  }

  function addFrame(parent, name, x, y, w, h, bgHex = '#0A0A14') {
    const f = figma.createFrame();
    f.name = name;
    f.x = x; f.y = y;
    f.resize(w, h);
    f.fills = [{ type: 'SOLID', color: hexToRgb(bgHex) }];
    parent.appendChild(f);
    return f;
  }

  function sectionLabel(parent, label, x, y) {
    addText(parent, label, x, y, 10, 500, '#8888AA');
  }

  // ── Create / get page ──────────────────────────────────────────────────────
  let page = figma.root.findChild(n => n.name === '🎨 Trilho Design System');
  if (!page) {
    page = figma.createPage();
    page.name = '🎨 Trilho Design System';
  }
  figma.currentPage = page;

  // ── 1. Color Styles ────────────────────────────────────────────────────────
  const colorDefs = [
    // Dark
    ['Dark/Background',      '#0A0A14'],
    ['Dark/Surface',         '#13131F'],
    ['Dark/Surface Raised',  '#1C1C2E'],
    ['Dark/Border',          '#2A2A3A'],
    ['Dark/Text Primary',    '#FFFFFF'],
    ['Dark/Text Secondary',  '#8888AA'],
    ['Dark/Text Disabled',   '#444455'],
    // Light
    ['Light/Background',     '#F5F5F7'],
    ['Light/Surface',        '#FFFFFF'],
    ['Light/Surface Raised', '#EFEFEF'],
    ['Light/Border',         '#E0E0E8'],
    ['Light/Text Primary',   '#0A0A14'],
    ['Light/Text Secondary', '#555566'],
    ['Light/Text Disabled',  '#AAAABC'],
    // Brand
    ['Brand/Primary',        '#0055FF'],
    ['Brand/Accent',         '#00C8FF'],
    // Semantic
    ['Semantic/Success',     '#22CC88'],
    ['Semantic/Warning',     '#FFB800'],
    ['Semantic/Danger',      '#FF4455'],
    // Crowd
    ['Crowd/Empty',          '#22CC88'],
    ['Crowd/Low',            '#88DD44'],
    ['Crowd/Moderate',       '#FFB800'],
    ['Crowd/High',           '#FF7722'],
    ['Crowd/Full',           '#FF4455'],
  ];
  colorDefs.forEach(([n, h]) => makeColorStyle(n, h));
  makeColorStyle('Brand/Primary Dim', '#0055FF', 0.15);
  makeColorStyle('Brand/Accent Dim',  '#00C8FF', 0.15);

  // ── 2. Text Styles ─────────────────────────────────────────────────────────
  makeTextStyle('Type/3XL · Extra Bold', 32, 800, -0.5);
  makeTextStyle('Type/2XL · Extra Bold', 24, 800, -0.5);
  makeTextStyle('Type/XL · Bold',        20, 700, -0.3);
  makeTextStyle('Type/LG · Bold',        16, 700,  0);
  makeTextStyle('Type/MD · Medium',      14, 500,  0);
  makeTextStyle('Type/SM · Regular',     12, 400,  0);
  makeTextStyle('Type/XS · Bold',        10, 700,  1);

  // ── 3. Frame: Colors ───────────────────────────────────────────────────────
  const colFrame = addFrame(page, '🎨 Colors', 0, 0, 960, 640);

  addText(colFrame, 'Cores',            32, 32, 20, 700, '#FFFFFF');
  addText(colFrame, 'Design tokens',    32, 60, 12, 400, '#8888AA');

  const swatches = [
    { label: 'Background',     hex: '#0A0A14', tx: '#8888AA' },
    { label: 'Surface',        hex: '#13131F', tx: '#8888AA' },
    { label: 'Surface Raised', hex: '#1C1C2E', tx: '#8888AA' },
    { label: 'Border',         hex: '#2A2A3A', tx: '#8888AA' },
    { label: 'Primary',        hex: '#0055FF', tx: '#FFFFFF' },
    { label: 'Accent',         hex: '#00C8FF', tx: '#0A0A14' },
    { label: 'Success',        hex: '#22CC88', tx: '#0A0A14' },
    { label: 'Warning',        hex: '#FFB800', tx: '#0A0A14' },
    { label: 'Danger',         hex: '#FF4455', tx: '#FFFFFF' },
    { label: 'Crowd · Vazio',  hex: '#22CC88', tx: '#0A0A14' },
    { label: 'Crowd · Baixo',  hex: '#88DD44', tx: '#0A0A14' },
    { label: 'Crowd · Mod.',   hex: '#FFB800', tx: '#0A0A14' },
    { label: 'Crowd · Alto',   hex: '#FF7722', tx: '#FFFFFF' },
    { label: 'Crowd · Lotado', hex: '#FF4455', tx: '#FFFFFF' },
  ];

  const SW = 116, SH = 72, GX = 14, GY = 52, COLS = 7;
  swatches.forEach((s, i) => {
    const col = i % COLS;
    const row = Math.floor(i / COLS);
    const x = 32 + col * (SW + GX);
    const y = 96 + row * (SH + GY);
    addRect(colFrame, x, y, SW, SH, s.hex, 1, 8);
    addText(colFrame, s.label,       x,     y + SH + 6,  9, 400, '#8888AA');
    addText(colFrame, s.hex.toUpperCase(), x, y + SH + 20, 9, 700, '#FFFFFF');
  });

  // Dark vs Light chip
  sectionLabel(colFrame, 'Dark mode → Light mode', 32, 548);
  addRect(colFrame, 32,  568, 120, 40, '#0A0A14', 1, 8);
  addRect(colFrame, 164, 568, 120, 40, '#F5F5F7', 1, 8);
  addText(colFrame, '#0A0A14 · bg', 40,  580, 10, 500, '#8888AA');
  addText(colFrame, '#F5F5F7 · bg', 172, 580, 10, 500, '#555566');

  // ── 4. Frame: Typography ───────────────────────────────────────────────────
  const tyFrame = addFrame(page, '🔤 Typography', 1000, 0, 720, 600);

  addText(tyFrame, 'Tipografia', 32, 32, 20, 700, '#FFFFFF');
  addText(tyFrame, 'Inter · 7 níveis',  32, 60, 12, 400, '#8888AA');

  const tyDefs = [
    { name: '3XL · 32 · ExtraBold', sample: 'Trilho',                   size: 32, w: 800 },
    { name: '2XL · 24 · ExtraBold', sample: 'Design System',            size: 24, w: 800 },
    { name: 'XL · 20 · Bold',       sample: 'Mobilidade em tempo real', size: 20, w: 700 },
    { name: 'LG · 16 · Bold',       sample: 'Estação República',        size: 16, w: 700 },
    { name: 'MD · 14 · Medium',     sample: 'Próximo trem em 4 min',    size: 14, w: 500 },
    { name: 'SM · 12 · Regular',    sample: 'Lotação: Moderada',         size: 12, w: 400 },
    { name: 'XS · 10 · Bold',       sample: 'L1 · AZUL · NORMAL',       size: 10, w: 700 },
  ];

  let ty = 96;
  tyDefs.forEach(d => {
    sectionLabel(tyFrame, d.name, 32, ty);
    ty += 16;
    addText(tyFrame, d.sample, 32, ty, d.size, d.w, '#FFFFFF', 640);
    ty += d.size + 24;
  });

  // ── 5. Frame: Components ──────────────────────────────────────────────────
  const compFrame = addFrame(page, '🧩 Components', 1000, 640, 720, 560);

  addText(compFrame, 'Componentes', 32, 32, 20, 700, '#FFFFFF');
  addText(compFrame, 'Botões · Chips · Crowd · Badges', 32, 60, 12, 400, '#8888AA');

  // Buttons
  sectionLabel(compFrame, 'Buttons', 32, 96);
  addRect(compFrame, 32,  112, 180, 48, '#0055FF', 1, 12);
  addText(compFrame, 'Entrar', 85, 128, 14, 700, '#FFFFFF');

  const ghost = figma.createRectangle();
  ghost.x = 228; ghost.y = 112; ghost.resize(180, 48);
  ghost.fills = [{ type: 'SOLID', color: hexToRgb('#0A0A14'), opacity: 0 }];
  ghost.strokes = [{ type: 'SOLID', color: hexToRgb('#2A2A3A') }];
  ghost.strokeWeight = 1.5;
  ghost.cornerRadius = 12;
  compFrame.appendChild(ghost);
  addText(compFrame, 'Continuar sem conta', 248, 128, 12, 500, '#8888AA');

  // Line Chips
  sectionLabel(compFrame, 'Line Chips', 32, 182);
  const chipData = [
    { code: 'L1', hex: '#0055DD' },
    { code: 'L2', hex: '#00AA44' },
    { code: 'L3', hex: '#EE2222' },
    { code: 'L4', hex: '#FFDD00' },
    { code: 'L5', hex: '#9944CC' },
    { code: 'L4Y', hex: '#FFD700' },
    { code: 'L7', hex: '#CC6600' },
    { code: 'L8', hex: '#888888' },
    { code: 'L9', hex: '#00AAAA' },
  ];
  let cx = 32;
  chipData.forEach(c => {
    const cw = c.code.length <= 2 ? 36 : 42;
    addRect(compFrame, cx, 196, cw, 24, c.hex, 1, 6);
    const lum = hexToRgb(c.hex);
    const bright = 0.299 * lum.r + 0.587 * lum.g + 0.114 * lum.b;
    addText(compFrame, c.code, cx + 4, 200, 9, 700, bright > 0.5 ? '#0A0A14' : '#FFFFFF');
    cx += cw + 6;
  });

  // Crowd Bars
  sectionLabel(compFrame, 'Crowd Bars', 32, 246);
  const crowdData = [
    { label: 'Vazio',    hex: '#22CC88', pct: 0.08 },
    { label: 'Baixo',    hex: '#88DD44', pct: 0.30 },
    { label: 'Moderado', hex: '#FFB800', pct: 0.55 },
    { label: 'Alto',     hex: '#FF7722', pct: 0.78 },
    { label: 'Lotado',   hex: '#FF4455', pct: 1.00 },
  ];
  let crY = 262;
  crowdData.forEach(c => {
    addRect(compFrame, 32, crY, 240, 12, '#1C1C2E', 1, 6);
    addRect(compFrame, 32, crY, Math.round(240 * c.pct), 12, c.hex, 1, 6);
    addText(compFrame, c.label, 284, crY, 10, 500, '#8888AA');
    crY += 30;
  });

  // Status Badges
  sectionLabel(compFrame, 'Status Badges', 32, 420);
  const badgeData = [
    { label: 'Normal',   bg: '#22CC88', tx: '#22CC88' },
    { label: 'Lentidão', bg: '#FFB800', tx: '#FFB800' },
    { label: 'Parada',   bg: '#FF4455', tx: '#FF4455' },
    { label: 'Em obras', bg: '#FFB800', tx: '#FFB800' },
  ];
  let bx = 32;
  badgeData.forEach(b => {
    const bw = b.label.length * 7 + 24;
    addRect(compFrame, bx, 436, bw, 26, b.bg, 0.12, 20);
    addText(compFrame, b.label, bx + 12, 442, 10, 700, b.tx);
    bx += bw + 10;
  });

  // ── 6. Frame: Logo ────────────────────────────────────────────────────────
  const logoFrame = addFrame(page, '◈ Logo', 0, 680, 960, 300);

  addText(logoFrame, 'Logo', 32, 32, 20, 700, '#FFFFFF');
  addText(logoFrame, 'Símbolo + Wordmark · Dark & Light', 32, 60, 12, 400, '#8888AA');

  // Dark version
  addRect(logoFrame, 32, 92, 280, 172, '#0D0D1A', 1, 16);
  // Network node icon
  addEllipse(logoFrame, 72,  166, 18, 18, '#00C8FF');  // left node
  addEllipse(logoFrame, 140, 166, 18, 18, '#00C8FF');  // right node
  addLine(logoFrame,  90, 175, 140, 175, '#00C8FF', 2.5);
  addEllipse(logoFrame, 106, 132, 14, 14, '#0055FF');  // top node
  addLine(logoFrame, 113, 146, 113, 166, '#0055FF', 2);
  addEllipse(logoFrame, 106, 200, 14, 14, '#0055FF');  // bottom node
  addLine(logoFrame, 113, 184, 113, 200, '#0055FF', 2);
  // Wordmark
  addText(logoFrame, 'TRILHO', 176, 152, 28, 800, '#00C8FF');
  addText(logoFrame, 'Mobilidade em tempo real', 176, 190, 11, 400, '#8888AA');

  // Light version
  addRect(logoFrame, 340, 92, 280, 172, '#F5F5F7', 1, 16);
  addEllipse(logoFrame, 380, 166, 18, 18, '#00C8FF');
  addEllipse(logoFrame, 448, 166, 18, 18, '#00C8FF');
  addLine(logoFrame,  398, 175, 448, 175, '#00C8FF', 2.5);
  addEllipse(logoFrame, 414, 132, 14, 14, '#0055FF');
  addLine(logoFrame, 421, 146, 421, 166, '#0055FF', 2);
  addEllipse(logoFrame, 414, 200, 14, 14, '#0055FF');
  addLine(logoFrame, 421, 184, 421, 200, '#0055FF', 2);
  addText(logoFrame, 'TRILHO', 484, 152, 28, 800, '#0055FF');
  addText(logoFrame, 'Mobilidade em tempo real', 484, 190, 11, 400, '#555566');

  // Icon-only (app icon)
  addRect(logoFrame, 648, 92, 72, 72, '#0A0A14', 1, 16);
  addEllipse(logoFrame, 656, 122, 12, 12, '#00C8FF');
  addEllipse(logoFrame, 700, 122, 12, 12, '#00C8FF');
  addLine(logoFrame,  668, 128, 700, 128, '#00C8FF', 2);
  addEllipse(logoFrame, 678, 100, 10, 10, '#0055FF');
  addLine(logoFrame, 683, 110, 683, 122, '#0055FF', 1.5);
  addEllipse(logoFrame, 678, 144, 10, 10, '#0055FF');
  addLine(logoFrame, 683, 134, 683, 144, '#0055FF', 1.5);
  addText(logoFrame, 'App Icon\n72×72', 648, 172, 9, 400, '#8888AA');

  // Zoom out to show all frames
  figma.viewport.scrollAndZoomIntoView([colFrame, tyFrame, compFrame, logoFrame]);

  figma.closePlugin('✅ Trilho Design System gerado com sucesso!');
}

// ── Shape helpers outside main ─────────────────────────────────────────────
function addEllipse(parent, x, y, w, h, hexColor) {
  const e = figma.createEllipse();
  e.x = x; e.y = y;
  e.resize(w, h);
  e.fills = [{ type: 'SOLID', color: hexToRgbGlobal(hexColor) }];
  parent.appendChild(e);
  return e;
}

function addLine(parent, x1, y1, x2, y2, hexColor, weight = 2) {
  const ln = figma.createLine();
  ln.x = x1; ln.y = y1;
  const dx = x2 - x1, dy = y2 - y1;
  ln.resize(Math.sqrt(dx * dx + dy * dy), 0);
  ln.rotation = -Math.atan2(dy, dx) * (180 / Math.PI);
  ln.strokes = [{ type: 'SOLID', color: hexToRgbGlobal(hexColor) }];
  ln.strokeWeight = weight;
  ln.fills = [];
  parent.appendChild(ln);
  return ln;
}

function hexToRgbGlobal(hex) {
  return {
    r: parseInt(hex.slice(1, 3), 16) / 255,
    g: parseInt(hex.slice(3, 5), 16) / 255,
    b: parseInt(hex.slice(5, 7), 16) / 255,
  };
}

main().catch(err => figma.closePlugin('❌ Erro: ' + err.message));
