#!/bin/sh
#
# install_dotfiles_prereqs.sh
#

# Steps:
# 1. Exit unless darwin
# 2. Exit unless admin
# 3. Initiate sudo caching
# 3. Ensure homebrew installed and configured
# 4. Ensure gnupg installed and configured
# 5. Ensure chezmoi installed
# 6. ...
# 7. Success!

# Check if system is macOS (Darwin)
if [ "$(uname)" != "Darwin" ]; then
    echo "Error: This script requires macOS (Darwin)."
    exit 1
fi

# Check if user is in admin group
if id -G -n | grep -q ' admin '; then
    : # User is in admin group, proceed
else
    echo "Error: This script requires the user to be in the admin group."
    exit 1
fi

# Prompt user to cache sudo credentials
echo "This script requires sudo access. You may be prompted for your password."
if sudo -v; then
    : # Sudo credentials cached, proceed
else
    echo "Error: Failed to obtain sudo access. Please ensure you have sudo privileges."
    exit 1
fi

# Check if brew command is available
if command -v brew >/dev/null 2>&1; then
    echo "Homebrew is already installed."
else
    echo "Homebrew not found."
    printf "Do you want to install Homebrew? (y/n): "
    read -r answer
    case "$answer" in
        [Yy]*)
            echo "Installing Homebrew..."
            if /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
                echo "Homebrew installed successfully."
                # Add Homebrew to PATH for immediate use
                PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
                # Verify brew is now available
                if command -v brew >/dev/null 2>&1; then
                    echo "Homebrew is now available in the PATH."
                else
                    echo "Error: Homebrew installed, but brew command is not available."
                    exit 1
                fi
            else
                echo "Error: Failed to install Homebrew."
                exit 1
            fi
            ;;
        *)
            echo "Homebrew installation skipped. Exiting."
            exit 0
            ;;
    esac
fi

# Check if gnupg is installed
if command -v gpg >/dev/null 2>&1; then
    echo "GnuPG is already installed."
else
    echo "GnuPG not found."
    printf "Do you want to install GnuPG? (y/n): "
    read -r answer
    case "$answer" in
        [Yy]*)
            echo "Installing GnuPG with Homebrew..."
            if brew install gnupg; then
                echo "GnuPG installed successfully."
                # Verify gpg is now available
                if command -v gpg >/dev/null 2>&1; then
                    echo "GnuPG (gpg command) is now available in the PATH."
                else
                    echo "Error: GnuPG installed, but gpg command is not available."
                    exit 1
                fi
            else
                echo "Error: Failed to install GnuPG."
                exit 1
            fi
            ;;
        *)
            echo "GnuPG installation skipped. Exiting."
            exit 0
            ;;
    esac
fi
