#!/usr/bin/env python3
# filepath: c:\Users\zanejohnson\projects\misc\conf-tests\convert_summaries_to_markdown.py
import re
import sys
import os
import argparse

def convert_to_markdown(input_file, output_file):
    """
    Convert test summaries from text format to Markdown with clickable file links
    """
    with open(input_file, 'r', encoding='utf-8', errors='replace') as f:
        content = f.read()
    
    # Extract the header information
    header_match = re.match(r'(Test Summaries.*?)\n\n', content, re.DOTALL)
    header = header_match.group(1) if header_match else "Test Summaries"
    
    # Split the content into individual summaries
    summaries = re.split(r'-{80}\n', content)
    
    # Remove empty entries
    summaries = [s.strip() for s in summaries if s.strip()]
      # Start building the markdown content
    md_content = f"# {header}\n\n"
    md_content += "## Summary Table\n\n"
    md_content += "> **Note:** Click on the platform name to open the original plugin.txt file directly.\n\n"
      # Create a summary table
    md_content += "| # | Platform | Test Results | Failures | Error Messages |\n"
    md_content += "|---|----------|--------------|----------|----------------|\n"
    
    # Process each summary entry
    detailed_results = []
    
    for idx, summary in enumerate(summaries):
        if summary.startswith("Test Summaries"):
            # Skip the header if it appears in the summaries
            continue
            
        # Extract file path
        file_match = re.search(r'File: (.*?)\n', summary)
        if not file_match:
            continue
            
        file_path = file_match.group(1)        # Extract pod name first since we'll need it for platform extraction
        pod_match = re.search(r'From (.*?) \(', summary)
        pod_name = pod_match.group(1) if pod_match else "Unknown"        # Extract platform info from the folder structure
        # Look for patterns like "13_AKS-Ubuntu N\Attempt1" or similar
        
        # First try to extract the platform name and attempt number from the path
        # Pattern like: ReleaseLogs_...\13_AKS-Ubuntu N\Attempt1\... or
        # C:\...\ReleaseLogs_...\13_AKS-Ubuntu N\Attempt1\...
        platform_attempt_match = re.search(r'[\\/](\d+[^/\\]+)[\\/](Attempt\d+)', file_path)
        
        if platform_attempt_match:
            # Found both platform and attempt
            platform_raw = platform_attempt_match.group(1)
            attempt = platform_attempt_match.group(2)
            # Combine them into a single platform name
            platform = f"{platform_raw}\\{attempt}"
        else:
            # Try just finding the platform part (without attempt)
            platform_match = re.search(r'[\\/](\d+[^/\\]+)[\\/]', file_path)
            if platform_match:
                platform = platform_match.group(1)
            else:
                # Try other patterns
                # Extract specific platform types
                aks_match = re.search(r'(AKS-[A-Za-z]+\s+[Nn](?:-\d+)?)', file_path)
                if aks_match:
                    platform = aks_match.group(0)
                else:
                    # Last resort: try to get something meaningful from the path
                    parts = file_path.split(os.sep)
                    platform_keywords = ["AKS", "Ubuntu", "TKG", "RKE", "OCP", "K3S", "Canonical", "Mariner"]
                    
                    # Look for parts with platform keywords
                    platform_parts = []
                    for part in parts:
                        if any(keyword in part for keyword in platform_keywords):
                            platform_parts.append(part)
                    
                    if platform_parts:
                        # Use the most specific part (usually contains the number prefix)
                        for part in platform_parts:
                            if re.search(r'^\d+_', part):
                                platform = part
                                break
                        else:
                            platform = platform_parts[0]
                    else:
                        # If all else fails, use the pod name
                        platform = pod_name if pod_name != "Unknown" else "Unknown"
          # Pod name already extracted above
        
        # Extract test results summary
        results_match = re.search(r'=+\s+((?:\d+\s+(?:failed|passed|skipped|deselected|warnings|error|errors)(?:,\s+)?)+)\s+in\s+[\d\.]+s', summary)
        results_summary = results_match.group(1) if results_match else "Unknown"
          # Extract all failed tests
        failures = []
        for line in summary.split('\n'):
            if 'FAILED' in line and '::' in line:
                test_name = line.split('::')[1].split(' - ')[0] if ' - ' in line.split('::')[1] else line.split('::')[1]
                failures.append(test_name)
        
        failure_list = ", ".join(failures) if failures else "None"
          # Extract detailed error messages
        error_messages = []
        error_section_match = re.search(r'Detailed Error Messages:\n(.*?)(?=\n-{80}|\Z)', summary, re.DOTALL)
        if error_section_match:
            error_section = error_section_match.group(1).strip()
            for line in error_section.split('\n'):
                if line.strip() and line.strip().startswith('E '):
                    # Remove the leading 'E ' and strip whitespace
                    error_msg = line.strip()[2:].strip()
                    error_messages.append(error_msg)
          # Create formatted error message text that preserves all messages
        error_msg_html = ""
        if error_messages:
            for msg in error_messages:
                # Use HTML line breaks to ensure messages appear on separate lines in the table
                if error_msg_html:
                    error_msg_html += "<br><br>"
                error_msg_html += msg
        
        # Create a file link for the platform name with Windows-compatible format and URL-encode spaces
        file_link = f"file:///{file_path.replace('\\', '/').replace(' ', '%20')}"
                
        # Add row to summary table with a link to the source file
        md_content += f"| {idx+1} | [{platform}]({file_link}) | {results_summary} | {failure_list if len(failure_list) < 50 else failure_list[:47] + '...'} | {error_msg_html} |\n"
        
        # Store detailed results for later
        detailed_results.append({
            "idx": idx+1,
            "platform": platform,
            "file_path": file_path,
            "pod_name": pod_name,
            "summary": summary,
            "failures": failures
        })
    
    # Add detailed results sections
    md_content += "\n## Detailed Results\n\n"
    
    for result in detailed_results:
        platform_anchor = result["platform"].lower().replace(' ', '-').replace('_', '-')
        md_content += f"### {result['idx']}. {result['platform']} <a id='{platform_anchor}'></a>\n\n"
          # Add file link - use file:// protocol for Windows and handle spaces in paths
        # Replace backslashes with forward slashes and encode spaces with %20
        file_link = f"file:///{result['file_path'].replace('\\', '/').replace(' ', '%20')}"
        md_content += f"**Pod**: {result['pod_name']}\n\n"
        md_content += f"**Log File**: [{result['file_path']}]({file_link})\n\n"
        
        # Extract and format the test summary
        summary_lines = result['summary'].split('\n')
        start_idx = 0
        
        # Find where the actual summary content starts (after the file path and pod info)
        for i, line in enumerate(summary_lines):
            if "----------------- generated xml file:" in line:
                start_idx = i
                break
        
        # Format the test results as a code block
        md_content += "```\n"
        md_content += "\n".join(summary_lines[start_idx:])
        md_content += "\n```\n\n"
          # If there are failures, list them in a more readable format
        if result['failures']:
            md_content += "**Failed Tests**:\n\n"
            for failure in result['failures']:
                md_content += f"- {failure}\n"
            md_content += "\n"
              # Extract and display detailed error messages if they exist
        error_section_match = re.search(r'Detailed Error Messages:\n(.*?)(?=\n-{80}|\Z)', result['summary'], re.DOTALL)
        if error_section_match:
            error_section = error_section_match.group(1).strip()
            if error_section:
                md_content += "**Error Details**:\n\n"
                for line in error_section.split('\n'):
                    if line.strip():
                        # Format the error message, removing the leading 'E ' if present
                        error_msg = line.strip()
                        if error_msg.startswith('E '):
                            error_msg = error_msg[2:].strip()
                        md_content += f"- {error_msg}\n"
                md_content += "\n"
    
    # Write the markdown content to the output file
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(md_content)
    
    print(f"Markdown file created: {output_file}")
    print(f"The file contains clickable links to the original plugin.txt files.")

def main():
    parser = argparse.ArgumentParser(description='Convert test summaries to Markdown with clickable file links')
    parser.add_argument('path', help='Path to folder containing test_summaries.txt')
    args = parser.parse_args()
    
    # Normalize the path to handle both relative (.\folder) and absolute paths
    folder_path = os.path.abspath(args.path)
    
    # Check if the path exists
    if not os.path.isdir(folder_path):
        print(f"Error: Folder '{folder_path}' does not exist")
        return 1
          # Set input and output paths to be in the specified folder
    input_file = os.path.join(folder_path, 'test_summaries.txt')
    
    # Extract the folder name to append to the output file name
    folder_name = os.path.basename(folder_path)
    output_file = os.path.join(folder_path, f'test_summaries_{folder_name}.md')
    
    if not os.path.isfile(input_file):
        print(f"Error: Input file '{input_file}' does not exist")
        return 1
    
    print(f"Using input file: {input_file}")
    print(f"Output will be written to: {output_file}")
    
    convert_to_markdown(input_file, output_file)
    
    return 0

if __name__ == "__main__":
    sys.exit(main())
