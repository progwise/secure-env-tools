#!/bin/bash

# Script to encrypt all sensitive files before committing to Git
# Usage: ./encrypt-secrets.sh [folder-name]
#        ./encrypt-secrets.sh --init [folder-name]
# Example: ./encrypt-secrets.sh .
#          ./encrypt-secrets.sh --init ./my-project
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

# Function to create default .sensitive-file-patterns file
create_patterns_file() {
    local target_dir="$1"
    local patterns_file="$target_dir/.sensitive-file-patterns"
    
    if [ -f "$patterns_file" ]; then
        echo -e "${YELLOW}File already exists: $patterns_file${NC}"
        echo -n "Overwrite? (y/N): "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            echo "Keeping existing file."
            return 0
        fi
    fi
    
    cat > "$patterns_file" << 'EOF'
# Sensitive file patterns for encryption
# One pattern per line, supports wildcards (*)
# Lines starting with # are comments
# Add patterns specific to your project

# Credentials files
credentials.*

# Environment files
*.env
.env
.env.*
# Exclude example files (uncomment if needed)
# !.env.example
# !.env.sample

# SSL/TLS certificates and keys
*.pem
*.key
*.crt

# SSH keys
id_rsa
id_ed25519
id_ecdsa
id_dsa

# Database configs
database.yml
database.json
db.conf

# AWS credentials
# credentials
# config

# API keys and tokens (be careful with wildcards)
# *apikey*
# *token*
# *secret*
EOF
    
    echo -e "${GREEN}✓ Created $patterns_file${NC}"
    echo -e "${YELLOW}Edit this file to customize which files to encrypt${NC}"
    return 0
}

# Parse arguments
if [ "$1" = "--init" ]; then
    FOLDER="${2:-.}"
    if [ ! -d "$FOLDER" ]; then
        echo -e "${RED}Error: directory '$FOLDER' not found${NC}"
        exit 1
    fi
    create_patterns_file "$FOLDER"
    exit 0
fi

FOLDER="$1"
if [ -z "$FOLDER" ]; then
    echo -e "${YELLOW}Usage: $0 [--init] <folder-path>${NC}"
    echo "Examples:"
    echo "  $0 .                    # Encrypt files in current directory"
    echo "  $0 ./my-project         # Encrypt files in specific folder"
    echo "  $0 --init .             # Create .sensitive-file-patterns in current directory"
    echo "  $0 --init ./my-project  # Create .sensitive-file-patterns in specific folder"
    exit 1
fi

# Check if directory exists
if [ ! -d "$FOLDER" ]; then
    echo -e "${RED}Error: directory '$FOLDER' not found${NC}"
    exit 1
fi

# Check for .sensitive-file-patterns file
PATTERNS_FILE="$FOLDER/.sensitive-file-patterns"
if [ ! -f "$PATTERNS_FILE" ]; then
    echo -e "${RED}Error: No .sensitive-file-patterns file found in $FOLDER${NC}"
    echo -e "${YELLOW}Run '$0 --init $FOLDER' to create one${NC}"
    exit 1
fi

# Load patterns from file
SENSITIVE_FILE_PATTERNS=()
EXCLUDE_PATTERNS=()
while IFS= read -r line; do
    # Skip empty lines and comments
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    # Trim whitespace
    line=$(echo "$line" | xargs)
    if [ -n "$line" ]; then
        if [[ "$line" == !* ]]; then
            # Exclusion pattern - remove the ! prefix
            EXCLUDE_PATTERNS+=("${line:1}")
        else
            SENSITIVE_FILE_PATTERNS+=("$line")
        fi
    fi
done < "$PATTERNS_FILE"

