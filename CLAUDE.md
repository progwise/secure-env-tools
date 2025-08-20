# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a collection of bash scripts for securely managing sensitive configuration files using OpenSSL encryption. The tools encrypt/decrypt files with patterns like `credentials.*`, `*.env`, and `*.pem` using AES-256-CBC with PBKDF2 key derivation.

## Core Scripts

- **encrypt-secrets.sh**: Encrypts sensitive files before committing to Git
- **decrypt-secrets.sh**: Decrypts .enc files after cloning/pulling from Git  
- **install.sh**: Installs scripts globally to system PATH

## Common Commands

### Script Usage
```bash
# Encrypt all sensitive files for a customer
./encrypt-secrets.sh customer-name

# Decrypt all .enc files for a customer
./decrypt-secrets.sh customer-name

# Install scripts globally (system-wide with sudo)
curl -sSL https://raw.githubusercontent.com/progwise/secure-env-tools/main/install.sh | sudo bash

# Install scripts to user directory (no sudo)
curl -sSL https://raw.githubusercontent.com/progwise/secure-env-tools/main/install.sh | bash
```

### Testing Scripts
```bash
# Test encryption script
./encrypt-secrets.sh test-customer

# Test decryption script  
./decrypt-secrets.sh test-customer

# Verify OpenSSL is working
openssl version
```

## Code Architecture

### File Patterns
Both encryption and decryption scripts use identical `SENSITIVE_FILE_PATTERNS` array:
- `credentials.*` - Any credentials file with any extension
- `*.env` - Environment files  
- `*.pem` - SSL certificates and private keys

### Security Features
- **Password validation**: 12+ chars, mixed case, numbers, special characters
- **Atomic operations**: Uses temp files to prevent data loss on failures
- **Safe decryption**: Wrong passwords don't destroy existing files
- **OpenSSL encryption**: AES-256-CBC with PBKDF2 (100,000 iterations)

### Error Handling
Scripts include comprehensive error checking for:
- Missing OpenSSL installation
- Non-existent customer directories
- Password strength validation
- File encryption/decryption failures
- Tab characters in passwords (problematic with OpenSSL)

## Repository Structure

```
secure-env-tools/
├── encrypt-secrets.sh    # Main encryption script
├── decrypt-secrets.sh    # Main decryption script  
├── install.sh           # Global installer
└── README.md           # User documentation
```

## Development Notes

- Scripts use `set -e` for strict error handling
- Color-coded output using ANSI codes (RED, GREEN, YELLOW, NC)
- File operations use `find` with `-print0` for safe filename handling
- Password input uses `read -s` to hide input from terminal
- Temporary files use `.tmp_decrypt` suffix for safety

## Security Considerations

- Never commit unencrypted sensitive files
- Use strong, unique passwords for each customer
- The `.enc` files are safe to commit to Git
- Original sensitive files should be in `.gitignore`