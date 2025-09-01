# Secure Environment Tools

🔐 A collection of tools for securely managing sensitive configuration files using OpenSSL encryption.

## Features

- **Strong Encryption**: AES-256-CBC with PBKDF2 key derivation (100,000 iterations)
- **Customer-Specific**: Organize sensitive files by customer/environment
- **Safe Operations**: Atomic operations prevent data loss on wrong passwords
- **Easy Installation**: One-command global installation
- **Cross-Platform**: Works on macOS, Linux, and other Unix-like systems

## Quick Start

### Installation

```bash
# System-wide installation (recommended)
curl -sSL https://raw.githubusercontent.com/progwise/secure-env-tools/main/install.sh | sudo bash

# User installation (no sudo required)
curl -sSL https://raw.githubusercontent.com/progwise/secure-env-tools/main/install.sh | bash
```

### Basic Usage

```bash
# 1. Initialize patterns file for a project
encrypt-secrets --init ./my-project

# 2. Edit patterns file to customize which files to encrypt
vim ./my-project/.sensitive-patterns.txt

# 3. Encrypt sensitive files
encrypt-secrets ./my-project

# 4. Decrypt files when needed
decrypt-secrets ./my-project

# Use current directory
encrypt-secrets --init .
encrypt-secrets .
decrypt-secrets .
```

## Prerequisites

- **OpenSSL** (usually pre-installed)
- **Bash** 4.0+ 
- **curl** (for installation)

Check if OpenSSL is available:
```bash
openssl version
```

If not installed:
```bash
# macOS
brew install openssl

# Ubuntu/Debian  
sudo apt-get install openssl

# CentOS/RHEL
sudo yum install openssl
```

## Detailed Usage

### Encrypt Files

```bash
# Show files to be encrypted, then prompt for password
encrypt-secrets customer-name

# Example output:
# 🔐 Encrypting sensitive files for customer: acme-corp
# 
# Files to be encrypted:
#   📄 acme-corp/.env (new)  
#   📄 acme-corp/credentials.md (will overwrite existing .enc)
#   📄 acme-corp/ssl-cert.pem (new)
#
# Enter encryption key: [secure password input]
```

### Decrypt Files

```bash
# Show files to be decrypted, then prompt for password
decrypt-secrets customer-name

# Example output:
# 🔓 Decrypting sensitive files for customer: acme-corp
#
# Files to be decrypted:
#   🔓 acme-corp/.env.enc → acme-corp/.env (new)
#   🔓 acme-corp/credentials.md.enc → acme-corp/credentials.md (will overwrite)
#
# Enter decryption key: [secure password input]
```

## Manual Encryption (Advanced)

For one-off encryption outside the scripts:

```bash
# Encrypt a file
openssl enc -aes-256-cbc -pbkdf2 -iter 100000 -salt -in secret.txt -out secret.txt.enc

# Decrypt a file
openssl enc -aes-256-cbc -pbkdf2 -iter 100000 -d -in secret.txt.enc -out secret.txt

# Non-interactive (scripting)
openssl enc -aes-256-cbc -pbkdf2 -iter 100000 -salt -in secret.txt -out secret.txt.enc -pass pass:"your_password"
```

## Security Features

### Password Requirements

Encryption passwords must meet these requirements:
- ✅ Minimum 12 characters
- ✅ At least one lowercase letter
- ✅ At least one uppercase letter  
- ✅ At least one number
- ✅ At least one special character
- ❌ No tab characters allowed

### Safe Operations

- **Atomic decryption**: Wrong passwords won't destroy existing files
- **Temporary file cleanup**: No sensitive data left in temp files
- **Memory safety**: Passwords not written to disk
- **Process security**: Minimal exposure in process lists

## Workflow Integration

### Git Repository Structure

```
your-repo/
├── customer-a/
│   ├── .env.enc          # ✅ Commit this
│   ├── credentials.md.enc # ✅ Commit this
│   ├── .env              # ❌ Don't commit (in .gitignore)
│   └── credentials.md    # ❌ Don't commit (in .gitignore)
├── customer-b/
│   └── ...
└── .gitignore           # Exclude unencrypted files
```

### Recommended .gitignore

```gitignore
# Sensitive files - Never commit unencrypted versions
**/*.pem
**/credentials.*
**/.env
**/*.env

# Allow encrypted versions
!**/*.enc

# OS files
.DS_Store
Thumbs.db
```

### Development Workflow

```bash
# 1. Clone repository
git clone your-customer-configs
cd your-customer-configs

# 2. Decrypt files for work
decrypt-secrets customer-name

# 3. Edit configuration files
vim customer-name/.env

# 4. Encrypt before committing
encrypt-secrets customer-name

# 5. Commit encrypted files
git add customer-name/*.enc
git commit -m "Update customer configuration"
```

### Deployment Workflow

```bash
# On customer server
git clone --sparse-checkout your-customer-configs
cd your-customer-configs
git sparse-checkout set customer-name
decrypt-secrets customer-name

# Files are now ready for deployment
```

## Error Handling

### Common Issues

**Wrong password during decryption:**
```
✗ Failed to decrypt: customer/.env.enc
  Error: Wrong password or corrupted file
```

**Missing OpenSSL:**
```
Error: OpenSSL is not installed
Install it with:
  brew install openssl  # macOS
```

**No patterns file:**
```
Error: No .sensitive-patterns.txt file found
Run 'encrypt-secrets --init ./folder' to create one
```

**No sensitive files found:**
```
No sensitive files found in folder/
```

### Troubleshooting

1. **Verify OpenSSL**: `openssl version`
2. **Check file permissions**: `ls -la *.enc`
3. **Verify file integrity**: Ensure `.enc` files aren't corrupted
4. **Password accuracy**: Passwords are case-sensitive

## Testing

The repository includes a comprehensive test suite that verifies all functionality:

```bash
# Run all tests
./run-tests.sh

# Tests include:
# ✓ Script availability
# ✓ Encryption with subdirectories
# ✓ Decryption functionality
# ✓ Current directory usage (.)
# ✓ Pattern file handling
# ✓ Exclusion patterns (!pattern)
# ✓ Password validation
# ✓ Error handling
# ✓ Empty directory handling
# ✓ Idempotency (re-encryption)
```

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature-name`
3. Make changes and test thoroughly: `./run-tests.sh`
4. Commit: `git commit -m "Add feature"`
5. Push: `git push origin feature-name`
6. Create a Pull Request

## Security Considerations

- **Never commit unencrypted sensitive files**
- **Use strong, unique passwords for each customer**
- **Store passwords securely (password manager recommended)**
- **Regularly rotate encryption passwords**
- **Use secure channels to share passwords with team members**

## License

MIT License - see LICENSE file for details

## Support

- 🐛 **Issues**: [GitHub Issues](https://github.com/progwise/secure-env-tools/issues)
- 📚 **Documentation**: This README
- 💬 **Discussions**: [GitHub Discussions](https://github.com/progwise/secure-env-tools/discussions)

---

**⚠️ Security Notice**: These tools handle sensitive data. Always verify you're downloading from the official repository and review the code before installation.