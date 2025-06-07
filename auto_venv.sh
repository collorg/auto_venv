#!/bin/bash
# Script auto_venv.sh with multi-environment support

if [[ -z $AUTO_VENV_PYTHON_SEARCH_PATH ]] ; then
  export AUTO_VENV_PYTHON_SEARCH_PATH="/usr/bin"
fi

# Variable to store the preferred active environment
export AUTO_VENV_PREFERRED=""

__parse_auto_venv_file() {
  # Parse the .auto_venv file and return available environments
  local file_path="$1"
  
  # Reset variables
  unset AUTO_VENV_ENVIRONMENTS
  declare -gA AUTO_VENV_ENVIRONMENTS
  AUTO_VENV_DEFAULT=""
  
  if [[ ! -f "$file_path" ]]; then
    return 1
  fi
  
  # Check if it's the old format (single line)
  local line_count
  local first_line
  line_count=$(wc -l < "$file_path")
  first_line=$(head -n1 "$file_path" | tr -d '\n\r' | xargs)
  
  if [[ $line_count -eq 1 && ! "$first_line" =~ : ]]; then
    # Old format - convert it to new format
    echo "[auto_venv] Converting old format .auto_venv file to multi-environment format"
    
    # Create new format file
    local temp_file
    temp_file=$(mktemp)
    echo "default:$first_line" > "$temp_file"
    echo "python:$first_line" >> "$temp_file"
    
    # Replace old file with new format
    mv "$temp_file" "$file_path"
    
    # Parse the newly formatted file
    AUTO_VENV_DEFAULT="$first_line"
    AUTO_VENV_ENVIRONMENTS["python"]="$first_line"
    return 0
  fi
  
  # New multi-environment format
  while IFS=: read -r key value; do
    # Clean whitespace
    key=$(echo "$key" | xargs)
    value=$(echo "$value" | xargs)
    
    if [[ -z "$key" || -z "$value" ]]; then
      continue
    fi
    
    if [[ "$key" == "default" ]]; then
      AUTO_VENV_DEFAULT="$value"
    else
      AUTO_VENV_ENVIRONMENTS["$key"]="$value"
    fi
  done < "$file_path"
  
  # If no default specified, take the first one
  if [[ -z "$AUTO_VENV_DEFAULT" && ${#AUTO_VENV_ENVIRONMENTS[@]} -gt 0 ]]; then
    AUTO_VENV_DEFAULT="${AUTO_VENV_ENVIRONMENTS[${!AUTO_VENV_ENVIRONMENTS[@]}]}"
  fi
  
  return 0
}

__select_environment() {
  # Select the environment to activate
  local preferred="$1"
  
  # If a preferred environment is specified
  if [[ -n "$preferred" ]]; then
    if [[ -n "${AUTO_VENV_ENVIRONMENTS[$preferred]}" ]]; then
      AUTO_VENV_PATH="${AUTO_VENV_ENVIRONMENTS[$preferred]}"
      AUTO_VENV_SELECTED="$preferred"
    else
      # Preferred environment doesn't exist
      return 1
    fi
  # No preference specified, use the default
  elif [[ -n "$AUTO_VENV_DEFAULT" ]]; then
    AUTO_VENV_PATH="$AUTO_VENV_DEFAULT"
    AUTO_VENV_SELECTED="default"
  else
    return 1
  fi
  
  # Build full path
  if [[ "$AUTO_VENV_PATH" != /* ]] ; then
    AUTO_VENV="$AUTO_VENV_BASE_DIR/$AUTO_VENV_PATH"
  else
    AUTO_VENV="$AUTO_VENV_PATH"
  fi
  
  return 0
}

__validate_venv() {
  # Function to validate that a virtual environment is valid and functional
  local venv_path="$1"
  
  # Check that the directory exists
  if [[ ! -d "$venv_path" ]]; then
    return 1
  fi
  
  # Check that the activate script exists
  if [[ ! -f "$venv_path/bin/activate" ]]; then
    return 1
  fi
  
  # Check that the Python executable exists in the environment
  if [[ ! -x "$venv_path/bin/python" ]]; then
    return 1
  fi
  
  # Check that pyvenv.cfg exists (for Python 3+ venv)
  # or that it's a valid Python 2.7 virtualenv
  if [[ ! -f "$venv_path/pyvenv.cfg" ]]; then
    # Could be a Python 2.7 virtualenv, check the structure
    # Use a loop to handle the glob properly
    local has_python_lib=false
    for _ in "$venv_path"/lib/python*; do
      has_python_lib=true
      break
    done
    
    if [[ ! -f "$venv_path/lib/python2.7/site.py" && "$has_python_lib" == false ]]; then
      return 1
    fi
  fi
  
  return 0
}

__validate_python_version() {
  # Function to validate that a Python version exists and is executable
  local python_version="$1"
  local python_path="$AUTO_VENV_PYTHON_SEARCH_PATH/$python_version"
  
  # Check that the file exists and is executable
  if [[ ! -x "$python_path" ]]; then
    return 1
  fi
  
  # Check that it's really a Python executable
  if ! "$python_path" --version &>/dev/null; then
    return 1
  fi
  
  return 0
}

__find_auto_venv_file() {
  # Function to find the .auto_venv conf file from the current directory up to the root.
  # Triggers __auto_venv_deactivate if no .auto_venv is found.

  local current_dir="$PWD"
  while [ "$current_dir" != "/" ]; do
    local file_path="$current_dir/.auto_venv"
    if [ -f "$file_path" ]; then
      AUTO_VENV_BASE_DIR=$current_dir
      
      # Parse the file to get environments
      if ! __parse_auto_venv_file "$file_path"; then
        echo "[auto_venv] Error: Failed to parse .auto_venv file in $current_dir" >&2
        return 1
      fi
      
      # Select the appropriate environment
      if ! __select_environment "$AUTO_VENV_PREFERRED"; then
        echo "[auto_venv] Error: No valid environment found in $file_path" >&2
        return 1
      fi
      
      # Validate the virtual environment
      if ! __validate_venv "$AUTO_VENV"; then
        echo "[auto_venv] Error: Invalid virtual environment at $AUTO_VENV" >&2
        echo "[auto_venv] Environment: $AUTO_VENV_SELECTED" >&2
        echo "[auto_venv] Found in: $file_path" >&2
        echo "[auto_venv] Suggestion: Run 'auto_venv --add $AUTO_VENV_SELECTED' to recreate" >&2
        # Clean variables and stop search
        unset AUTO_VENV
        unset AUTO_VENV_BASE_DIR
        unset AUTO_VENV_PATH
        unset AUTO_VENV_ENVIRONMENTS
        unset AUTO_VENV_DEFAULT
        unset AUTO_VENV_SELECTED
        return 1
      fi
      
      return 0
    fi
    current_dir=$(dirname "$current_dir")
  done
  # No .auto_venv file found in the directory tree
  __auto_venv_deactivate
  return 0
}

function __auto_venv_show() {
  if [[ -n "$AUTO_VENV" ]] ; then
    echo -n "[auto_venv] $AUTO_VENV"
    if [[ -n "$AUTO_VENV_SELECTED" && "$AUTO_VENV_SELECTED" != "default" ]]; then
      echo -n " ($AUTO_VENV_SELECTED)"
    fi
    if [[ -n "$VIRTUAL_ENV" ]] ; then
      echo " activated ($(python --version 2>&1))"
    else
      echo " found but not activated"
    fi
  fi
}

function __auto_venv_activate() {
  if [ -n "$AUTO_VENV" ] ; then
    # Double check before activation
    if __validate_venv "$AUTO_VENV"; then
      # shellcheck disable=SC1091
      source "$AUTO_VENV/bin/activate"
      if [[ "$OLD_AUTO_VENV_BASE_DIR" != "$AUTO_VENV_BASE_DIR" || -z "$OLD_AUTO_VENV_BASE_DIR" ]] ; then
        __auto_venv_show
      fi
    else
      echo "[auto_venv] Error: Cannot activate invalid environment $AUTO_VENV" >&2
      unset AUTO_VENV
    fi
  fi
}

function __auto_venv_deactivate() {
  # Deactivate virtual environment if active
  if [[ -n "$VIRTUAL_ENV" ]]; then
    deactivate
  fi
  
  unset AUTO_VENV
  unset AUTO_VENV_BASE_DIR
  unset AUTO_VENV_PATH
  unset AUTO_VENV_ENVIRONMENTS
  unset AUTO_VENV_DEFAULT
  unset AUTO_VENV_SELECTED
  unset OLD_AUTO_VENV_BASE_DIR
}

function cd() {
  builtin cd "$@" || return
  OLD_AUTO_VENV_BASE_DIR=$AUTO_VENV_BASE_DIR
  unset AUTO_VENV
  
  # Look for .auto_venv file and validate the environment
  __find_auto_venv_file
  
  # If we found a valid environment and it's different from the previous one
  if [[ -n "$AUTO_VENV" && "$AUTO_VENV_BASE_DIR" != "$OLD_AUTO_VENV_BASE_DIR" ]]; then
    __auto_venv_activate
  fi
}

function auto_venv() {
  if [[ "$1" == "--new" || "$1" == "--add" ]] ; then
    local env_name=""
    if [[ "$1" == "--add" && -n "$2" ]]; then
      env_name="$2"
    fi
    
    # Load existing environments if we're in --add
    if [[ "$1" == "--add" ]]; then
      # Try to find existing .auto_venv file
      if __find_auto_venv_file; then
        echo "[auto_venv] Found existing environments in $AUTO_VENV_BASE_DIR/.auto_venv"
      fi
    fi
    
    echo "Available Python versions:"
    
    # List and validate available Python versions
    local available_pythons=()
    for python_exec in "$AUTO_VENV_PYTHON_SEARCH_PATH"/python*; do
      if [[ -x "$python_exec" && "$python_exec" =~ python[23](\.[0-9]+)?$ ]]; then
        local version_name
        version_name=$(basename "$python_exec")
        if __validate_python_version "$version_name"; then
          available_pythons+=("$version_name")
          
          # Check if this version is already configured
          local status_marker=""
          if [[ "$1" == "--add" && -n "${AUTO_VENV_ENVIRONMENTS[$version_name]}" ]]; then
            status_marker=" ✓ (already set)"
          fi
          
          echo "  - $version_name ($("$python_exec" --version 2>&1))$status_marker"
        fi
      fi
    done
    
    if [[ ${#available_pythons[@]} -eq 0 ]]; then
      echo "[auto_venv] Error: No valid Python versions found in $AUTO_VENV_PYTHON_SEARCH_PATH" >&2
      return 1
    fi
    
    VENV_MODULE="venv"
    read -r -p "Python version to use? " PYTHON_VERSION
    
    # If no environment name specified, use Python version
    if [[ -z "$env_name" ]]; then
      env_name="$PYTHON_VERSION"
    fi
    
    # Check if this environment is already configured
    if [[ "$1" == "--add" && -n "${AUTO_VENV_ENVIRONMENTS[$PYTHON_VERSION]}" ]]; then
      echo "[auto_venv] Error: Environment '$PYTHON_VERSION' is already configured" >&2
      echo "[auto_venv] Path: ${AUTO_VENV_ENVIRONMENTS[$PYTHON_VERSION]}" >&2
      echo "[auto_venv] Use 'auto_venv --switch $PYTHON_VERSION' to activate it" >&2
      return 1
    fi
    
    # Enhanced Python version validation
    if [[ ! "${available_pythons[*]}" =~ ${PYTHON_VERSION} ]]; then
      echo "[auto_venv] Error: '$PYTHON_VERSION' is not available. Please choose from: ${available_pythons[*]}" >&2
      return 1
    fi
    
    if ! __validate_python_version "$PYTHON_VERSION"; then
      echo "[auto_venv] Error: Invalid Python version '$PYTHON_VERSION'" >&2
      return 1
    fi
    
    if [[ "$PYTHON_VERSION" == "python2.7" ]] ; then
      VENV_MODULE="virtualenv"
      # Check that virtualenv is available
      if ! command -v virtualenv &> /dev/null; then
        echo "[auto_venv] Error: virtualenv is required for Python 2.7 but not found" >&2
        echo "[auto_venv] Install with: pip install virtualenv" >&2
        return 1
      fi
    fi
    
    read -r -p "Virtual environment path [.venv_${env_name//[.\/]/_}]: " VENV_PATH
    if [ -z "$VENV_PATH" ] ; then
      VENV_PATH=".venv_${env_name//[.\/]/_}"
    fi
    
    # Check if directory already exists
    if [[ -d "$VENV_PATH" && -n "$(ls -A "$VENV_PATH" 2>/dev/null)" ]]; then
      echo "[auto_venv] Warning: Directory '$VENV_PATH' already exists and is not empty"
      read -r -p "Continue anyway? [y/N]: " confirm
      if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "[auto_venv] Cancelled"
        return 1
      fi
    fi
    
    echo "[auto_venv] Creating virtual environment with $PYTHON_VERSION..."
    if "$AUTO_VENV_PYTHON_SEARCH_PATH/$PYTHON_VERSION" -m "$VENV_MODULE" "$VENV_PATH"; then
      echo "[auto_venv] Virtual environment created successfully"
      
      # Update .auto_venv file
      local auto_venv_file="$PWD/.auto_venv"
      local is_first_env=true
      
      if [[ -f "$auto_venv_file" ]]; then
        # File already exists, not the first environment
        is_first_env=false
      fi
      
      # Add new environment
      echo "$env_name:$VENV_PATH" >> "$auto_venv_file"
      
      # If it's the first one, set it as default
      if [[ "$is_first_env" == true ]]; then
        echo "default:$VENV_PATH" >> "$auto_venv_file"
      fi
      
      echo "[auto_venv] Updated .auto_venv file"
      
      # Activate new environment
      AUTO_VENV_PREFERRED="$env_name"
      __find_auto_venv_file
      __auto_venv_activate
    else
      echo "[auto_venv] Error: Failed to create virtual environment" >&2
      return 1
    fi
    
  elif [[ "$1" == "--switch" ]]; then
    if [[ -z "$2" ]]; then
      echo "[auto_venv] Error: Please specify environment name" >&2
      echo "[auto_venv] Usage: auto_venv --switch <environment>" >&2
      return 1
    fi
    
    # Look for .auto_venv file
    if ! __find_auto_venv_file; then
      echo "[auto_venv] Error: No .auto_venv file found" >&2
      return 1
    fi
    
    # Set preferred environment and reload
    AUTO_VENV_PREFERRED="$2"
    
    # Deactivate current environment if necessary
    if [[ -n "$VIRTUAL_ENV" ]]; then
      deactivate
    fi
    
    # Reload with new environment
    if __find_auto_venv_file && __auto_venv_activate; then
      echo "[auto_venv] Switched to environment: $AUTO_VENV_PREFERRED"
    else
      echo "[auto_venv] Error: Failed to switch to environment '$2'" >&2
      echo "[auto_venv] Run 'auto_venv --list' to see available environments" >&2
      return 1
    fi
    
  elif [[ "$1" == "--list" ]]; then
    if ! __find_auto_venv_file; then
      echo "[auto_venv] No .auto_venv file found in current directory tree"
      return 1
    fi
    
    echo "[auto_venv] Available environments in $AUTO_VENV_BASE_DIR:"
    for env in "${!AUTO_VENV_ENVIRONMENTS[@]}"; do
      local marker=""
      if [[ "$env" == "$AUTO_VENV_SELECTED" ]]; then
        marker=" (active)"
      elif [[ "${AUTO_VENV_ENVIRONMENTS[$env]}" == "$AUTO_VENV_DEFAULT" ]]; then
        marker=" (default)"
      fi
      
      local path="${AUTO_VENV_ENVIRONMENTS[$env]}"
      local full_path="$path"
      if [[ "$path" != /* ]]; then
        full_path="$AUTO_VENV_BASE_DIR/$path"
      fi
      
      if __validate_venv "$full_path"; then
        echo "  $env: $path$marker"
      else
        echo "  $env: $path [INVALID]$marker"
      fi
    done
    
  elif [[ "$1" == "--set-default" ]]; then
    if [[ -z "$2" ]]; then
      echo "[auto_venv] Error: Please specify environment name" >&2
      echo "[auto_venv] Usage: auto_venv --set-default <environment>" >&2
      return 1
    fi
    
    if ! __find_auto_venv_file; then
      echo "[auto_venv] Error: No .auto_venv file found" >&2
      return 1
    fi
    
    local env_to_default="$2"
    if [[ -z "${AUTO_VENV_ENVIRONMENTS[$env_to_default]}" ]]; then
      echo "[auto_venv] Error: Environment '$env_to_default' not found" >&2
      return 1
    fi
    
    # Rewrite file with new default
    local auto_venv_file="$AUTO_VENV_BASE_DIR/.auto_venv"
    local temp_file
    temp_file=$(mktemp)
    
    echo "default:${AUTO_VENV_ENVIRONMENTS[$env_to_default]}" > "$temp_file"
    for env in "${!AUTO_VENV_ENVIRONMENTS[@]}"; do
      echo "$env:${AUTO_VENV_ENVIRONMENTS[$env]}" >> "$temp_file"
    done
    
    mv "$temp_file" "$auto_venv_file"
    echo "[auto_venv] Set default environment to: $env_to_default"
    
  elif [[ "$1" == "--validate" ]]; then
    # New option to validate current environment
    if [[ -z "$AUTO_VENV" ]]; then
      echo "[auto_venv] No environment found in current directory tree"
      return 1
    fi
    
    echo "[auto_venv] Validating environment: $AUTO_VENV"
    if __validate_venv "$AUTO_VENV"; then
      echo "[auto_venv] ✓ Environment is valid"
      if [[ -f "$AUTO_VENV/pyvenv.cfg" ]]; then
        echo "[auto_venv] Python version: $(grep "version = " "$AUTO_VENV/pyvenv.cfg" | cut -d' ' -f3)"
      fi
      
      # Show all available environments
      if [[ ${#AUTO_VENV_ENVIRONMENTS[@]} -gt 1 ]]; then
        echo "[auto_venv] Multiple environments available. Use 'auto_venv --list' to see all."
      fi
      return 0
    else
      echo "[auto_venv] ✗ Environment is invalid or corrupted"
      return 1
    fi
    
  elif [[ "$1" == "--help" ]]; then
    echo "Usage: auto_venv [OPTION]"
    echo ""
    echo "Options:"
    echo "  (no option)     Show current environment status"
    echo "  --new           Create a new virtual environment (converts to multi-env format)"
    echo "  --add <name>    Add a new environment with specific name"
    echo "  --switch <name> Switch to a different environment"
    echo "  --list          List all available environments"
    echo "  --set-default   Set the default environment"
    echo "  --validate      Validate the current environment"
    echo "  --help          Show this help message"
    echo ""
    echo "Multi-environment .auto_venv format:"
    echo "  default:./venv"
    echo "  python3.9:./venv39"
    echo "  python3.10:./venv310"
    
  else
    __auto_venv_show
    if [ -z "$AUTO_VENV" ]; then
      echo "[auto_venv] No auto_venv found in current directory tree."
    fi
    if [[ "$AUTO_VENV_BASE_DIR" != "$PWD" ]]; then
      echo "[auto_venv] Use 'auto_venv --new' to create a new auto_venv in $PWD."
    fi
    
    # Show available environments if there are multiple
    if [[ ${#AUTO_VENV_ENVIRONMENTS[@]} -gt 1 ]]; then
      echo "[auto_venv] Multiple environments available. Use 'auto_venv --list' to see all."
      echo "[auto_venv] Use 'auto_venv --switch <name>' to change environment."
    fi
  fi
}