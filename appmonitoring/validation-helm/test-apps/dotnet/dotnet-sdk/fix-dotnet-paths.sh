#!/bin/sh
# Fix .NET environment variables for Windows
# This script converts Linux-style paths to Windows-style paths in .NET-specific environment variables
# Usage: source this script or use it as a wrapper

# Convert forward slashes to backslashes in DOTNET_STARTUP_HOOKS
if [ -n "$DOTNET_STARTUP_HOOKS" ]; then
    export DOTNET_STARTUP_HOOKS=$(echo "$DOTNET_STARTUP_HOOKS" | tr '/' '\\')
    echo "Fixed DOTNET_STARTUP_HOOKS: $DOTNET_STARTUP_HOOKS"
fi

# Convert forward slashes to backslashes in DOTNET_ADDITIONAL_DEPS
if [ -n "$DOTNET_ADDITIONAL_DEPS" ]; then
    export DOTNET_ADDITIONAL_DEPS=$(echo "$DOTNET_ADDITIONAL_DEPS" | tr '/' '\\')
    echo "Fixed DOTNET_ADDITIONAL_DEPS: $DOTNET_ADDITIONAL_DEPS"
fi

# Convert forward slashes to backslashes in DOTNET_SHARED_STORE
if [ -n "$DOTNET_SHARED_STORE" ]; then
    export DOTNET_SHARED_STORE=$(echo "$DOTNET_SHARED_STORE" | tr '/' '\\')
    echo "Fixed DOTNET_SHARED_STORE: $DOTNET_SHARED_STORE"
fi

# Convert forward slashes to backslashes in OTEL_DOTNET_AUTO_HOME
if [ -n "$OTEL_DOTNET_AUTO_HOME" ]; then
    export OTEL_DOTNET_AUTO_HOME=$(echo "$OTEL_DOTNET_AUTO_HOME" | tr '/' '\\')
    echo "Fixed OTEL_DOTNET_AUTO_HOME: $OTEL_DOTNET_AUTO_HOME"
fi

# Convert forward slashes to backslashes in OTEL_DOTNET_AUTO_LOG_DIRECTORY
if [ -n "$OTEL_DOTNET_AUTO_LOG_DIRECTORY" ]; then
    export OTEL_DOTNET_AUTO_LOG_DIRECTORY=$(echo "$OTEL_DOTNET_AUTO_LOG_DIRECTORY" | tr '/' '\\')
    echo "Fixed OTEL_DOTNET_AUTO_LOG_DIRECTORY: $OTEL_DOTNET_AUTO_LOG_DIRECTORY"
fi

# Execute the command passed as arguments
exec "$@"
