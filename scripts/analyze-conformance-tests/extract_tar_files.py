#!/usr/bin/env python3
import os
import sys
import tarfile
import argparse

def find_and_extract_tar_files(root_folder):
    """
    Find all 11_results.tar.gz files in the given folder, check if they've been
    extracted, and extract them if not.
    """
    tar_files_found = []
    files_extracted = []  # List of tar files extracted
    extracted_contents = {}  # Dictionary to store contents of each extracted tar
    
    # Walk through all directories and files
    for dirpath, dirnames, filenames in os.walk(root_folder):
        # Check if 11_results.tar.gz exists in current directory
        if '11_results.tar.gz' in filenames:            
            tar_path = os.path.join(dirpath, '11_results.tar.gz')
            tar_files_found.append(tar_path)
            print(f"Found tar file: {tar_path}")
              # Check if the tar file has already been extracted
            try:
                with tarfile.open(tar_path, 'r:gz') as tar:
                    # Get list of files in the tar
                    tar_contents = tar.getnames()
                    
                    # Create a subfolder with the same name as the tar file (without extension)
                    tar_filename = os.path.basename(tar_path)
                    extract_folder_name = os.path.splitext(os.path.splitext(tar_filename)[0])[0]  # Remove both .tar and .gz
                    extract_folder_path = os.path.join(dirpath, extract_folder_name)
                    
                    # Check if the extraction folder exists and contains the extracted files
                    if not os.path.exists(extract_folder_path):
                        os.makedirs(extract_folder_path, exist_ok=True)
                        print(f"  Created folder: {extract_folder_path}")
                      # Check if all files in the tar already exist in the extraction folder
                    all_extracted = all(os.path.exists(os.path.join(extract_folder_path, name)) for name in tar_contents)
                    
                    if not all_extracted:
                        print(f"  Extracting {tar_path} to {extract_folder_path} ({len(tar_contents)} files)")
                        tar.extractall(path=extract_folder_path)
                        files_extracted.append(extract_folder_path)  # Store extract folder path instead of tar file path
                        
                        # Store list of extracted files for this tar
                        extracted_contents[tar_path] = [os.path.join(extract_folder_path, name) for name in tar_contents]
                    else:
                        print(f"  Already extracted: {tar_path}")
                        # Also store the paths of already extracted files
                        files_extracted.append(extract_folder_path)  # Also add extract folder path for already extracted files
                        extracted_contents[tar_path] = [os.path.join(extract_folder_path, name) for name in tar_contents]
            except Exception as e:
                print(f"  Error processing {tar_path}: {str(e)}")
    
    return tar_files_found, files_extracted, extracted_contents

def main():
    parser = argparse.ArgumentParser(description='Find and extract 11_results.tar.gz files')
    parser.add_argument('folder', help='Root folder to search for tar.gz files')
    parser.add_argument('--output', '-o', help='Output file to save extraction results', default='extraction_results.txt')
    args = parser.parse_args()
    
    if not os.path.isdir(args.folder):
        print(f"Error: {args.folder} is not a valid directory")
        return 1
    
    # Extract the folder name from the path
    folder_name = os.path.basename(os.path.normpath(args.folder))
    local_folder = os.path.join(os.path.dirname(os.path.abspath(__file__)), folder_name)
    
    # Check if the local folder exists, if not create it
    if not os.path.exists(local_folder):
        # Ask for verification before creating the folder
        print(f"\nPreparing to create local folder: {local_folder}")
        verification = input(f"Continue with creating this folder? (y/n): ")
        
        if verification.lower() != 'y':
            print("Operation cancelled by user.")
            return 0
        
        os.makedirs(local_folder)
        print(f"Created folder: {local_folder}")
    else:
        print(f"\nUsing existing folder: {local_folder}")
        verification = input(f"Continue with using this folder? (y/n): ")
        
        if verification.lower() != 'y':
            print("Operation cancelled by user.")
            return 0
    
    print(f"\nSearching for 11_results.tar.gz files in {args.folder}")
    
    tar_files, extracted_files, extracted_contents = find_and_extract_tar_files(args.folder)
    print("\nSummary:")
    print(f"Found {len(tar_files)} tar files")
    print(f"Extracted {len(extracted_files)} tar archives")
    
    if extracted_files:
        print("\nExtraction folders:")
        for folder in extracted_files:
            print(f"  {folder}")    # Set output paths to be in the local folder
    output_file_path = os.path.join(local_folder, "extraction_results.txt")
    folders_file_path = os.path.join(local_folder, "extraction_folders.txt")
    
    # Always write the results to the output file, even if no files were extracted
    with open(output_file_path, 'w') as f:        
        f.write(f"Found {len(tar_files)} tar files\n")
        f.write(f"Extracted {len(extracted_files)} tar archives\n\n")
        
        f.write("Tar files found:\n")
        for file in tar_files:
            f.write(f"{file}\n")
        
        if extracted_files:
            f.write("\nExtraction folders created or already existing:\n")
            for folder in extracted_files:
                f.write(f"{folder}\n")
    
    # Create a separate extraction_folders.txt file with just the folder paths
    # This makes it easier for other scripts to use this data directly
    with open(folders_file_path, 'w') as f:
        f.write("Extraction folders created or already existing:\n")
        for folder in extracted_files:
            f.write(f"{folder}\n")
    
    print(f"\nResults written to {output_file_path}")
    print(f"Extraction folders list written to {folders_file_path}")
    print(f"\nTo process these files with extract_plugin_data.py, use:")
    print(f"python extract_plugin_data.py --input \"{folders_file_path}\" --output \"test_summaries.txt\"")
    
    return 0

if __name__ == "__main__":
    sys.exit(main())
