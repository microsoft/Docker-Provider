import json
import sys

FILE = r"c:\Users\zanejohnson\projects\prom-ci-repo\Docker-Provider\monitoring\internal-ade-dashboard\(New)Container-Insights-Logs-Addon-with-ProcessMetrics-readable.json"

with open(FILE, "r", encoding="utf-8") as f:
    raw = f.read()

prefix = ""
if raw.lstrip().startswith("//"):
    idx = raw.index("\n")
    prefix = raw[:idx + 1]
    raw = raw[idx + 1:]

data = json.loads(raw)

QUERY_ID = "5755e1e1-8072-41a3-83ab-adf6d903a8ff"
PARAM_ID = "3f4a2ffd-6e08-4be1-8434-7229d81d0171"

# Update query text to include ClusterName as displayText
new_text = "\n".join([
    "customMetrics",
    "| where timestamp > ago(1d)",
    '| where name contains "memory_rss" or name contains "cpu_usage"',
    "| where isnotempty(tostring(customDimensions.AksResourceId))",
    "| distinct AksResourceId = tostring(customDimensions.AksResourceId)",
    '| extend ClusterName = tostring(split(AksResourceId, "/")[-1])',
    "| project ClusterName, AksResourceId",
    "| order by ClusterName asc",
    "| take 200",
])

for q in data["queries"]:
    if q.get("id") == QUERY_ID:
        q["text"] = new_text
        print("Updated query text")
        break

# Update columns mapping to include displayText
for p in data["parameters"]:
    if p.get("id") == PARAM_ID:
        p["dataSource"]["columns"] = {
            "value": "AksResourceId",
            "displayText": "ClusterName"
        }
        print("Updated columns mapping")
        break

# Write back
output = json.dumps(data, indent=2, ensure_ascii=False)
with open(FILE, "w", encoding="utf-8", newline="\n") as f:
    if prefix:
        f.write(prefix)
    f.write(output)
    f.write("\n")

print("Done!")
