#!/usr/bin/env python3
# filepath: c:\Users\zanejohnson\projects\misc\conf-tests\extract_plugin_data.py
import os
import sys
import re
import glob
import argparse

def find_plugin_txt_files(base_folder):
    """
    Find all plugin.txt files in the specified pattern within the base folder
    """
    pattern = os.path.join(base_folder, "podlogs", "sonobuoy", "sonobuoy-azure-arc-monitor-job-*", "logs", "plugin.txt")
    return glob.glob(pattern)

def extract_test_summary(file_path):
    """
    Extract text between the specified markers in the plugin.txt file
    and also collect error lines that start with "E "
    """
    try:
        with open(file_path, 'r', encoding='utf-8', errors='replace') as f:
            content = f.read()
        
        # Define the start marker
        start_marker = "----------------- generated xml file: /tmp/results/results.xml -----------------"
        
        # Find the start of the summary
        start_idx = content.find(start_marker)
        if start_idx == -1:
            return None  # Start marker not found
        
        # Define the end marker pattern using regex to match pytest summary lines
        # Pattern matches lines like "======= X failed, Y passed, Z warnings in TIME ======="
        # Where X, Y, Z, and TIME can vary
        end_marker_pattern = r"=+\s+\d+\s+(?:failed|passed|skipped|deselected|warnings|error|errors)(?:,\s+\d+\s+(?:failed|passed|skipped|deselected|warnings|error|errors))*\s+in\s+[\d\.]+s(?:\s+\(\d+:\d+:\d+\))?\s+=+"
        
        # Find the end of the summary using regex
        summary_text = content[start_idx:]
        match = re.search(end_marker_pattern, summary_text)
        
        if match:
            # Include the end marker in the extracted text
            end_idx = match.end()
            extracted_text = summary_text[:end_idx]
        else:
            # If no end marker found, use the original approach (all text after start marker)
            extracted_text = summary_text
            print(f"Warning: No end marker found in {file_path}, using full text after start marker")
          # Collect all error lines starting with "E "
        error_lines = []
        for line in content.split('\n'):
            line = line.strip()
            if line.startswith('E '):
                error_lines.append(line)
        
        # Get the relevant folder info from the file path
        path_parts = file_path.split(os.sep)
        folder_info = path_parts[-5] if len(path_parts) >= 5 else "unknown"
        
        # Add error details if found
        if error_lines:
            detailed_errors = "\nDetailed Error Messages:\n" + "\n".join(error_lines)
        else:
            detailed_errors = ""
        
        # Return the extracted text with folder info, the complete file path, and detailed errors
        return f"File: {file_path}\nFrom {folder_info} ({os.path.basename(os.path.dirname(os.path.dirname(file_path)))})\n{extracted_text}{detailed_errors}\n{'-'*80}\n"
    
    except Exception as e:
        print(f"Error processing {file_path}: {str(e)}")
        return None

def process_folders(input_file, output_file):
    """
    Process each folder in the input file and extract test summaries from plugin.txt files
    """
    with open(input_file, 'r') as f:
        lines = f.readlines()
    
    # Skip the header line
    folders = [line.strip() for line in lines[1:] if line.strip()]
    
    print(f"Processing {len(folders)} folders...")
    
    all_summaries = []
    plugin_files_found = 0
    
    for folder in folders:
        if not os.path.isdir(folder):
            print(f"Warning: Folder not found: {folder}")
            continue
        
        # Find all plugin.txt files in this folder
        plugin_files = find_plugin_txt_files(folder)
        plugin_files_found += len(plugin_files)
        
        # Process each plugin.txt file
        for plugin_file in plugin_files:
            summary = extract_test_summary(plugin_file)
            if summary:
                all_summaries.append(summary)
                print(f"Extracted summary from: {plugin_file}")
            else:
                print(f"No summary markers found in: {plugin_file}")
    
    # Write all summaries to the output file
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(f"Test Summaries from plugin.txt files\n")
        f.write(f"Found {plugin_files_found} plugin.txt files across {len(folders)} folders\n")
        f.write(f"Extracted {len(all_summaries)} test summaries\n")
        f.write(f"{'-'*80}\n\n")
        
        for summary in all_summaries:
            f.write(summary)
    
    print(f"\nSummary:")
    print(f"Processed {len(folders)} folders")
    print(f"Found {plugin_files_found} plugin.txt files")
    print(f"Extracted {len(all_summaries)} test summaries")
    print(f"Results written to {output_file}")

def main():
    parser = argparse.ArgumentParser(description='Extract test summaries from plugin.txt files')
    parser.add_argument('path', help='Path to folder containing extraction_folders.txt')
    args = parser.parse_args()
    
    # Normalize the path to handle both relative (.\folder) and absolute paths
    folder_path = os.path.abspath(args.path)
    
    # Check if the path exists
    if not os.path.isdir(folder_path):
        print(f"Error: Folder '{folder_path}' does not exist")
        return 1
        
    # Set input and output paths to be in the specified folder
    input_file = os.path.join(folder_path, 'extraction_folders.txt')
    output_file = os.path.join(folder_path, 'test_summaries.txt')
    
    if not os.path.isfile(input_file):
        print(f"Error: Input file '{input_file}' does not exist")
        return 1
    
    print(f"Using input file: {input_file}")
    print(f"Output will be written to: {output_file}")
    
    process_folders(input_file, output_file)
    
    return 0

if __name__ == "__main__":
    sys.exit(main())
