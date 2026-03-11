---
applyTo: "**/*.py"
---

# Python Coding Instructions

- Follow snake_case for functions/variables, PascalCase for classes
- Use pytest for all tests with @pytest.fixture for setup/teardown
- Use specific exception types in try/except blocks
- Group imports: stdlib, third-party (pytest, kubernetes, azure-*), local
- E2E tests use kubernetes Python client and Azure SDK
- Test with: `pytest test/e2e/src/tests/ -xvs`
- Use conftest.py for shared fixtures across test modules
- Do not add type hints unless the existing module uses them consistently
