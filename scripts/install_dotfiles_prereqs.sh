#!/bin/bash
#
# install_dotfiles_prereqs.sh
#

# Enable case-insensitive matching for prompts
shopt -s nocasematch

# Global vars to track package install status
homebrew_install_status=2
gnupg_install_status=2

# Print error to stderr and exit
# $1 - message: error text to show
# Returns: exits with status 1
_error_exit() {
  local message="$1"
  echo "Error: $message" >&2
  exit 1
}

# Check if a command is available
# $1 - check_command: cmd to test
# $2 - package_name: display name
# Returns: 0 if found, 1 if not
_check_command() {
  local check_command="$1" package_name="$2"
  if command -v "$check_command" >/dev/null 2>&1; then
    echo "$package_name is already installed."
    return 0  # Command found
  else
    return 1  # Command not found
  fi
}

# Verify cmd exists post-install
# $1 - command_name: cmd to check
# $2 - package_name: display name
# Returns: exits if not found
_verify_command() {
  local command_name="$1" package_name="$2"
  command -v "$command_name" >/dev/null 2>&1 || _error_exit "$package_name installed, but $command_name command is not available."
}

# Prompt user for yes/no answer
# $1 - prompt: question to ask
# $2 - default: 'y', 'n', or ''
# Returns: 0 for yes, 1 for no
_prompt_yes_no() {
  local prompt="$1" default="$2"
  local display_default
  if [[ $default == "y" ]]; then
    display_default="[y]"
  elif [[ $default == "n" ]]; then
    display_default="[n]"
  else
    display_default="[]"
  fi
  read -r -p "$prompt (y/n): $display_default " answer
  case "$answer" in
    y|yes)
      return 0  # User said yes
      ;;
    n|no)
      return 1  # User said no
      ;;
    "")
      if [[ $default == "y" ]]; then
        return 0  # Default yes
      elif [[ $default == "n" ]]; then
        return 1  # Default no
      else
        echo "Invalid input; enter 'y' or 'n'." >&2
        _prompt_yes_no "$prompt" "$default"
        return $?
      fi
      ;;
    *)
      echo "Invalid input; enter 'y' or 'n'." >&2
      _prompt_yes_no "$prompt" "$default"
      return $?
      ;;
  esac
}

# Define prerequisite check for GnuPG
# Returns: 0 if prereq met, 1 if not
_check_homebrew_prereq() {
  if [[ $homebrew_install_status == 0 || $homebrew_install_status == 1 ]]; then
    return 0  # Homebrew is installed
  else
    return 1  # Homebrew not installed
  fi
}

# Install a package
# $1 - package_name: display name
# $2 - check_command: cmd to check
# $3 - install_command: install cmd
# $4 - prereq_func: name of prereq check function (or empty)
# $5 - prereq_error_message: error text
# $6 - additional_paths: PATH dirs
# Returns: 0 new, 1 exists, 2 skip
_install_package() {
  local package_name="$1" check_command="$2" install_command="$3" prereq_func="$4" prereq_error_message="$5" additional_paths="$6"
  local original_path="$PATH"

  # Add extra paths to PATH if given
  if [[ -n $additional_paths ]]; then
    # Convert space-separated to colon-separated
    local colon_paths="${additional_paths// /:}"
    PATH="$colon_paths:$PATH"
  fi

  # Check if cmd is in PATH
  if _check_command "$check_command" "$package_name"; then
    PATH="$original_path"
    return 1  # Already installed
  fi

  # Check prereqs if provided
  if [[ -n $prereq_func ]]; then
    if ! type "$prereq_func" >/dev/null 2>&1; then
      _error_exit "Prerequisite function $prereq_func not found for $package_name."
    fi
    if ! "$prereq_func"; then
      echo "$prereq_error_message" >&2
      PATH="$original_path"
      return 2  # Skipped: prereq fail
    fi
  fi

  # Prompt to install, default 'y'
  echo "$package_name not found."
  if _prompt_yes_no "Do you want to install $package_name?" "y"; then
    echo "Installing $package_name..."
    eval "$install_command" || _error_exit "Failed to install $package_name."
    echo "$package_name installed successfully."
    _verify_command "$check_command" "$package_name"
    PATH="$original_path"
    return 0  # Newly installed
  else
    echo "$package_name installation skipped."
    PATH="$original_path"
    return 2  # Skipped by user
  fi
}

# Check for macOS (Darwin)
[[ $(uname) == Darwin ]] || _error_exit "This script requires macOS (Darwin)."

# Check if user is in admin group
id -G -n | grep -q ' admin ' || _error_exit "This script requires the user to be in the admin group."

# Check for internet connectivity
if ! ping -c 1 -W 2 google.com >/dev/null 2>&1; then
  _error_exit "No internet connection detected; required for package installs."
fi

# Install Homebrew
_install_package "Homebrew" "brew" "/bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"" "" "" "/opt/homebrew/bin /usr/local/bin"
homebrew_install_status=$?

# Update PATH for Homebrew if newly installed
if [[ $homebrew_install_status == 0 ]]; then
  if [ -x "/opt/homebrew/bin/brew" ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x "/usr/local/bin/brew" ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  else
    echo "Warning: brew command found, but shellenv setup failed." >&2
  fi
fi

# Set brew_prefix for subsequent package installs
brew_prefix=$(brew --prefix 2>/dev/null || echo "/opt/homebrew")

# Install GnuPG
_install_package "GnuPG" "gpg" "brew install gnupg" "_check_homebrew_prereq" "GnuPG requires Homebrew to be installed." "$brew_prefix/bin"
gnupg_install_status=$?

# Manual steps if Homebrew new
if [[ $homebrew_install_status == 0 ]]; then
  brew_prefix=$(brew --prefix 2>/dev/null)
  brew_shellenv="eval \"\$(${brew_prefix}/bin/brew shellenv)\""
  config_file="your shell configuration file (e.g., ~/.bash_profile, ~/.zshrc)"
  if [[ $gnupg_install_status == 0 ]]; then
    echo "To make Homebrew and GnuPG available in future sessions, add the following to $config_file:"
  else
    echo "To make Homebrew available in future sessions, add the following to $config_file:"
  fi
  echo "  $brew_shellenv"
fi
exit 0  # Exit successfully
