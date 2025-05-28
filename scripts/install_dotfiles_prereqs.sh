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
    echo "Homebrew not found. Installing Homebrew..."
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
fi

# Provide instructions for adding Homebrew to shell configuration
echo "To ensure Homebrew works in new shell sessions, add the following to your shell configuration file:"
echo ""
if command -v brew >/dev/null 2>&1 && brew_prefix="$(brew --prefix 2>/dev/null)"; then
    # Use the actual Homebrew prefix if available
    echo "# Homebrew configuration"
    echo "export PATH=\"$brew_prefix/bin:\$PATH\""
else
    # Fallback to both possible paths
    echo "# Homebrew configuration"
    echo "export PATH=\"/opt/homebrew/bin:/usr/local/bin:\$PATH\""
fi
echo ""
echo "Steps:"
echo "1. Open your shell configuration file in a text editor:"
echo "   - For zsh (default on macOS): ~/.zshrc"
echo "   - For bash: ~/.bashrc"
echo "   Example: nano ~/.zshrc"
echo "2. Append the lines above to the file."
echo "3. Save the file and reload your shell configuration:"
echo "   - For zsh: source ~/.zshrc"
echo "   - For bash: source ~/.bashrc"
echo "   Alternatively, close and reopen your terminal."
echo "4. Verify Homebrew is available by running: command -v brew"
