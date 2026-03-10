---
applyTo: "test/e2e/**/*.py,test/**/*.py"
description: "Python conventions for E2E testing in this repository."
---

# Python Test Conventions — Docker-Provider

1. Functions use `snake_case`, classes `PascalCase`, constants `UPPER_CASE`.
2. Test framework is pytest with session-scoped fixtures in `conftest.py`.
3. Use `pytest.fail("message")` for assertion failures — not bare `assert` in utility functions.
4. Error handling: wrap Kubernetes API calls in `try/except` with descriptive error messages.
5. Kubernetes utilities live in `test/e2e/src/common/` — reuse existing helpers (`kubernetes_pod_utility.py`, etc.).
6. Constants for cloud endpoints are in `test/e2e/src/common/constants.py`.
7. Environment variables (`TENANT_ID`, `CLIENT_ID`, `CLIENT_SECRET`) drive E2E auth — never hardcode.
8. Use `subprocess.Popen` with `.communicate()` for shell commands in tests.
