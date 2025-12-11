# docker buildx build --platform linux/amd64,linux/arm64 -t appmonitoring.azurecr.io/demoaks-java-instrumented-agent-app:latest --push .

# Multi-stage build
FROM maven:3.9.6-eclipse-temurin-17 AS build

# Set working directory
WORKDIR /app

# Copy pom.xml and download dependencies (for better layer caching)
COPY pom.xml ./
RUN mvn dependency:go-offline -B

# Copy source code and build the application
COPY src ./src
RUN mvn clean package -DskipTests

# Runtime stage
FROM eclipse-temurin:17-jre-jammy

# Create non-root user
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Set working directory
WORKDIR /app

# Download OpenTelemetry Java agent
ARG OTEL_AGENT_VERSION=2.10.0
RUN curl -L https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/v${OTEL_AGENT_VERSION}/opentelemetry-javaagent.jar \
    -o /app/opentelemetry-javaagent.jar

# Copy the built JAR from the build stage
COPY --from=build /app/target/java-instrumented-agent-app-1.0.0.jar app.jar

# Change ownership of the app directory
RUN chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Set OpenTelemetry environment variables for the agent
#ENV OTEL_SERVICE_NAME=java-instrumented-agent-app
#ENV OTEL_SERVICE_VERSION=1.0.0
#ENV OTEL_TRACES_EXPORTER=otlp
#ENV OTEL_METRICS_EXPORTER=otlp
#ENV OTEL_LOGS_EXPORTER=otlp
#ENV OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:8080/actuator/health || exit 1

# Start the application with OpenTelemetry Java agent
CMD ["java", "-javaagent:/app/opentelemetry-javaagent.jar", "-jar", "app.jar"]
