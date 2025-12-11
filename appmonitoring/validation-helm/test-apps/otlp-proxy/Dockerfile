# docker buildx build --platform linux/amd64,linux/arm64 -t appmonitoring.azurecr.io/otlp-proxy:latest --push .

# Use official Node.js LTS image
FROM node:20

# Set working directory
WORKDIR /app

# Copy package files and install dependencies
COPY package*.json ./
RUN npm install --production

# Copy server code
COPY server.js ./

# Expose port
EXPOSE 4318

# Start the server
CMD ["node", "server.js"]
