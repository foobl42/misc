#!/bin/bash
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

# Enable case-insensitive matching for prompts
shopt -s nocasematch

# Global variables to track package installation status
homebrew_install_status=2
gnupg_install_status=2

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
# Returns: 0 (newly installed), 1 (already installed), 2 (skipped by user)
_install_package() {
    local check_command="$1" package_name="$2" install_command="$3" post_install_action="$4" prereq_test="$5" prereq_error_message="$6" precheck_fix="$7"
    if command -v "$check_command" >/dev/null 2>&1; then
        echo "$package_name is already installed."
        return 1
    fi
    if [[ -n $precheck_fix ]]; then
        echo "$package_name not found in PATH, attempting pre-check fix..."
        eval "$precheck_fix"
        if command -v "$check_command" >/dev/null 2>&1; then
            echo "$package_name is already installed."
            return 1
        fi
    fi
    echo "$package_name not found."
    read -r -p "Do you want to install $package_name? (y/n): " answer
    case "$answer" in
        y*)
            if [[ -n $prereq_test ]] && ! eval "$prereq_test"; then
                _error_exit "$prereq_error_message"
            fi
            echo "Installing $package_name..."
            eval "$install_command" || _error_exit "Failed to install $package_name."
            echo "$package_name installed successfully."
            [[ -n $post_install_action ]] && eval "$post_install_action"
            _verify_command "$check_command" "$package_name"
            return 0
            ;;
        *)
            echo "$package_name installation skipped."
            return 2
            ;;
    esac
}

# Check if system is macOS (Darwin)
[[ $(uname) == Darwin ]] || _error_exit "This script requires macOS (Darwin)."

# Check if user is in admin group
id -G -n | grep -q ' admin ' || _error_exit "This script requires the user to be in the admin group."

# Install Homebrew
_install_package "brew" \
                 "Homebrew" \
                 "/bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"" \
                 "PATH=/opt/homebrew/bin:/usr/local/bin:\$PATH" \
                 "" \
                 "" \
                 "if [ -x /opt/homebrew/bin/brew ]; then PATH=/opt/homebrew/bin:\$PATH; elif [ -x /usr/local/bin/brew ]; then PATH=/usr/local/bin:\$PATH; fi"
homebrew_install_status=$?

# Install GnuPG
_install_package "gpg" \
                 "GnuPG" \
                 "brew install gnupg" \
                 "" \
                 "[[ \$homebrew_install_status == 0 || \$homebrew_install_status == 1 ]]" \
                 "GnuPG requires Homebrew to be installed." \
                 ""
gnupg_install_status=$?

# Provide manual steps for shell configuration if Homebrew was newly installed
if [[ $homebrew_install_status == 0 ]]; then
    brew_prefix=$(brew --prefix 2>/dev/null)
    brew_shellenv="eval \"\$(${brew_prefix}/bin/brew shellenv)\""
    config_file="your shell configuration file"
    if [[ $gnupg_install_status == 0 ]]; then
        echo "To make Homebrew and GnuPG available in future sessions, add the following to $config_file:"
    else
        echo "To make Homebrew available in future sessions, add the following to $config_file:"
    fi
    echo "  $brew_shellenv"
fi
exit 0
