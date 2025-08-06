# Kubernetes Test Results Processing Tools

This collection of scripts helps process and analyze test results from Kubernetes conformance tests across multiple environments. The scripts automate the extraction, parsing, and presentation of test summaries from archived logs.

## Workflow Overview

The tools in this repository work together in a sequential workflow:

1. **Extract TAR Files**: Find and extract all test result archives
2. **Extract Plugin Data**: Parse the extracted files to collect test summaries
3. **Convert to Markdown**: Transform the summaries into a readable format with clickable links

## Scripts

### 1. extract_tar_files.py

This script locates and extracts all `11_results.tar.gz` files from a directory tree.

**Usage:**
```powershell
python extract_tar_files.py "C:\Path\To\ReleaseLogs" --output "extraction_results.txt"
```

**Arguments:**
- `folder`: Root folder to search for tar.gz files (required positional argument)
- `--output`, `-o`: Output file to save extraction results (default: extraction_results.txt)

**Output:**
- Creates a local folder named after the source folder
- Extracts archives to their original locations
- Saves `extraction_results.txt` and `extraction_folders.txt` in the local folder

### 2. extract_plugin_data.py

This script processes the extracted folders to find and parse all `plugin.txt` files, which contain test summaries.

**Usage:**
```powershell
python extract_plugin_data.py ".\ReleaseLogs_6700_05222025"
```

**Arguments:**
- `path`: Path to folder containing extraction_folders.txt (required positional argument)

**Output:**
- A text file containing all test summaries with their file paths

### 3. convert_summaries_to_markdown.py

Transforms the text summaries into a well-formatted Markdown document with clickable file links and a summary table.

**Usage:**
```powershell
python convert_summaries_to_markdown.py ".\ReleaseLogs_6700_05222025"
```

**Arguments:**
- `path`: Path to folder containing test_summaries.txt (required positional argument)

**Output:**
- A Markdown file with:
  - Summary table showing test results by platform
  - Detailed sections for each platform
  - Clickable links to open the original log files
  - Formatted listing of test failures

## Complete Workflow Example

To process a full set of release logs, run the following commands in sequence:

```powershell
# Step 1: Extract tar files
python extract_tar_files.py "C:\Users\zanejohnson\Downloads\ReleaseLogs_6700_05222025"
# This creates a local folder named "ReleaseLogs_6700_05222025" containing extraction_results.txt and extraction_folders.txt

# Step 2: Extract test data from plugin.txt files
python extract_plugin_data.py ".\ReleaseLogs_6700_05222025"

# Step 3: Convert to Markdown format
python convert_summaries_to_markdown.py ".\ReleaseLogs_6700_05222025"
```

After running these commands, open `test_summaries.md` in any Markdown viewer to:
- Review the summary of test results across all platforms
- Click on links to open specific log files for detailed analysis
- Identify patterns in test failures across different environments

## Understanding the Output

The final Markdown file organizes test results by platform (e.g., AKS-Ubuntu, RKE, OCP) and provides:

1. **Summary Table**: Overview of all test results showing:
   - Platform name
   - Test counts (passed, failed, warnings)
   - List of failed tests

2. **Detailed Sections**: For each platform, showing:
   - Full path to the log file (clickable)
   - Test summary output
   - List of specific test failures

The file links are formatted as `file:///path/to/log/file.txt` so they can be clicked to open the original log files directly from the Markdown viewer.

## Requirements

- Python 3.6 or later
- Windows operating system (for file path compatibility)
- A Markdown viewer that supports `file://` protocol links
