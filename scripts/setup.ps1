# Trilho - Setup Script para Windows

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  Trilho - Setup Script (Windows)" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# Check .NET SDK
Write-Host "[1/5] Verificando .NET SDK..." -ForegroundColor Yellow
dotnet --version > $null 2>&1
if ($LASTEXITCODE -eq 0) {
    $version = dotnet --version
    Write-Host "  OK - .NET $version" -ForegroundColor Green
} else {
    Write-Host "  ERRO - .NET SDK 8.0 não encontrado" -ForegroundColor Red
    Write-Host "  Instale em: https://dotnet.microsoft.com/download/dotnet/8.0" -ForegroundColor Yellow
    exit 1
}

# Check Docker
Write-Host "[2/5] Verificando Docker..." -ForegroundColor Yellow
docker --version > $null 2>&1
if ($LASTEXITCODE -eq 0) {
    $dockerVersion = docker --version
    Write-Host "  OK - $dockerVersion" -ForegroundColor Green
} else {
    Write-Host "  ERRO - Docker não encontrado" -ForegroundColor Red
    Write-Host "  Instale em: https://docker.com/products/docker-desktop" -ForegroundColor Yellow
    exit 1
}

# Check Flutter (optional)
Write-Host "[3/5] Verificando Flutter SDK..." -ForegroundColor Yellow
$flutterPath = $null
$possiblePaths = @(
    "C:\flutter",
    "C:\src\flutter",
    "$env:USERPROFILE\flutter",
    "$env:LOCALAPPDATA\flutter"
)
foreach ($path in $possiblePaths) {
    if (Test-Path "$path\bin\flutter.cmd") {
        $flutterPath = $path
        break
    }
}

if ($flutterPath) {
    Write-Host "  OK - Flutter encontrado em $flutterPath" -ForegroundColor Green
} else {
    Write-Host "  AVISO - Flutter SDK não encontrado (opcional para mobile)" -ForegroundColor Yellow
    Write-Host "  Instale em: https://flutter.dev/docs/get-started/install" -ForegroundColor Gray
}

# Setup .env
Write-Host "[4/5] Configurando .env..." -ForegroundColor Yellow
if (-not (Test-Path ".env")) {
    if (Test-Path ".env.example") {
        Copy-Item ".env.example" ".env"
        Write-Host "  ARQUIVO .env criado - Edite com seus valores!" -ForegroundColor Green
        Write-Host "  IMPORTANTE: Cadastre o token OlhoVivo em sptrans.com.br/desenvolvedores" -ForegroundColor Yellow
    } else {
        Write-Host "  AVISO - .env.example não encontrado" -ForegroundColor Yellow
    }
} else {
    Write-Host "  OK - .env já existe" -ForegroundColor Green
}

# Docker Compose
Write-Host "[5/5] Iniciando infraestrutura (Docker)..." -ForegroundColor Yellow
docker-compose up -d db redis 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "  OK - PostGIS e Redis iniciados" -ForegroundColor Green
} else {
    Write-Host "  AVISO - Falha ao iniciar Docker (verifique se o Docker Desktop está rodando)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  Setup concluído!" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Próximos passos:" -ForegroundColor White
Write-Host "  1. Edite o arquivo .env com suas credenciais" -ForegroundColor Gray
Write-Host "  2. Cadastre o token OlhoVivo em sptrans.com.br/desenvolvedores" -ForegroundColor Gray
Write-Host ""
Write-Host "Para iniciar o backend:" -ForegroundColor White
Write-Host "  cd backend" -ForegroundColor Gray
Write-Host "  dotnet run --project Trilho.API" -ForegroundColor Gray
Write-Host ""
Write-Host "Para iniciar o mobile (após instalar Flutter):" -ForegroundColor White
Write-Host "  cd mobile" -ForegroundColor Gray
Write-Host "  flutter pub get" -ForegroundColor Gray
Write-Host "  flutter run" -ForegroundColor Gray
Write-Host ""
