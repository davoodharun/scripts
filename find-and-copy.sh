#!/bin/bash

# Usage: ./find_and_copy.sh /path/to/search .txt /destination/folder

# Check if correct arguments are provided
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <source_directory> <file_extension> <destination_folder>"
    exit 1
fi

SOURCE_DIR="$1"
FILE_EXT="$2"
DEST_DIR="$3"

# Convert to absolute paths
SOURCE_DIR="$(realpath "$SOURCE_DIR")"
DEST_DIR="$(realpath "$DEST_DIR")"

# Create the destination directory if it doesn't exist
mkdir -p "$DEST_DIR"

# Function to generate a unique filename if a duplicate exists
generate_unique_filename() {
    local base_name="$1"
    local ext="$2"
    local count=1
    local new_name="$base_name$ext"

    while [[ -e "$DEST_DIR/$new_name" ]]; do
        new_name="${base_name}_copy${count}${ext}"
        ((count++))
    done

    echo "$new_name"
}

# Find all matching files recursively and process them
find "$SOURCE_DIR" -type f -name "*$FILE_EXT" | while read -r file; do
    original_name=$(basename "$file")
    base_name="${original_name%.*}"
    ext=".${original_name##*.}"

    # Generate a unique filename if needed
    new_name=$(generate_unique_filename "$base_name" "$ext")
    
    # Copy the file to the destination
    cp "$file" "$DEST_DIR/$new_name"
    
    # Add a commented line with the original path (only for text-based files)
    if [[ "$FILE_EXT" =~ ^\.(txt|log|sh|py|js|html|md|csv|json|yaml|yml|xml|conf|ini)$ ]]; then
        sed -i "1i # Copied from: $file" "$DEST_DIR/$new_name"
    fi

    echo "Copied: $file -> $DEST_DIR/$new_name"
done

echo "All *$FILE_EXT files copied to $DEST_DIR with original paths added."
