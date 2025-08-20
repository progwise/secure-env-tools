#!/bin/bash

  # Secure Environment Tools Installer
  # This script installs encrypt-secrets.sh and decrypt-secrets.sh globally

  set -e

  # Colors for output
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  NC='\033[0m' # No Color

  REPO_URL="https://raw.githubusercontent.com/your-org/secure-env-tools/main"
  INSTALL_DIR="/usr/local/bin"
  SCRIPTS=("encrypt-secrets.sh" "decrypt-secrets.sh")

  echo "🔧 Installing Secure Environment Tools..."

  # Check if running as root for system-wide install
  if [ "$EUID" -eq 0 ]; then
      INSTALL_DIR="/usr/local/bin"
      echo -e "${GREEN}Installing system-wide to $INSTALL_DIR${NC}"
  else
      # Install to user directory
      INSTALL_DIR="$HOME/.local/bin"
      mkdir -p "$INSTALL_DIR"
      echo -e "${YELLOW}Installing to user directory $INSTALL_DIR${NC}"

      # Check if ~/.local/bin is in PATH
      if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
          echo -e "${YELLOW}Adding $HOME/.local/bin to PATH${NC}"
          echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
          echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc 2>/dev/null || true
          export PATH="$HOME/.local/bin:$PATH"
      fi
  fi

  # Check prerequisites
  echo "🔍 Checking prerequisites..."

  # Check OpenSSL
  if ! command -v openssl &> /dev/null; then
      echo -e "${RED}Error: OpenSSL is not installed${NC}"
      echo "Install it with:"
      echo "  brew install openssl  # macOS"
      echo "  apt-get install openssl  # Ubuntu/Debian"
      exit 1
  fi

  openssl_version=$(openssl version)
  echo -e "${GREEN}✓ OpenSSL found: $openssl_version${NC}"

  # Check curl
  if ! command -v curl &> /dev/null; then
      echo -e "${RED}Error: curl is required but not installed${NC}"
      exit 1
  fi

  # Download and install scripts
  echo -e "\n📥 Downloading scripts..."

  for script in "${SCRIPTS[@]}"; do
      echo -n "  Downloading $script... "

      if curl -sSL "$REPO_URL/$script" -o "$INSTALL_DIR/$script"; then
          chmod +x "$INSTALL_DIR/$script"
          echo -e "${GREEN}✓${NC}"
      else
          echo -e "${RED}✗ Failed${NC}"
          echo -e "${RED}Error: Failed to download $script${NC}"
          exit 1
      fi
  done

  # Verify installation
  echo -e "\n🔍 Verifying installation..."

  for script in "${SCRIPTS[@]}"; do
      script_name="${script%.sh}"  # Remove .sh extension for command
      if command -v "$script_name" &> /dev/null; then
          echo -e "${GREEN}✓ $script_name is available${NC}"
      else
          echo -e "${YELLOW}⚠️  $script_name may not be in PATH${NC}"
      fi
  done

  # Success message
  echo -e "\n${GREEN}════════════════════════════════════════${NC}"
  echo -e "${GREEN}✅ Installation complete!${NC}"
  echo -e "${GREEN}════════════════════════════════════════${NC}"

  echo -e "\n${YELLOW}Available commands:${NC}"
  echo "  encrypt-secrets <customer-name>  # Encrypt sensitive files"
  echo "  decrypt-secrets <customer-name>  # Decrypt encrypted files"

  echo -e "\n${YELLOW}Example usage:${NC}"
  echo "  cd your-customer-repo/customer-folder"
  echo "  decrypt-secrets"
  echo "  # Edit your files..."
  echo "  encrypt-secrets customer-name"

  if [ "$EUID" -ne 0 ]; then
      echo -e "\n${YELLOW}Note: You may need to restart your shell or 
  run:${NC}"
      echo "  source ~/.bashrc"
      echo "  # or"
      echo "  source ~/.zshrc"
  fi

  echo -e "\n${GREEN}🔐 Your secure environment tools are ready!${NC}"