if [ ${#SENSITIVE_FILE_PATTERNS[@]} -eq 0 ]; then
    echo -e "${YELLOW}Warning: No patterns found in .sensitive-file-patterns${NC}"
    echo -e "${YELLOW}Edit $PATTERNS_FILE to add file patterns${NC}"
    exit 0
fi

echo "🔐 Encrypting sensitive files in folder: $FOLDER"
echo -e "${YELLOW}Using patterns from .sensitive-file-patterns${NC}"

# Check if OpenSSL is installed
if ! command -v openssl &> /dev/null; then
    echo -e "${RED}Error: OpenSSL is not installed${NC}"
    echo "Install it with:"
    echo "  brew install openssl  # macOS"
    echo "  apt-get install openssl  # Ubuntu/Debian"
    exit 1
fi

# Counter for encrypted files
encrypted_count=0
files_to_encrypt=()

# Find all sensitive files in directory
echo -e "\n${YELLOW}Looking for sensitive files in $FOLDER/...${NC}"

# Build find command with all patterns, excluding .enc files
find_conditions=()
for i in "${!SENSITIVE_FILE_PATTERNS[@]}"; do
    if [ $i -eq 0 ]; then
        find_conditions+=("(" "-name" "${SENSITIVE_FILE_PATTERNS[$i]}")
    else
        find_conditions+=("-o" "-name" "${SENSITIVE_FILE_PATTERNS[$i]}")
    fi
done
find_conditions+=(")" "-not" "-name" "*.enc")

# Add exclusion patterns
for pattern in "${EXCLUDE_PATTERNS[@]}"; do
    find_conditions+=("-not" "-name" "$pattern")
done

# Find all matching files (excluding .enc files and exclusion patterns)
while IFS= read -r -d '' file; do
    files_to_encrypt+=("$file")
done < <(find "$FOLDER" "${find_conditions[@]}" -type f -print0 2>/dev/null)

# Check if any files found
if [ ${#files_to_encrypt[@]} -eq 0 ]; then
    echo -e "${YELLOW}No sensitive files found in $FOLDER/${NC}"
    exit 0
fi

# Show files that will be encrypted
echo -e "\n${GREEN}Files to be encrypted:${NC}"
for file in "${files_to_encrypt[@]}"; do
    if [ -f "${file}.enc" ]; then
        echo -e "  ${YELLOW}📄${NC} $file ${RED}(will overwrite existing .enc)${NC}"
    else
        echo -e "  ${GREEN}📄${NC} $file ${GREEN}(new)${NC}"
    fi
done

echo -e "\n${YELLOW}Total: ${#files_to_encrypt[@]} file(s) will be encrypted${NC}"

# Password validation function is in config.sh

# Get encryption password once
while true; do
    echo -n "Enter encryption key for all files of \"$FOLDER\": "
    IFS= read -r -s password
    echo
    
    # Check for tabs or other problematic whitespace
    if [[ "$password" == *$'\t'* ]]; then
        echo -e "${RED}Error: Password contains tab character. Please avoid using tabs.${NC}\n"
        continue
    fi
    
    # Check if password is empty or only whitespace
    if [[ -z "${password// }" ]]; then
        echo -e "${RED}Error: Password cannot be empty${NC}\n"
        continue
    fi
    
    # Validate password strength
    if ! validate_password "$password"; then
        echo -e "\n${YELLOW}Please choose a stronger password${NC}"
        continue
    fi
    
    echo -n "Confirm encryption key: "
    IFS= read -r -s password2
    echo
    
    if [ "$password" != "$password2" ]; then
        echo -e "${RED}Error: Passwords don't match${NC}\n"
        continue
    fi
    
    echo -e "${GREEN}✓ Password meets security requirements${NC}"
    break
done

# Encrypt each file with the same password
echo -e "\n${GREEN}Encrypting ${#files_to_encrypt[@]} file(s)${NC}"
for file in "${files_to_encrypt[@]}"; do
    if [ -f "$file" ]; then
        # Encrypt directly to .enc file using OpenSSL
        if openssl enc -${ENCRYPTION_ALGORITHM} -pbkdf2 -iter ${PBKDF2_ITERATIONS} -salt -in "$file" -out "${file}.enc" -pass pass:"$password" 2>/dev/null; then
            # Encryption successful
            echo -e "${GREEN}✓ Encrypted: $file -> ${file}.enc${NC}"
            encrypted_count=$((encrypted_count + 1))
        else
            echo -e "${RED}✗ Failed to encrypt: $file${NC}"
            # Remove the failed .enc file if it was created
            rm -f "${file}.enc"
        fi
    fi
done

# Summary
echo -e "\n${GREEN}════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Encryption complete for $FOLDER!${NC}"
echo -e "${GREEN}  Total files encrypted: $encrypted_count${NC}"
echo -e "${GREEN}════════════════════════════════════════${NC}"

# List encrypted files
if [ $encrypted_count -gt 0 ]; then
    echo -e "\n${GREEN}Encrypted files:${NC}"
    for file in "${files_to_encrypt[@]}"; do
        if [ -f "${file}.enc" ]; then
            echo -e "  ${GREEN}✓${NC} ${file}.enc"
        fi
    done
fi

# Reminder
echo -e "\n${YELLOW}⚠️  Important reminders:${NC}"
echo "  1. Keep your encryption password safe!"
echo "  2. Never commit the unencrypted files"
echo "  3. Add *.enc files to git: git add $FOLDER/*.enc"
echo "  4. The unencrypted files are in .gitignore"

exit 0