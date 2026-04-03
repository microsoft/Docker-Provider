import json
import sys

FILE = r"c:\Users\zanejohnson\projects\prom-ci-repo\Docker-Provider\monitoring\internal-ade-dashboard\(New)Container-Insights-Logs-Addon-with-ProcessMetrics-readable.json"

with open(FILE, "r", encoding="utf-8") as f:
    raw = f.read()

# Check for // filepath: comment on line 1
prefix = ""
if raw.lstrip().startswith("//"):
    idx = raw.index("\n")
    prefix = raw[:idx + 1]
    raw = raw[idx + 1:]

data = json.loads(raw)

# === STEP 1: Remove Process Metrics page from existing clusterId parameter ===
PM_PAGE = "edff4e67-d622-4655-a2dc-d702e96a4be2"
CRI_PAGE = "535afc96-2254-4d53-abd5-687caaaf85da"
EXISTING_PARAM_ID = "96d8eb7d-df31-4cbc-9a07-bcc20951cc33"

params = data["parameters"]
existing_param = None
existing_param_idx = None
for i, p in enumerate(params):
    if p.get("id") == EXISTING_PARAM_ID:
        existing_param = p
        existing_param_idx = i
        break

if existing_param is None:
    print("ERROR: Could not find existing clusterId parameter")
    sys.exit(1)

# Remove PM page from showOnPages
page_ids = existing_param["showOnPages"]["pageIds"]
if PM_PAGE in page_ids:
    page_ids.remove(PM_PAGE)
    print(f"Step 1: Removed Process Metrics page from existing clusterId param. Remaining pages: {page_ids}")
else:
    print(f"Step 1: Process Metrics page was not in showOnPages (already removed?)")

# === STEP 2: Add new parameter for Process Metrics ===
new_param = {
    "kind": "string",
    "id": "a1b2c3d4-e5f6-7890-abcd-clusteridpm01",
    "displayName": "Cluster Resource Id (Process Metrics)",
    "description": "Select or enter a Cluster Resource ID for Process Metrics page",
    "variableName": "clusterIdForProcessMetrics",
    "selectionType": "scalar",
    "includeAllOption": True,
    "defaultValue": {
        "kind": "all"
    },
    "dataSource": {
        "kind": "query",
        "dataSourceId": "78c8522c-31b4-4851-adbd-45195c9d70f1",
        "query": "customMetrics\n| where timestamp > ago(1d)\n| where name contains \"memory_rss\" or name contains \"cpu_usage\"\n| where isnotempty(tostring(customDimensions.AksResourceId))\n| distinct AksResourceId = tostring(customDimensions.AksResourceId)\n| order by AksResourceId asc\n| take 200",
        "columns": [
            {
                "column": "AksResourceId",
                "property": "value"
            }
        ]
    },
    "showOnPages": {
        "kind": "selection",
        "pageIds": [
            "edff4e67-d622-4655-a2dc-d702e96a4be2"
        ]
    }
}

# Insert right after the existing clusterId param
params.insert(existing_param_idx + 1, new_param)
print(f"Step 2: Added new clusterIdForProcessMetrics parameter at index {existing_param_idx + 1}")

