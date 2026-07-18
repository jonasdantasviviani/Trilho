FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy project files and restore (layer cache)
COPY Trilho.sln ./
COPY Trilho.Domain/Trilho.Domain.csproj           Trilho.Domain/
COPY Trilho.Infrastructure/Trilho.Infrastructure.csproj Trilho.Infrastructure/
COPY Trilho.API/Trilho.API.csproj                 Trilho.API/
COPY Trilho.Tests/Trilho.Tests.csproj             Trilho.Tests/
RUN dotnet restore Trilho.sln

# Copy source and publish
COPY . .
RUN dotnet publish Trilho.API/Trilho.API.csproj -c Release -o /app/publish

FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app
COPY --from=build /app/publish .
EXPOSE 8080
ENTRYPOINT ["dotnet", "Trilho.API.dll"]
