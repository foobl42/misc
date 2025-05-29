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

#!/bin/bash

# Enable case-insensitive matching for prompts
shopt -s nocasematch

# Private function to print error to stderr and exit
_error_exit() {
    local message="$1"
    echo "Error: $message" >&2
    exit 1
}

# Private function to verify a command is available
_verify_command() {
    local command_name="$1" package_name="$2"
    command -v "$command_name" >/dev/null 2>&1 || _error_exit "$package_name installed, but $command_name command is not available."
}

# Private function to install a package
_install_package() {
    local check_command="$1" package_name="$2" install_command="$3" post_install_action="$4" prereq_test="$5" prereq_error_message="$6"
    if command -v "$check_command" >/dev/null 2>&1; then
        echo "$package_name is already installed."
    else
        if [[ -n $prereq_test ]] && ! eval "$prereq_test"; then
            echo "$prereq_error_message"
        else
            echo "$package_name not found."
            read -r -p "Do you want to install $package_name? (y/n): " answer
            case "$answer" in
                y*)
                    echo "Installing $package_name..."
                    eval "$install_command" || _error_exit "Failed to install $package_name."
                    echo "$package_name installed successfully."
                    [[ -n $post_install_action ]] && eval "$post_install_action"
                    _verify_command "$check_command" "$package_name"
                    ;;
                *)
                    echo "$package_name installation skipped. Proceeding to next steps."
                    ;;
            esac
        fi
    fi
}

# Check if system is macOS (Darwin)
[[ $(uname) == Darwin ]] || _error_exit "This script requires macOS (Darwin)."

# Check if user is in admin group
id -G -n | grep -q ' admin ' || _error_exit "This script requires the user to be in the admin group."

# Prompt user to cache sudo credentials
echo "This script requires sudo access. You may be prompted for your password."
sudo -v || _error_exit "Failed to obtain sudo access. Please ensure you have sudo privileges."

# Install Homebrew
_install_package "brew" "Homebrew" "/bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"" "PATH=/opt/homebrew/bin:/usr/local/bin:\$PATH" "" ""

# Install GnuPG
_install_package "gpg" "GnuPG" "brew install gnupg" "" "command -v brew >/dev/null 2>&1" "GnuPG requires Homebrew to be installed."

# Provide manual steps for shell configuration
if command -v brew >/dev/null 2>&1 && brew_prefix=$(brew --prefix 2>/dev/null); then
    brew_shellenv="eval \"\$(${brew_prefix}/bin/brew shellenv)\""
else
    brew_shellenv="eval \"\$(/opt/homebrew/bin/brew shellenv)\""
fi
config_file="your shell configuration file"
echo "To make Homebrew and GnuPG available in future sessions, add the following to $config_file:"
echo "  $brew_shellenv"
exit 0
