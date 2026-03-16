---
applyTo: "**/*.py"
description: "Python coding conventions for Docker-Provider utility scripts."
---

# Python Code Standards

- Use `snake_case` for functions and variables, `PascalCase` for classes.
- Include type hints where practical.
- Use `os.environ` for configuration — never hardcode secrets.
- Error handling: use specific exception types, not bare `except:`.
- Python scripts in this repo are primarily utility/tooling scripts (not core plugins).
- Follow PEP 8 style guidelines.
- Test any Python changes by running the relevant scripts manually.
