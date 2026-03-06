# Threat Model History

This directory contains threat model analysis artifacts for the Docker-Provider repository (Azure Monitor Container Insights). Each subdirectory represents one analysis run, timestamped by date.

**Methodology:** Microsoft SDL Threat Modeling + STRIDE
**Reference:** https://learn.microsoft.com/en-us/azure/security/develop/threat-modeling-tool

## How to Generate a New Threat Model

Invoke the `@ThreatModelAnalyst` agent in GitHub Copilot Chat:

```
@ThreatModelAnalyst perform a full threat model analysis of this repository
```

Or scope it to a specific area:

```
@ThreatModelAnalyst threat model the log ingestion pipeline
@ThreatModelAnalyst analyze the Kubernetes RBAC and secrets management
@ThreatModelAnalyst assess the Windows agent attack surface
```

Each run creates a new date-stamped subdirectory with the full report, STRIDE analysis, threat catalogue, and architecture diagram.

## Analysis Runs

| Date | Scope | Analyst | Critical | High | Medium | Low | Report |
|------|-------|---------|----------|------|--------|-----|--------|
| *(No runs yet — invoke `@ThreatModelAnalyst` to generate the first analysis)* | | | | | | | |
