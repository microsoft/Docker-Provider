# docker build -t appmonitoring.azurecr.io/demoaks-dotnet-app:latest .
# docker push appmonitoring.azurecr.io/demoaks-dotnet-app:latest 

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
EXPOSE 3001
ENV ASPNETCORE_URLS=http://+:3001
CMD ["dotnet", "dotnet-test-app.dll"]