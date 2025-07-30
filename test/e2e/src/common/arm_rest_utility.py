import pytest
import os
import json
import requests
from azure.identity import ClientAssertionCredential, ClientSecretCredential, ManagedIdentityCredential, CertificateCredential
#from azure.identity._credentials.client_assertion import JwtAssertion

# Function that returns aad token credentials for a given spn
# Default behavior is to use managed identity, if use_cert_auth is set we attempt to use a certificate, if use_SPN_auth is set we fall back to SPN client secret auth
def get_fed_token():
    system_accesstoken = os.getenv('SYSTEM_ACCESSTOKEN')
    service_connection_id = os.getenv('SERVICE_CONNECTION_ID')
    system_oidc_request_uri = os.getenv('SYSTEM_OIDCREQUESTURI')

    if system_accesstoken and service_connection_id and system_oidc_request_uri:

        # Construct the OIDC_REQUEST_URL
        oidc_request_url = f"{system_oidc_request_uri}?api-version=7.1&serviceConnectionId={service_connection_id}"

        # Preparing headers for ADO Pipeline OIDC authentication
        headers = {
            "Content-Length": "0",
            "Content-Type": "application/json",
            "Authorization": f"Bearer {system_accesstoken}"
        }

        # Make the POST request
        response = requests.post(oidc_request_url, headers=headers)

        # Check the response and extract the OIDC token
        if response.status_code == 200:
            # Assuming the response is JSON and has an 'oidcToken' field
            arm_oidc_token = response.json().get('oidcToken')
            print("Return Fed token")
            return arm_oidc_token
        else:
            print("Failed to retrieve FED Token:", response.status_code, response.text)

    else:
        print("""
        One or more variables (SYSTEM_ACCESSTOKEN, 
        SERVICE_CONNECTION_ID, 
        SYSTEM_OIDCREQUESTURI) are either not set or empty.
        """)

def fetch_aad_token_credentials(tenant_id, client_id, client_secret, authority, use_cert_auth = False, use_SPN_auth = False, use_FIC_auth = False):
    try:
        if use_FIC_auth:
            return ClientAssertionCredential(tenant_id=tenant_id, client_id=client_id, func=get_fed_token, authority=authority)
            #return ClientSecretCredential(tenant_id=tenant_id, client_id=fed_client_id, client_secret=fed_token, authority=authority)
        if use_SPN_auth:
            return ClientSecretCredential(tenant_id=tenant_id, client_id=client_id, client_secret=client_secret, authority=authority)
        if use_cert_auth:
            import base64
            cert_bytes = base64.b64decode(client_secret)
            return CertificateCredential(tenant_id=tenant_id, client_id=client_id, certificate_data=cert_bytes, send_certificate_chain=True)
        else:
            return ManagedIdentityCredential(client_id=client_id)
    except Exception as e:
        pytest.fail("Error occured while fetching credentials: " + str(e))
