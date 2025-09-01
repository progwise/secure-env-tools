#!/bin/bash

# Test script for encrypt-secrets.sh and decrypt-secrets.sh
# Usage: ./run-tests.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# Test password that meets requirements
TEST_PASSWORD="TestPass123!@#"

# Test directory
TEST_DIR="test-secure-env"

# Function to print test header
print_test_header() {
    echo -e "\n${BLUE}════════════════════════════════════════${NC}"
    echo -e "${BLUE}TEST: $1${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
}

# Function to check test result
check_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓ $2${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ $2${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Function to setup test environment
setup_test_env() {
    echo -e "${YELLOW}Setting up test environment...${NC}"
    
    # Clean up any existing test directory
    rm -rf "$TEST_DIR"
    
    # Create nested directory structure
    mkdir -p "$TEST_DIR/project1/config/secrets"
    mkdir -p "$TEST_DIR/project1/ssl/certs"
    mkdir -p "$TEST_DIR/project2/env"
    mkdir -p "$TEST_DIR/standalone"
    
    # Create test files matching sensitive patterns
    echo "user=admin" > "$TEST_DIR/project1/credentials.txt"
    echo "api_key=secret123" > "$TEST_DIR/project1/credentials.yml"
    echo "DB_PASSWORD=secret" > "$TEST_DIR/project1/config/.env"
    echo "API_KEY=xyz123" > "$TEST_DIR/project1/config/secrets/production.env"
    echo "-----BEGIN PRIVATE KEY-----" > "$TEST_DIR/project1/ssl/server.pem"
    echo "-----BEGIN CERTIFICATE-----" > "$TEST_DIR/project1/ssl/certs/client.pem"
    echo "STRIPE_KEY=sk_test_123" > "$TEST_DIR/project2/env/development.env"
    echo "AWS_SECRET=aws123" > "$TEST_DIR/standalone/.env"
    
    # Create some non-sensitive files (should be ignored)
    echo "# README" > "$TEST_DIR/README.md"
    echo "console.log('test');" > "$TEST_DIR/project1/app.js"
    echo "import React from 'react';" > "$TEST_DIR/project2/index.tsx"
    
    echo -e "${GREEN}Test environment created${NC}"
}

# Function to cleanup test environment
cleanup_test_env() {
    echo -e "${YELLOW}Cleaning up test environment...${NC}"
    rm -rf "$TEST_DIR"
    echo -e "${GREEN}Cleanup complete${NC}"
}

# Test 1: Verify scripts exist and are executable
print_test_header "Script Availability"

if [ -f "./encrypt-secrets.sh" ] && [ -x "./encrypt-secrets.sh" ]; then
    check_result 0 "encrypt-secrets.sh exists and is executable"
else
    check_result 1 "encrypt-secrets.sh exists and is executable"
fi

if [ -f "./decrypt-secrets.sh" ] && [ -x "./decrypt-secrets.sh" ]; then
    check_result 0 "decrypt-secrets.sh exists and is executable"
else
    check_result 1 "decrypt-secrets.sh exists and is executable"
fi

# Test 2: Test encryption with subdirectories
print_test_header "Encryption with Subdirectories"

setup_test_env

# Run encryption
echo -e "${TEST_PASSWORD}\n${TEST_PASSWORD}" | ./encrypt-secrets.sh "$TEST_DIR" > /dev/null 2>&1

# Check if all sensitive files were encrypted
EXPECTED_ENC_FILES=(
    "$TEST_DIR/project1/credentials.txt.enc"
    "$TEST_DIR/project1/credentials.yml.enc"
    "$TEST_DIR/project1/config/.env.enc"
    "$TEST_DIR/project1/config/secrets/production.env.enc"
    "$TEST_DIR/project1/ssl/server.pem.enc"
    "$TEST_DIR/project1/ssl/certs/client.pem.enc"
    "$TEST_DIR/project2/env/development.env.enc"
    "$TEST_DIR/standalone/.env.enc"
)

ALL_ENCRYPTED=true
for enc_file in "${EXPECTED_ENC_FILES[@]}"; do
    if [ ! -f "$enc_file" ]; then
        ALL_ENCRYPTED=false
        echo -e "${RED}  Missing: $enc_file${NC}"
    fi
done

if [ "$ALL_ENCRYPTED" = true ]; then
    check_result 0 "All sensitive files encrypted in subdirectories (8 files)"
else
    check_result 1 "All sensitive files encrypted in subdirectories"
fi

# Verify non-sensitive files were NOT encrypted
if [ ! -f "$TEST_DIR/README.md.enc" ] && [ ! -f "$TEST_DIR/project1/app.js.enc" ]; then
    check_result 0 "Non-sensitive files were not encrypted"
else
    check_result 1 "Non-sensitive files were not encrypted"
fi

# Test 3: Test decryption with subdirectories
print_test_header "Decryption with Subdirectories"

# Remove original files
find "$TEST_DIR" -type f \( -name "credentials.*" -o -name "*.env" -o -name "*.pem" \) ! -name "*.enc" -delete

# Run decryption
echo "${TEST_PASSWORD}" | ./decrypt-secrets.sh "$TEST_DIR" > /dev/null 2>&1

# Check if all files were decrypted
EXPECTED_DEC_FILES=(
    "$TEST_DIR/project1/credentials.txt"
    "$TEST_DIR/project1/credentials.yml"
    "$TEST_DIR/project1/config/.env"
    "$TEST_DIR/project1/config/secrets/production.env"
    "$TEST_DIR/project1/ssl/server.pem"
    "$TEST_DIR/project1/ssl/certs/client.pem"
    "$TEST_DIR/project2/env/development.env"
    "$TEST_DIR/standalone/.env"
)

ALL_DECRYPTED=true
for dec_file in "${EXPECTED_DEC_FILES[@]}"; do
    if [ ! -f "$dec_file" ]; then
        ALL_DECRYPTED=false
        echo -e "${RED}  Missing: $dec_file${NC}"
    fi
done

if [ "$ALL_DECRYPTED" = true ]; then
    check_result 0 "All encrypted files decrypted in subdirectories (8 files)"
else
    check_result 1 "All encrypted files decrypted in subdirectories"
fi

# Test 4: Test current directory encryption
print_test_header "Current Directory Encryption"

cd "$TEST_DIR"
echo -e "${TEST_PASSWORD}\n${TEST_PASSWORD}" | ../encrypt-secrets.sh . > /dev/null 2>&1
cd ..

# Count encrypted files
ENC_COUNT=$(find "$TEST_DIR" -name "*.enc" -type f | wc -l | tr -d ' ')
if [ "$ENC_COUNT" -eq "8" ]; then  # Should still be 8 files (overwrites existing)
    check_result 0 "Current directory encryption works (. as argument)"
else
    check_result 1 "Current directory encryption works (expected 8 .enc files, found $ENC_COUNT)"
fi

# Test 5: Test wrong password handling
print_test_header "Wrong Password Handling"

# Try to decrypt with wrong password
echo "WrongPass123!@#" | ./decrypt-secrets.sh "$TEST_DIR" 2>&1 | grep -q "Failed to decrypt" && WRONG_PASS_RESULT=0 || WRONG_PASS_RESULT=1
check_result $WRONG_PASS_RESULT "Wrong password is properly rejected"

# Test 6: Test file pattern matching
print_test_header "File Pattern Matching"

# Setup specific pattern test
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR/patterns"

# Create files that should match
echo "test" > "$TEST_DIR/patterns/credentials.json"
echo "test" > "$TEST_DIR/patterns/credentials.yaml"
echo "test" > "$TEST_DIR/patterns/test.env"
echo "test" > "$TEST_DIR/patterns/local.env"
echo "test" > "$TEST_DIR/patterns/server.pem"
echo "test" > "$TEST_DIR/patterns/client.pem"

# Create files that should NOT match
echo "test" > "$TEST_DIR/patterns/config.json"
echo "test" > "$TEST_DIR/patterns/package.json"
echo "test" > "$TEST_DIR/patterns/server.crt"
echo "test" > "$TEST_DIR/patterns/notes.txt"

# Run encryption
echo -e "${TEST_PASSWORD}\n${TEST_PASSWORD}" | ./encrypt-secrets.sh "$TEST_DIR/patterns" > /dev/null 2>&1

# Check pattern matching (now includes *.crt from config.sh)
PATTERN_MATCH_COUNT=$(find "$TEST_DIR/patterns" -name "*.enc" -type f | wc -l | tr -d ' ')
if [ "$PATTERN_MATCH_COUNT" -eq "7" ]; then
    check_result 0 "Pattern matching works correctly (7 files matched)"
else
    check_result 1 "Pattern matching works correctly (expected 7, found $PATTERN_MATCH_COUNT)"
fi

# Test 7: Test empty directory handling
print_test_header "Empty Directory Handling"

mkdir -p "$TEST_DIR/empty"
./encrypt-secrets.sh "$TEST_DIR/empty" 2>&1 | grep -q "No sensitive files found" && EMPTY_RESULT=0 || EMPTY_RESULT=1
check_result $EMPTY_RESULT "Empty directory handled gracefully"

# Test 8: Test non-existent directory handling
print_test_header "Non-existent Directory Handling"

./encrypt-secrets.sh "$TEST_DIR/nonexistent" 2>&1 | grep -q "Error: directory" && NONEXIST_RESULT=0 || NONEXIST_RESULT=1
check_result $NONEXIST_RESULT "Non-existent directory error handled"

# Test 9: Test password validation
print_test_header "Password Validation"

# Test weak password (too short)
echo -e "weak\nweak" | ./encrypt-secrets.sh "$TEST_DIR" 2>&1 | grep -q "At least 12 characters" && WEAK_PASS=0 || WEAK_PASS=1
check_result $WEAK_PASS "Weak password rejected (length check)"

# Test password without special chars
echo -e "LongPassword123\nLongPassword123" | ./encrypt-secrets.sh "$TEST_DIR" 2>&1 | grep -q "special character required" && NO_SPECIAL=0 || NO_SPECIAL=1
check_result $NO_SPECIAL "Password without special characters rejected"

# Test 10: Test idempotency (re-encryption)
print_test_header "Idempotency Test"

# First encryption
setup_test_env
echo -e "${TEST_PASSWORD}\n${TEST_PASSWORD}" | ./encrypt-secrets.sh "$TEST_DIR" > /dev/null 2>&1
FIRST_ENC_COUNT=$(find "$TEST_DIR" -name "*.enc" -type f | wc -l | tr -d ' ')

# Second encryption (should overwrite)
echo -e "${TEST_PASSWORD}\n${TEST_PASSWORD}" | ./encrypt-secrets.sh "$TEST_DIR" 2>&1 | grep -q "will overwrite existing .enc" && OVERWRITE_MSG=0 || OVERWRITE_MSG=1
SECOND_ENC_COUNT=$(find "$TEST_DIR" -name "*.enc" -type f | wc -l | tr -d ' ')

if [ "$FIRST_ENC_COUNT" -eq "$SECOND_ENC_COUNT" ] && [ "$OVERWRITE_MSG" -eq 0 ]; then
    check_result 0 "Re-encryption overwrites existing .enc files correctly"
else
    check_result 1 "Re-encryption overwrites existing .enc files correctly"
fi

# Cleanup
cleanup_test_env

# Print summary
echo -e "\n${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}TEST SUMMARY${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}✓ All tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}✗ Some tests failed${NC}"
    exit 1
fi