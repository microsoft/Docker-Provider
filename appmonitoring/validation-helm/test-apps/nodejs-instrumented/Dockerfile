# docker buildx build --platform linux/amd64,linux/arm64 -t appmonitoring.azurecr.io/demoaks-nodejs-instrumented-app:latest --push .

# Use official Node.js LTS image
FROM node:20

# Set working directory
WORKDIR /app

# Copy package files and install dependencies
COPY package*.json ./
RUN npm install --production

# Copy application code
COPY instrumentation.js ./
COPY server.js ./

# Set OpenTelemetry environment variables
ENV OTEL_SERVICE_NAME=nodejs-instrumented-test-app
ENV OTEL_SERVICE_VERSION=1.0.0
ENV OTEL_ENVIRONMENT=production
ENV OTEL_LOG_LEVEL=info

# Expose port
EXPOSE 3001

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3001/health || exit 1

# Start the server
CMD ["node", "server.js"]
