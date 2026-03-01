"""
Mock Azure Instance Metadata Service (IMDS) — Hard Level
Same as medium level IMDS. Students must discover the IMDS URL on their own.
"""
import time
from flask import Flask, jsonify, request

app = Flask(__name__)

VM_METADATA = {
    "compute": {
        "azEnvironment": "AzurePublicCloud",
        "customData": "",
        "isHostCompatibilityLayerVm": "false",
        "licenseType": "",
        "location": "brazilsouth",
        "name": "stags-lab-vm",
        "offer": "UbuntuServer",
        "osProfile": {
            "adminUsername": "labadmin",
            "computerName": "stags-lab-vm",
            "disablePasswordAuthentication": "true",
        },
        "osType": "Linux",
        "plan": {"name": "", "product": "", "publisher": ""},
        "platformFaultDomain": "0",
        "platformUpdateDomain": "0",
        "provider": "Microsoft.Compute",
        "publicKeys": [],
        "publisher": "Canonical",
        "resourceGroupName": "rg-stags-lab",
        "resourceId": "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/rg-stags-lab/providers/Microsoft.Compute/virtualMachines/stags-lab-vm",
        "securityProfile": {
            "secureBootEnabled": "false",
            "virtualTpmEnabled": "false",
        },
        "sku": "18.04-LTS",
        "subscriptionId": "12345678-1234-1234-1234-123456789012",
        "tags": "environment:lab;ctf:stags2026",
        "tagsList": [
            {"name": "environment", "value": "lab"},
            {"name": "ctf", "value": "stags2026"},
        ],
        "userData": "",
        "version": "18.04.202201010",
        "vmId": "cafebabe-cafe-babe-cafe-babecafebabe",
        "vmSize": "Standard_D2s_v3",
        "zone": "",
        "ctfFlag": "FLAG_3{4zur3_1m4g3_m3t4d4t4_4cc355}",
    },
    "network": {
        "interface": [
            {
                "ipv4": {
                    "ipAddress": [
                        {"privateIpAddress": "10.0.0.4", "publicIpAddress": ""}
                    ],
                    "subnet": [{"address": "10.0.0.0", "prefix": "24"}],
                },
                "ipv6": {"ipAddress": []},
                "macAddress": "000D3A123456",
            }
        ]
    },
}

FAKE_TOKEN = (
    "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImtpZCI6ImZha2Vfa2lkX2hhcmQifQ"
    ".eyJzdWIiOiJjYWZlYmFiZS1jYWZlLWJhYmUtY2FmZS1iYWJlY2FmZWJhYmUiLCJvaWQi"
    "OiJkZWFkYmVlZi1kZWFkLWJlZWYtZGVhZC1iZWVmZGVhZGJlZWYiLCJpc3MiOiJodHRw"
    "czovL3N0cy53aW5kb3dzLm5ldC9kZWFkYmVlZi1kZWFkLWJlZWYtZGVhZC1iZWVmZGVh"
    "ZGJlZWYvIiwiYXVkIjoiaHR0cHM6Ly9tYW5hZ2VtZW50LmF6dXJlLmNvbS8iLCJhcHBp"
    "ZCI6ImNhZmViYWJlLWNhZmUtYmFiZS1jYWZlLWJhYmVjYWZlYmFiZSIsImlhdCI6MTc0"
    "MDgzNTIwMCwiZXhwIjoxNzQwOTIxNjAwLCJuYmYiOjE3NDA4MzUyMDB9"
    ".FAKESIGNATURE_HARD_LAB_USE_ONLY"
)


def _require_metadata_header():
    if request.headers.get("Metadata") != "true":
        return (
            jsonify({"error": "Required metadata header not specified"}),
            400,
        )
    return None


@app.route("/metadata/instance", methods=["GET"])
def instance_metadata():
    err = _require_metadata_header()
    if err:
        return err
    return jsonify(VM_METADATA)


@app.route("/metadata/identity/oauth2/token", methods=["GET"])
def identity_token():
    err = _require_metadata_header()
    if err:
        return err

    resource = request.args.get("resource", "https://management.azure.com/")
    now = int(time.time())

    return jsonify(
        {
            "access_token": FAKE_TOKEN,
            "client_id": "cafebabe-cafe-babe-cafe-babecafebabe",
            "expires_in": "86399",
            "expires_on": str(now + 86399),
            "ext_expires_in": "86399",
            "not_before": str(now),
            "resource": resource,
            "token_type": "Bearer",
        }
    )


@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ok"})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80)
