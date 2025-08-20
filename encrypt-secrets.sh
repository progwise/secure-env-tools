#!/bin/bash

# Script to encrypt all sensitive files before committing to Git
# Usage: ./encrypt-secrets.sh [customer-name]
# Example: ./encrypt-secrets.sh cheplapharm
# Requires OpenSSL to be installed

set -e

# Define file patterns to encrypt (easily extendable)
SENSITIVE_FILE_PATTERNS=(
    "credentials.*"
    "*.env"
    "*.pem"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Parse arguments
CUSTOMER="$1"
if [ -z "$CUSTOMER" ]; then
    echo -e "${YELLOW}Usage: $0 <customer-name>${NC}"
    echo "Example: $0 cheplapharm"
    echo -e "\n${YELLOW}Available customers:${NC}"
    for dir in */; do
        if [ -d "$dir" ] && [ "$dir" != ".git/" ]; then
            echo "  - ${dir%/}"
        fi
    done
    exit 1
fi

# Check if customer directory exists
if [ ! -d "$CUSTOMER" ]; then
    echo -e "${RED}Error: Customer directory '$CUSTOMER' not found${NC}"
    exit 1
fi

echo "🔐 Encrypting sensitive files for customer: $CUSTOMER"

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

# Find all sensitive files in customer directory
echo -e "\n${YELLOW}Looking for sensitive files in $CUSTOMER/...${NC}"

# Build find command with all patterns, excluding .cpt files
find_conditions=()
for i in "${!SENSITIVE_FILE_PATTERNS[@]}"; do
    if [ $i -eq 0 ]; then
        find_conditions+=("(" "-name" "${SENSITIVE_FILE_PATTERNS[$i]}")
    else
        find_conditions+=("-o" "-name" "${SENSITIVE_FILE_PATTERNS[$i]}")
    fi
done
find_conditions+=(")" "-not" "-name" "*.enc")

# Find all matching files (excluding .enc files)
while IFS= read -r -d '' file; do
    files_to_encrypt+=("$file")
done < <(find "$CUSTOMER" "${find_conditions[@]}" -type f -print0 2>/dev/null)

# Check if any files found
if [ ${#files_to_encrypt[@]} -eq 0 ]; then
    echo -e "${YELLOW}No sensitive files found in $CUSTOMER/${NC}"
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

# Function to validate password strength
validate_password() {
    local pass="$1"
    local errors=""
    
    # Check minimum length
    if [ ${#pass} -lt 12 ]; then
        errors="${errors}\n  ✗ At least 12 characters required (current: ${#pass})"
    fi
    
    # Check for lowercase letter
    if ! [[ "$pass" =~ [a-z] ]]; then
        errors="${errors}\n  ✗ At least one lowercase letter required"
    fi
    
    # Check for uppercase letter
    if ! [[ "$pass" =~ [A-Z] ]]; then
        errors="${errors}\n  ✗ At least one uppercase letter required"
    fi
    
    # Check for number
    if ! [[ "$pass" =~ [0-9] ]]; then
        errors="${errors}\n  ✗ At least one number required"
    fi
    
    # Check for special character
    if ! [[ "$pass" =~ [^a-zA-Z0-9] ]]; then
        errors="${errors}\n  ✗ At least one special character required (!@#$%^&*()_+-=[]{}|;:,.<>?)"
    fi
    
    if [ -n "$errors" ]; then
        echo -e "${RED}Password does not meet security requirements:${NC}"
        echo -e "$errors"
        return 1
    fi
    
    return 0
}

# Get encryption password once
while true; do
    echo -n "Enter encryption key for all files of \"$CUSTOMER\": "
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
        if openssl enc -aes-256-cbc -pbkdf2 -iter 100000 -salt -in "$file" -out "${file}.enc" -pass pass:"$password" 2>/dev/null; then
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
echo -e "${GREEN}✓ Encryption complete for $CUSTOMER!${NC}"
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
echo "  3. Add *.enc files to git: git add $CUSTOMER/*.enc"
echo "  4. The unencrypted files are in .gitignore"

exit 0