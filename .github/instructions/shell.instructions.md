---
applyTo: "**/*.sh"
---

# Shell Coding Instructions

- Use UPPER_CASE for environment variables and global constants
- Use snake_case for function names
- Always set -e at script start for fail-fast behavior
- Quote all variable expansions ("$VAR") to prevent word splitting
- Use [[ ]] for conditionals (bash-specific) or [ ] for POSIX compatibility
- Log with echo to stdout; use >&2 for error messages
- Source shared functions from common scripts (e.g., source /opt/microsoft/...)
- Check exit codes explicitly for critical operations
- Use case statements for multi-branch logic (cloud detection, OS detection)
- Do not use curl | bash patterns — download then verify then execute
- Scripts under kubernetes/ are container entrypoints — test changes with Docker builds
