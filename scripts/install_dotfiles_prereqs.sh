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

# Private function to print an error message to stderr and exit the script
# Parameters:
#   $1 - message: the error message to display
# Returns:
#   None (exits the script with status 1)
_error_exit() {
  local message="$1"
  echo "Error: $message" >&2
  exit 1
}

# Private function to check if a command is available
# Parameters:
#   $1 - check_command: the command to check (e.g., "brew", "gpg")
#   $2 - package_name: the display name of the package (e.g., "Homebrew", "GnuPG")
# Returns:
#   0 - command is found
#   1 - command is not found
_check_command() {
  local check_command="$1" package_name="$2"
  if command -v "$check_command" >/dev/null 2>&1; then
    echo "$package_name is already installed."
    return 0  # Command found
  else
    return 1  # Command not found
  fi
}

# Private function to verify a command is available after installation
# Exits the script if the command is not found
# Parameters:
#   $1 - command_name: the command to verify (e.g., "brew", "gpg")
#   $2 - package_name: the display name of the package (e.g., "Homebrew", "GnuPG")
# Returns:
#   None (exits the script if the command is not found)
_verify_command() {
  local command_name="$1" package_name="$2"
  command -v "$command_name" >/dev/null 2>&1 || \
    _error_exit "$package_name installed, but $command_name command is not available."
}

# Private function to prompt the user for a yes/no response
# Parameters:
#   $1 - prompt: the question to ask the user
#   $2 - default: the default response ("y" for yes, "n" for no, "" for no default)
# Returns:
#   0 - user answered yes (or default is yes and Enter was pressed)
#   1 - user answered no (or default is no and Enter was pressed)
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
    y|yes) return 0 ;;
    n|no)  return 1 ;;
    "")
      if [[ $default == "y" ]]; then
        return 0
      elif [[ $default == "n" ]]; then
        return 1
      else
        echo "Invalid input; please enter 'y' or 'n'." >&2
        _prompt_yes_no "$prompt" "$default"
        return $?
      fi
      ;;
    *)
      echo "Invalid input; please enter 'y' or 'n'." >&2
      _prompt_yes_no "$prompt" "$default"
      return $?
      ;;
  esac
}

# Private function to install a package
# Parameters:
#   $1 - package_name: display name of the package (e.g., "Homebrew", "GnuPG")
#   $2 - check_command: command to check if package is installed (e.g., "brew", "gpg")
#   $3 - install_command: command to install the package
#   $4 - path_fix: space-separated list of directories to temporarily add to PATH for checking check_command
#   $5 - prereq_test: optional test to check prerequisites
#   $6 - prereq_error_message: message to display if prerequisites are not met
#   $7 - post_install_action: optional command to run after installation; must be a safe, valid command defined within this script
# Returns:
#   0 - newly installed
#   1 - already installed
#   2 - skipped (user choice or prerequisite failure)
_install_package() {
  local package_name="$1" check_command="$2" install_command="$3" \
        path_fix="$4" prereq_test="$5" prereq_error_message="$6" post_install_action="$7"
  local original_path="$PATH"

  # Check if the command is already in PATH
  if _check_command "$check_command" "$package_name"; then
    return 1  # Already installed
  fi

  # If path_fix is provided, temporarily add each directory to PATH and check for check_command
  if [[ -n $path_fix ]]; then
    PATH="$path_fix:$PATH"
    if _check_command "$check_command" "$package_name"; then
      PATH="$original_path"
      return 1  # Already installed after PATH fix
    fi
  fi

  # Check prerequisites if provided
  if [[ -n $prereq_test ]] && ! eval "$prereq_test"; then
    echo "$prereq_error_message" >&2
    PATH="$original_path"
    return 2
  fi

  # Prompt user to install the package with a default of 'y'
  echo "$package_name not found."
  if _prompt_yes_no "Do you want to install $package_name?" "y"; then
    echo "Installing $package_name..."
    eval "$install_command" || _error_exit "Failed to install $package_name."
    echo "$package_name installed successfully."
    [[ -n $post_install_action ]] && eval "$post_install_action"
    _verify_command "$check_command" "$package_name"
    PATH="$original_path"
    return 0
  else
    echo "$package_name installation skipped."
    PATH="$original_path"
    return 2
  fi
}

# Check if system is macOS (Darwin)
[[ $(uname) == Darwin ]] || _error_exit "This script requires macOS (Darwin)."

# Check if user is in admin group
id -G -n | grep -q ' admin ' || _error_exit "This script requires the user to be in the admin group."

# Install Homebrew
_install_package "Homebrew" "brew" \
  "/bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"" \
  "/opt/homebrew/bin /usr/local/bin" \
  "" \
  "" \
  "PATH=/opt/homebrew/bin:/usr/local/bin:\$PATH"
homebrew_install_status=$?

# Install GnuPG
_install_package "GnuPG" "gpg" "brew install gnupg" \
  "/opt/homebrew/bin /usr/local/bin" \
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

