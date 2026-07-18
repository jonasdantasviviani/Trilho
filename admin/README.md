# Trilho Admin Dashboard

Dashboard administrativo para gerenciar o aplicativo Trilho.

## Stack

- **Framework**: Next.js 14 (App Router)
- **UI**: Componentes customizados + CSS Modules
- **Charts**: Recharts
- **Icons**: Lucide React

## Páginas

### Dashboard (`/dashboard`)
- Visão geral com métricas principais
- Gráfico de consultas por hora
- Linhas com problemas operacionais
- Estações mais consultadas

### Usuários (`/dashboard/users`)
- Lista de todos os usuários
- Busca e filtros
- Toggle VIP
- Gerenciamento de acessos

### Linhas (`/dashboard/lines`)
- Status em tempo real de todas as linhas
- Gráfico de lotação por linha
- Histórico de atualizações
- Filtros por tipo (Metrô/CPTM)

### Analytics (`/dashboard/analytics`)
- Receita MRR
- Taxa de conversão
- Churn rate
- Gráficos de uso por dispositivo

### Configurações (`/dashboard/settings`)
- Token OlhoVivo API
- Notificações
- Cidades ativas
- Dados do sistema

## Instalação

```bash
cd admin
npm install
npm run dev
```

## Variáveis de Ambiente

```bash
NEXT_PUBLIC_API_URL=http://localhost:5000
```

## API Endpoints Admin

| Método | Endpoint | Descrição |
|--------|----------|-----------|
| POST | `/api/admin/login` | Login admin |
| GET | `/api/admin/users` | Lista de usuários |
| GET | `/api/admin/stats` | Estatísticas |
| GET | `/api/admin/lines/status` | Status das linhas |
| GET | `/api/admin/analytics` | Analytics |
| PATCH | `/api/admin/users/:id/vip` | Toggle VIP |

## Build

```bash
npm run build
npm start
```
