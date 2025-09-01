#!/bin/bash

# Shared configuration for secure-env-tools
# This file is sourced by both encrypt-secrets.sh and decrypt-secrets.sh

# Encryption settings
ENCRYPTION_ALGORITHM="aes-256-cbc"
PBKDF2_ITERATIONS=100000

# Colors for output (shared across scripts)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Password validation settings
MIN_PASSWORD_LENGTH=12
REQUIRE_LOWERCASE=true
REQUIRE_UPPERCASE=true
REQUIRE_NUMBERS=true
REQUIRE_SPECIAL_CHARS=true

# Function to validate password strength
validate_password() {
    local pass="$1"
    local errors=""
    
    # Check minimum length
    if [ ${#pass} -lt $MIN_PASSWORD_LENGTH ]; then
        errors="${errors}\n  ✗ At least $MIN_PASSWORD_LENGTH characters required (current: ${#pass})"
    fi
    
    # Check for lowercase letter
    if [ "$REQUIRE_LOWERCASE" = true ] && ! [[ "$pass" =~ [a-z] ]]; then
        errors="${errors}\n  ✗ At least one lowercase letter required"
    fi
    
    # Check for uppercase letter
    if [ "$REQUIRE_UPPERCASE" = true ] && ! [[ "$pass" =~ [A-Z] ]]; then
        errors="${errors}\n  ✗ At least one uppercase letter required"
    fi
    
    # Check for number
    if [ "$REQUIRE_NUMBERS" = true ] && ! [[ "$pass" =~ [0-9] ]]; then
        errors="${errors}\n  ✗ At least one number required"
    fi
    
    # Check for special character
    if [ "$REQUIRE_SPECIAL_CHARS" = true ] && ! [[ "$pass" =~ [^a-zA-Z0-9] ]]; then
        errors="${errors}\n  ✗ At least one special character required (!@#$%^&*()_+-=[]{}|;:,.<>?)"
    fi
    
    if [ -n "$errors" ]; then
        echo -e "${RED}Password does not meet security requirements:${NC}"
        echo -e "$errors"
        return 1
    fi
    
    return 0
}

