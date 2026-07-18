# Configuração de Secrets e Environments no GitHub

## 1. Criar os Environments

No GitHub, vá em **Settings → Environments** e crie três environments:

| Environment | Branch | Proteção |
|-------------|--------|----------|
| `dsv` | `develop` | Nenhuma (deploy automático) |
| `hml` | `staging` | Nenhuma (deploy automático) |
| `prd` | `master`  | **Required reviewers** (pelo menos 1 aprovador) |

Para `prd`: ative *"Required reviewers"* e adicione os revisores autorizados.

---

## 2. Secrets por Environment

Configure os secrets abaixo em cada environment (**Settings → Environments → [env] → Add secret**):

### Secrets de Infraestrutura (por environment)

| Secret | Descrição | dsv | hml | prd |
|--------|-----------|-----|-----|-----|
| `SSH_HOST` | IP ou hostname do servidor | IP do servidor dsv | IP do servidor hml | IP do servidor prd |
| `SSH_USER` | Usuário SSH (ex: `deploy`) | ✅ | ✅ | ✅ |
| `SSH_KEY` | Chave SSH privada (conteúdo do `~/.ssh/id_ed25519`) | ✅ | ✅ | ✅ |
| `DSV_API_URL` | URL pública da API dsv (ex: `http://dsv-api.trilho.app`) | ✅ | — | — |
| `HML_API_URL` | URL pública da API hml | — | ✅ | — |
| `PRD_API_URL` | URL pública da API prd | — | — | ✅ |

### Secrets de Aplicação (por environment)

| Secret | Descrição |
|--------|-----------|
| `JWT_SECRET` | Chave secreta para assinar JWTs (mín. 32 chars) — **diferente por ambiente** |
| `ADMIN_API_KEY` | Chave do header `X-Admin-Key` para rotas admin |
| `FIREBASE_PROJECT_ID` | ID do projeto Firebase |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | JSON da service account do Firebase, codificado em **base64** |
| `OLHOVIVO_TOKEN` | Token da API OlhoVivo SPTrans |
| `NEXTAUTH_SECRET` | Segredo do NextAuth (mín. 32 chars) |
| `NEXT_PUBLIC_FIREBASE_API_KEY` | API Key pública do Firebase |
| `NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN` | Auth domain do Firebase |
| `NEXT_PUBLIC_FIREBASE_PROJECT_ID` | Project ID público do Firebase |
| `NEXT_PUBLIC_GOOGLE_MAPS_API_KEY` | API Key do Google Maps |

---

## 3. Preparar o servidor (por ambiente)

Execute no servidor antes do primeiro deploy:

```bash
# Instalar Docker e Docker Compose
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker deploy

# Criar diretório do projeto
sudo mkdir -p /opt/trilho/backups
sudo chown deploy:deploy /opt/trilho

# Fazer login no GHCR (apenas uma vez)
echo "<GITHUB_TOKEN>" | docker login ghcr.io -u <SEU_USUARIO_GITHUB> --password-stdin
```

---

## 4. Estratégia de branches

```
feature/...  →  PR para develop
develop      →  deploy automático em DSV
staging      →  deploy automático em HML  (PR de develop para staging)
master       →  deploy em PRD após aprovação manual
```

Para criar os branches de ambiente:

```bash
git checkout -b develop && git push origin develop
git checkout -b staging && git push origin staging
```

---

## 5. Como encodar a Service Account do Firebase em base64

```bash
# Linux/macOS
cat firebase-service-account.json | base64 -w0

# Windows (PowerShell)
[Convert]::ToBase64String([IO.File]::ReadAllBytes("firebase-service-account.json"))
```

Cole o resultado no secret `FIREBASE_SERVICE_ACCOUNT_JSON`.

---

## 6. Gerar JWT_SECRET seguro

```bash
openssl rand -base64 48
```

Use uma chave diferente para cada ambiente.
