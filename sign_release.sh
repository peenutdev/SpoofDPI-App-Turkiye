#!/bin/bash

# Path to the Sparkle signing tool (relative to this script)
SIGN_TOOL="./Tools/bin/sign_update"

# Check if zip file is provided
if [ -z "$1" ]; then
    echo "Usage: ./sign_release.sh <path_to_zip_file>"
    echo "Example: ./sign_release.sh SpoofDPI.App.zip"
    exit 1
fi

ZIP_FILE="$1"

if [ ! -f "$ZIP_FILE" ]; then
    echo "Error: File '$ZIP_FILE' not found."
    exit 1
fi

echo "Signing '$ZIP_FILE'..."
"$SIGN_TOOL" "$ZIP_FILE"
