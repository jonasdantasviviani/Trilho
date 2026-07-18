@echo off
REM Trilho - Setup Script for Windows
REM Run as Administrator if needed

echo ======================================
echo   Trilho - Setup Script (Windows)
echo ======================================
echo.

REM Check .NET SDK
echo [1/5] Verificando .NET SDK...
dotnet --version >nul 2>&1
if %errorlevel% equ 0 (
    dotnet --version
    echo   OK - .NET SDK encontrado
) else (
    echo   ERRO - .NET SDK 8.0 nao encontrado
    echo   Instale em: https://dotnet.microsoft.com/download/dotnet/8.0
    exit /b 1
)

REM Check Docker
echo.
echo [2/5] Verificando Docker...
docker --version >nul 2>&1
if %errorlevel% equ 0 (
    docker --version
    echo   OK - Docker encontrado
) else (
    echo   ERRO - Docker nao encontrado
    echo   Instale em: https://docker.com/products/docker-desktop
    exit /b 1
)

REM Check Flutter
echo.
echo [3/5] Verificando Flutter SDK...
where flutter >nul 2>&1
if %errorlevel% equ 0 (
    flutter --version
    echo   OK - Flutter SDK encontrado
) else (
    echo   AVISO - Flutter SDK nao encontrado (opcional para mobile)
    echo   Instale em: https://flutter.dev/docs/get-started/install
)

REM Setup .env
echo.
echo [4/5] Configurando .env...
if not exist .env (
    if exist .env.example (
        copy .env.example .env
        echo   ARQUIVO .env criado - Edite com seus valores!
        echo   IMPORTANTE: Cadastre o token OlhoVivo em sptrans.com.br/desenvolvedores
    )
) else (
    echo   OK - .env ja existe
)

REM Docker Compose
echo.
echo [5/5] Iniciando infraestrutura (Docker)...
docker-compose up -d db redis >nul 2>&1
if %errorlevel% equ 0 (
    echo   OK - PostGIS e Redis iniciados
) else (
    echo   AVISO - Falha ao iniciar Docker (verifique se o Docker Desktop esta rodando)
)

echo.
echo ======================================
echo   Setup concluido!
echo ======================================
echo.
echo Proximos passos:
echo   1. Edite o arquivo .env com suas credenciais
echo   2. Cadastre o token OlhoVivo em sptrans.com.br/desenvolvedores
echo.
echo Para iniciar o backend:
echo   cd backend
echo   dotnet run --project Trilho.API
echo.
echo Para iniciar o mobile (apos instalar Flutter):
echo   cd mobile
echo   flutter pub get
echo   flutter run
echo.
pause
