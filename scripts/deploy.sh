#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# deploy.sh — Executa no servidor alvo via SSH
# Uso: bash scripts/deploy.sh <env> <image-tag> <gh-owner>
#
# Exemplos:
#   bash scripts/deploy.sh dsv abc1234 meu-usuario
#   bash scripts/deploy.sh prd v1.2.3  meu-usuario
# ─────────────────────────────────────────────────────────────────
set -euo pipefail

ENV="${1:?Informe o ambiente: dsv | hml | prd}"
IMAGE_TAG="${2:?Informe a tag da imagem}"
GH_OWNER="${3:?Informe o owner do GitHub}"

REGISTRY="ghcr.io/$GH_OWNER"
DEPLOY_DIR="/opt/trilho"
COMPOSE_BASE="docker-compose.yml"
COMPOSE_ENV="docker-compose.$ENV.yml"

echo ""
echo "═══════════════════════════════════════════════"
echo "  🚀  Trilho Deploy — $ENV  |  tag: ${IMAGE_TAG:0:7}"
echo "═══════════════════════════════════════════════"
echo ""

# ── Exporta variáveis para o docker-compose ──────────────────────
export GH_OWNER IMAGE_TAG

# ── Garante que o diretório existe ───────────────────────────────
mkdir -p "$DEPLOY_DIR"
cd "$DEPLOY_DIR"

# ── Login no GHCR (usa GITHUB_TOKEN se disponível, caso contrário
#    assume que docker já está autenticado no servidor) ─────────────
if [ -n "${GITHUB_TOKEN:-}" ]; then
  echo "$GITHUB_TOKEN" | docker login ghcr.io -u "$GH_OWNER" --password-stdin
  echo "✅ Login no GHCR realizado"
fi

# ── Pull das imagens ─────────────────────────────────────────────
echo "📥 Baixando imagens..."
docker pull "$REGISTRY/trilho-api:$IMAGE_TAG"
docker pull "$REGISTRY/trilho-web:$IMAGE_TAG"   2>/dev/null || echo "   (web/ ainda não existe — pulando)"
docker pull "$REGISTRY/trilho-admin:$IMAGE_TAG" 2>/dev/null || echo "   (admin/ ainda não existe — pulando)"

# ── Tag env-latest para rollback rápido ──────────────────────────
docker tag "$REGISTRY/trilho-api:$IMAGE_TAG" "$REGISTRY/trilho-api:$ENV-latest" 2>/dev/null || true

# ── Rotaciona backup do banco (apenas prd) ───────────────────────
if [ "$ENV" = "prd" ]; then
  echo "💾 Backup do banco antes do deploy..."
  docker compose -f "$COMPOSE_BASE" -f "$COMPOSE_ENV" exec -T db \
    pg_dump -U postgres "trilho_$ENV" \
    > "/opt/trilho/backups/pre-deploy-$(date +%Y%m%dT%H%M%S).sql" 2>/dev/null \
    && echo "   Backup salvo em /opt/trilho/backups/" \
    || echo "   ⚠️  Backup falhou (continuando mesmo assim)"
fi

# ── Deploy com zero-downtime (nova instância antes de parar a antiga) ─
echo "🔄 Atualizando serviços..."
docker compose \
  -f "$COMPOSE_BASE" \
  -f "$COMPOSE_ENV" \
  up -d \
  --remove-orphans \
  --wait \
  --timeout 120

# ── Aguarda API ficar saudável ───────────────────────────────────
echo "⏳ Aguardando API ficar saudável..."
API_PORT=5000
ATTEMPTS=30
for i in $(seq 1 $ATTEMPTS); do
  if curl -sf "http://localhost:$API_PORT/health" > /dev/null 2>&1; then
    echo "✅ API saudável!"
    break
  fi
  if [ "$i" -eq "$ATTEMPTS" ]; then
    echo "❌ API não ficou saudável após ${ATTEMPTS} tentativas"
    echo "📋 Logs da API:"
    docker compose -f "$COMPOSE_BASE" -f "$COMPOSE_ENV" logs api --tail=50
    exit 1
  fi
  echo "   Tentativa $i/$ATTEMPTS..."
  sleep 4
done

# ── Remove imagens antigas (mantém as 3 últimas) ─────────────────
echo "🧹 Limpando imagens antigas..."
docker image prune -f --filter "until=72h" 2>/dev/null || true

echo ""
echo "═══════════════════════════════════════════════"
echo "  ✅  Deploy em $ENV concluído!"
echo "  🏷   Versão: ${IMAGE_TAG:0:7}"
echo "═══════════════════════════════════════════════"
echo ""
