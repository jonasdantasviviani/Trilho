# Trilho - Design System Documentation

## Como Importar no Figma

### Opção 1: Figma Tokens (Plugin)
1. Instale o plugin **Figma Tokens** no Figma
2. Abra o arquivo `design-tokens.json`
3. No plugin, clique em **Import from JSON**
4. Os tokens serão convertidos em estilos do Figma

### Opção 2: Token Studio
1. Instale o plugin **Token Studio** no Figma
2. Importe o arquivo `design-tokens.json`
3. Sync automática com estilos de cor, texto e espaçamento

### Opção 3: Importar Cores Manualmente
1. Abra o arquivo `linhas-cores.csv` no Excel/Google Sheets
2. Copie os dados
3. Cole em uma tabela no Figma
4. Use para criar swatches de cores

---

## Estrutura de Arquivos

```
design/
├── README.md              # Este arquivo
├── design-tokens.json     # Tokens completos (para plugins)
└── linhas-cores.csv      # Cores das linhas (importar como tabela)
```

---

## Componentes Principais

### Tela: Mapa Principal
- **Header**: Logo + Seletor de cidade
- **Chips de linha**: Botões coloridos para filtrar
- **Mapa**: Google Maps com marcadores de estação
- **Bottom Sheet**: Detalhes ao tocar estação

### Tela: Detalhe da Linha
- **Status Banner**: Cor da linha + status operacional
- **Estações List**: Cards com indicador de lotação
- **Filtros**: Por lotação, horário

### Tela: Detalhe da Estação
- **Header**: Nome + linha
- **Indicador Lotação**: Badge colorido grande
- **Gráfico**: Histórico de lotação (fl_chart)
- **Info**: Capacidade, próxima linha

### Tela: Paywall
- **Header**: Benefícios
- **Cards**: Preço + funcionalidades
- **CTA**: Assinar / Restaurar

---

## Cores de Status

| Badge | Cor | Uso |
|-------|-----|-----|
| 🟢 Tranquilo | #4CAF50 | Lotação < 30% |
| 🟡 Moderado | #FFC107 | Lotação 30-60% |
| 🟠 Cheio | #FF9800 | Lotação 60-85% |
| 🔴 Lotado | #F44336 | Lotação > 85% |

---

## Tipografia

| Estilo | Tamanho | Peso | Uso |
|--------|---------|------|-----|
| Display Large | 32px | 700 | Títulos principais |
| Headline Large | 20px | 600 | Títulos de seção |
| Title Medium | 14px | 500 | Labels, botões |
| Body Large | 16px | 400 | Texto principal |
| Body Medium | 14px | 400 | Texto secundário |
| Label Small | 11px | 500 | Badges, captions |

---

## Ícones

Usar **Material Symbols Rounded**:
- Material Icons → Settings
- Weight: 400 (Regular)
- Optical size: 24px

Ícones principais:
- `train` - Metrô/Trem
- `directions_bus` - Ônibus
- `location_on` - Estação
- `people` - Lotação
- `settings` - Configurações
- `person` - Usuário
- `chevron_right` - Navegação
- `close` - Fechar
- `check_circle` - Selecionado
- `warning` - Alerta
