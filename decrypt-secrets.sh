#!/bin/bash

# Script to decrypt all .enc files after cloning or pulling from Git
# Usage: ./decrypt-secrets.sh [folder-name]
# Example: ./decrypt-secrets.sh .
# Requires OpenSSL to be installed

set -e

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the shared configuration
if [ -f "$SCRIPT_DIR/config.sh" ]; then
    source "$SCRIPT_DIR/config.sh"
else
    echo "Error: config.sh not found in $SCRIPT_DIR"
    exit 1
fi

# Parse arguments
FOLDER="$1"
if [ -z "$FOLDER" ]; then
    echo -e "${YELLOW}Usage: $0 <folder-path>${NC}"
    echo "Examples:"
    echo "  $0 .                    # Decrypt files in current directory"
    echo "  $0 ./my-project         # Decrypt files in specific folder"
    exit 1
fi

# Check if directory exists
if [ ! -d "$FOLDER" ]; then
    echo -e "${RED}Error: directory '$FOLDER' not found${NC}"
    exit 1
fi

echo "🔓 Decrypting sensitive files in folder: $FOLDER"

# Note: decrypt-secrets.sh doesn't need to read .sensitive-file-patterns
# It simply decrypts all .enc files found in the directory

# Check if OpenSSL is installed
if ! command -v openssl &> /dev/null; then
    echo -e "${RED}Error: OpenSSL is not installed${NC}"
    echo "Install it with:"
    echo "  brew install openssl  # macOS"
    echo "  apt-get install openssl  # Ubuntu/Debian"
    exit 1
fi

# Find all .enc files in folder
files_to_decrypt=()
while IFS= read -r -d '' file; do
    files_to_decrypt+=("$file")
done < <(find "$FOLDER" -name "*.enc" -type f -print0 2>/dev/null)

# Check if any files found
if [ ${#files_to_decrypt[@]} -eq 0 ]; then
    echo -e "${YELLOW}No encrypted (.enc) files found in $FOLDER/${NC}"
    exit 0
fi

# Show files that will be decrypted
echo -e "\n${GREEN}Files to be decrypted:${NC}"
for enc_file in "${files_to_decrypt[@]}"; do
    target_file="${enc_file%.enc}"
    if [ -f "$target_file" ]; then
        echo -e "  ${YELLOW}🔓${NC} $enc_file → $target_file ${RED}(will overwrite existing)${NC}"
    else
        echo -e "  ${GREEN}🔓${NC} $enc_file → $target_file ${GREEN}(new)${NC}"
    fi
done

echo -e "\n${YELLOW}Total: ${#files_to_decrypt[@]} file(s) will be decrypted${NC}"

# Show warning if files will be overwritten
existing_files=()
for enc_file in "${files_to_decrypt[@]}"; do
    target_file="${enc_file%.enc}"
    if [ -f "$target_file" ]; then
        existing_files+=("$target_file")
    fi
done

if [ ${#existing_files[@]} -gt 0 ]; then
    echo -e "\n${YELLOW}⚠️  ${#existing_files[@]} unencrypted file(s) will be overwritten${NC}"
    echo -e "${YELLOW}Press Ctrl+C to cancel or continue with password entry${NC}"
fi

# Get decryption password once
echo -n "Enter decryption key for all files of \"$FOLDER\": "
read -s password
echo

# Counter for decrypted files
decrypted_count=0
failed_count=0

# Decrypt each file with the same password
for enc_file in "${files_to_decrypt[@]}"; do
    target_file="${enc_file%.enc}"
    temp_file="${target_file}.tmp_decrypt"
    
    # Decrypt to temporary file first to avoid destroying existing files
    if openssl enc -${ENCRYPTION_ALGORITHM} -pbkdf2 -iter ${PBKDF2_ITERATIONS} -d -in "$enc_file" -out "$temp_file" -pass pass:"$password" 2>/dev/null; then
        # Decryption successful, move temp file to target
        mv "$temp_file" "$target_file"
        echo -e "${GREEN}✓ Decrypted: $enc_file -> $target_file${NC}"
        decrypted_count=$((decrypted_count + 1))
    else
        echo -e "${RED}✗ Failed to decrypt: $enc_file${NC}"
        echo -e "${RED}  Error: Wrong password or corrupted file${NC}"
        rm -f "$temp_file"  # Remove failed temp file
        failed_count=$((failed_count + 1))
    fi
done

# Summary
echo -e "\n${GREEN}════════════════════════════════════════${NC}"
if [ $failed_count -eq 0 ]; then
    echo -e "${GREEN}✓ Decryption complete for $FOLDER!${NC}"
else
    echo -e "${YELLOW}⚠️  Decryption finished with errors${NC}"
fi
echo -e "${GREEN}  Successfully decrypted: $decrypted_count${NC}"
if [ $failed_count -gt 0 ]; then
    echo -e "${RED}  Failed to decrypt: $failed_count${NC}"
    echo -e "${YELLOW}  Wrong password? Try again with correct password${NC}"
fi
echo -e "${GREEN}════════════════════════════════════════${NC}"

# Security reminder
echo -e "\n${YELLOW}⚠️  Security reminders:${NC}"
echo "  1. Never commit unencrypted sensitive files!"
echo "  2. These files are in .gitignore for your protection"
echo "  3. Keep decrypted files secure on your local machine"

exit 0