import os
import base64
import requests
import pytest
from typing import Optional, Callable
from azure.identity import (
    ClientAssertionCredential,
    ClientSecretCredential,
    ManagedIdentityCredential,
    CertificateCredential
)

# Function that returns aad token credentials for a given spn
# Default behavior is to use managed identity, if use_cert_auth is set we attempt to use a certificate, if use_SPN_auth is set we fall back to SPN client secret auth
def get_fed_token() -> str:
    """Retrieve a federated (OIDC) token from Azure DevOps pipeline environment.

    Expects the following environment variables to be set:
      - SYSTEM_ACCESSTOKEN
      - SERVICE_CONNECTION_ID
      - SYSTEM_OIDCREQUESTURI

    Returns:
        JWT assertion string.

    Raises:
        RuntimeError: if required env vars missing or request/response invalid.
    """
    system_accesstoken = os.getenv('SYSTEM_ACCESSTOKEN')
    service_connection_id = os.getenv('SERVICE_CONNECTION_ID')
    system_oidc_request_uri = os.getenv('SYSTEM_OIDCREQUESTURI')

    missing = [name for name, val in [
        ('SYSTEM_ACCESSTOKEN', system_accesstoken),
        ('SERVICE_CONNECTION_ID', service_connection_id),
        ('SYSTEM_OIDCREQUESTURI', system_oidc_request_uri)
    ] if not val]
    if missing:
        raise RuntimeError(f"Missing required env vars for federated auth: {', '.join(missing)}")

    oidc_request_url = f"{system_oidc_request_uri}?api-version=7.1&serviceConnectionId={service_connection_id}"
    headers = {
        "Content-Length": "0",
        "Content-Type": "application/json",
        "Authorization": f"Bearer {system_accesstoken}"
    }

    try:
        response = requests.post(oidc_request_url, headers=headers, timeout=15)
    except Exception as ex:
        raise RuntimeError(f"HTTP request for federated token failed: {ex}") from ex

    if response.status_code != 200:
        raise RuntimeError(f"Failed to retrieve federated token: status={response.status_code} body={response.text[:300]}")

    arm_oidc_token = response.json().get('oidcToken')
    if not arm_oidc_token:
        raise RuntimeError(f"Response JSON missing 'oidcToken' field: {response.text[:300]}")
    return arm_oidc_token


def build_scope(resource_endpoint: str) -> str:
    """Return a resource scope suitable for Azure.Identity .get_token calls.

    Ensures a single trailing slash before appending .default.
    Example: https://management.azure.com -> https://management.azure.com/.default
    """
    resource_endpoint = resource_endpoint.rstrip('/')
    return f"{resource_endpoint}/.default"

def fetch_aad_token_credentials(
    tenant_id: str,
    client_id: Optional[str],
    client_secret: Optional[str],
    authority: str,
    use_cert_auth: bool = False,
    use_SPN_auth: bool = False,
    use_FIC_auth: bool = False
):
    """Return an Azure credential object based on selected auth mode.

    Precedence / selection rules:
      - Exactly one of use_cert_auth, use_SPN_auth, use_FIC_auth may be True.
      - If all False, fall back to ManagedIdentityCredential.

    Args:
        tenant_id: Azure AD tenant ID (guid).
        client_id: Application (client) ID or user-assigned managed identity client ID.
        client_secret: Secret or base64 cert bytes depending on mode.
        authority: Base authority host (e.g. https://login.microsoftonline.com).
        use_cert_auth: Use certificate assertion credential.
        use_SPN_auth: Use client secret credential.
        use_FIC_auth: Use federated identity credential (ClientAssertionCredential with get_fed_token).

    Returns:
        Credential instance implementing get_token().
    """
    try:
        modes_selected = sum(bool(x) for x in [use_cert_auth, use_SPN_auth, use_FIC_auth])
        if modes_selected > 1:
            raise ValueError("Only one auth mode may be enabled at a time.")

        if use_FIC_auth:
            if not client_id:
                raise ValueError("client_id required for federated identity auth")
            return ClientAssertionCredential(
                tenant_id=tenant_id,
                client_id=client_id,
                func=get_fed_token,
                authority=authority
            )
        if use_SPN_auth:
            if not (client_id and client_secret):
                raise ValueError("client_id and client_secret required for SPN auth")
            return ClientSecretCredential(
                tenant_id=tenant_id,
                client_id=client_id,
                client_secret=client_secret,
                authority=authority
            )
        if use_cert_auth:
            if not (client_id and client_secret):
                raise ValueError("client_id and client_secret (base64 cert) required for cert auth")
            cert_bytes = base64.b64decode(client_secret)
            return CertificateCredential(
                tenant_id=tenant_id,
                client_id=client_id,
                certificate_data=cert_bytes,
                send_certificate_chain=True,
                authority=authority
            )
        # Managed Identity path
        return ManagedIdentityCredential(client_id=client_id)
    except Exception as e:
        pytest.fail("Error occurred while fetching credentials: " + str(e))
