#!/bin/bash

# Usage: ./find_and_copy.sh /path/to/search .yaml /destination/folder "/path/to/exclude,/another/path" [owning_team]

if [ "$#" -lt 3 ]; then
    echo "Usage: $0 <source_directory> <file_extension> <destination_folder> [exclude_paths] [owning_team]"
    exit 1
fi

SOURCE_DIR="$1"
FILE_EXT="$2"
DEST_DIR="$3"
EXCLUDE_PATHS="$4"
OWNING_TEAM="${5:-mma}"  # Default to "mma" if not provided

SOURCE_DIR="$(realpath "$SOURCE_DIR")"
DEST_DIR="$(realpath "$DEST_DIR")"

mkdir -p "$DEST_DIR"

EXCLUDE_ARGS=()
if [[ -n "$EXCLUDE_PATHS" ]]; then
    IFS=',' read -ra EXCLUDE_ARRAY <<< "$EXCLUDE_PATHS"
    for EXCLUDE_PATH in "${EXCLUDE_ARRAY[@]}"; do
        EXCLUDE_PATH_ABS="$(realpath "$EXCLUDE_PATH")"
        EXCLUDE_ARGS+=(-path "$EXCLUDE_PATH_ABS" -prune -o)
    done
fi

# Function to generate unique filenames
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

# Temporary file to store JSON entries
JSON_TMP_FILE=$(mktemp)

find "$SOURCE_DIR" "${EXCLUDE_ARGS[@]}" -type f -name "*$FILE_EXT" -print0 | while IFS= read -r -d '' file; do
    original_name=$(basename "$file")
    base_name="${original_name%.*}"
    ext=".${original_name##*.}"
    new_name=$(generate_unique_filename "$base_name" "$ext")

    cp "$file" "$DEST_DIR/$new_name"

    # Add a commented line with the original path
    if [[ "$FILE_EXT" =~ ^\.(txt|log|sh|py|js|html|md|csv|json|yaml|yml|xml|conf|ini)$ ]]; then
        sed -i "1i # Copied from: $file" "$DEST_DIR/$new_name"
    fi

    # Determine JSON properties based on filename
    name_prefix="deploy"
    branch="main"
    environment=""

    if [[ "$original_name" == *"build"* ]]; then
        name_prefix="build"
    elif [[ "$original_name" == *"test"* ]]; then
        branch="test"
        environment="test"
    elif [[ "$original_name" == *"stage"* ]]; then
        branch="stage"
        environment="stage"
    elif [[ "$original_name" == *"prod"* ]]; then
        branch="main"
        environment="prod"
    fi

    yaml_path=".azuredevops/$new_name"

    # Construct JSON entry
    entry="{\"name_prefix\":\"$name_prefix\",\"owning_team\":\"$OWNING_TEAM\",\"branch\":\"$branch\",\"yaml_path\":\"$yaml_path\""
    if [[ -n "$environment" ]]; then
        entry+=",\"environment\":\"$environment\""
    fi
    entry+="}"

    echo "$entry" >> "$JSON_TMP_FILE"

    echo "Copied: $file -> $DEST_DIR/$new_name"
done

# Build the final JSON file
{
    echo '{ "pipelines": ['
    paste -sd "," "$JSON_TMP_FILE"
    echo '] }'
} | jq '.' > "$DEST_DIR/pipelines.json"

rm "$JSON_TMP_FILE"

echo "JSON file created at: $DEST_DIR/pipelines.json"
