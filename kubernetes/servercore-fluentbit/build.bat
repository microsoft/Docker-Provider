@echo off

REM Build the runtime image (second stage)
docker build -t docker-provider/servercore-fluentbit:latest --build-arg WINDOWS_VERSION=ltsc2022 -f "%~dp0.\Dockerfile" "%~dp0."