# === STEP 3: Update Process Metrics queries ===
PM_QUERY_IDS = {
    "8f2c0ff0-2bbd-48b3-bf03-341c57fcf378",
    "f42075b7-ed0a-41e4-a53c-93c2fad86bbe",
    "4c909817-241a-4fbd-b09b-4598b1191cce",
    "44793c47-4e1c-4384-bdc5-a7ec7259aec3",
    "0af115b8-7903-4791-b478-149f50aa0b3f",
    "6327a184-523e-4e89-8a6c-cba71cdb0526",
    "74c101bc-b5f3-43d7-af8f-cc919870842c",
    "93244c8c-9236-4c0e-a67e-c752861fe30c",
    "484eb6f0-01f0-49ac-83bd-39d77a64435f",
    "3ba20854-47de-479d-a9b1-85f6e5023d4a",
    "069b22ae-3d05-405f-90de-967a9e8a14b6",
    "b9866497-0e55-4a70-90c6-d3f57c713510",
    "be565860-3602-49ba-9ea7-c76330ed05c3",
    "bac5b78b-854f-4887-bca7-2212abe47a83",
    "df270865-2b7e-40c1-839f-5ccf6be4e1bc",
    "3aa7fe6e-710a-42db-ae5f-13f40c857a3d",
    "108a9a6b-8748-41b3-9bd8-5f4a8d131f76",
    "8ee9d1db-d5c9-48c7-b25a-d5dc77862ce8",
    "68c1439f-8f58-4092-917e-4995dce78e85",
    "75bddd2c-b413-42fa-a456-5ee52d057c25",
    "d45b3245-8ffe-4a9d-9dae-a1c28b866dde",
    "0ec348a3-50cc-4d28-8d27-f4923932005a",
    "556bf939-55bb-49b7-b182-3ef03362022d",
    "d4b7c043-78cb-4d3b-84f0-30fa1870abc2",
    "385e50d8-9ed6-43d7-904d-ec663d2521c8",
    "08c0c6ed-268b-4e6e-ae52-5f74341be404",
    "53acfd8e-dc30-40b4-88db-fa71cbaad960",
    "b9a7c7d6-dcc9-48ef-b868-b6c7d81b1b2b",
    "51b4fa0f-0b61-42e6-8c50-6a55022f966c",
    "1b5a9c1e-3848-4565-860d-e3fd4d11491e",
    "c77d380f-3d4c-424f-bd10-12c6e513a781",
    "9c998ca5-bd2b-4413-946b-8949999e0e9d",
    "8ebee58a-273a-483a-a849-c5e9f166639b",
    "d5b149fc-b29e-490f-bfc5-275704fd9c93",
    "1d547b70-482a-43e8-90e6-efdf125e58c5",
    "8bf13357-057f-4105-82ec-e28b05a02c73",
}

# CRI queries that must NOT be touched
CRI_QUERY_IDS = {
    "4d6d19f9-ab76-4af3-8331-5908dece797f",
    "c4f6bfc5-d39d-407e-8b8e-78977ad51efb",
    "5d3196d6-02c0-4112-8d78-20620d2be49a",
    "be9bd8e7-7ce2-487c-a037-3b70171ea00f",
    "8b19ef14-7970-4145-8fa7-3cd8015ea68b",
    "c524b746-2a86-445c-b5f6-c0c56c2de779",
}

updated_count = 0
queries = data.get("queries", [])
for q in queries:
    qid = q.get("id", "")
    if qid in PM_QUERY_IDS:
        # Update KQL text: replace clusterId with clusterIdForProcessMetrics
        # We need to be careful to only replace the variable reference, not partial matches
        text = q.get("text", "")
        # Replace =~ clusterId patterns (the KQL variable reference)
        new_text = text.replace("=~ clusterId", "=~ clusterIdForProcessMetrics")
        if new_text == text:
            # Try other patterns just in case
            new_text = text.replace("clusterId", "clusterIdForProcessMetrics")
        q["text"] = new_text

        # Update usedVariables
        used_vars = q.get("usedVariables", [])
        new_vars = []
        for v in used_vars:
            if v == "clusterId":
                new_vars.append("clusterIdForProcessMetrics")
            else:
                new_vars.append(v)
        q["usedVariables"] = new_vars
        updated_count += 1
    elif qid in CRI_QUERY_IDS:
        # Verify we're not touching these
        pass

print(f"Step 3: Updated {updated_count} Process Metrics queries (expected 36)")

# Write back
output = json.dumps(data, indent=2, ensure_ascii=False)
with open(FILE, "w", encoding="utf-8", newline="\n") as f:
    if prefix:
        f.write(prefix)
    f.write(output)
    f.write("\n")

print("Done! File written successfully.")

# Verify: check CRI queries are untouched
for q in data.get("queries", []):
    if q.get("id") in CRI_QUERY_IDS:
        if "clusterIdForProcessMetrics" in q.get("text", ""):
            print(f"WARNING: CRI query {q['id']} was incorrectly modified!")
        if "clusterIdForProcessMetrics" in q.get("usedVariables", []):
            print(f"WARNING: CRI query {q['id']} usedVariables was incorrectly modified!")
