# docker buildx build --platform linux/amd64,linux/arm64 -t appmonitoring.azurecr.io/demoaks-dotnet-instrumented-app:latest --push .

FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY . .
RUN dotnet restore
RUN dotnet publish -c Release -o /app

FROM base AS final
WORKDIR /app
COPY --from=build /app .

# Set OpenTelemetry environment variables
ENV OTEL_SERVICE_NAME=dotnet-instrumented-test-app
ENV OTEL_SERVICE_VERSION=1.0.0
ENV OTEL_ENVIRONMENT=production
ENV OTEL_LOG_LEVEL=info

EXPOSE 3001
ENV ASPNETCORE_URLS=http://+:3001

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3001/health || exit 1

CMD ["dotnet", "dotnet-instrumented-test-app.dll"]
