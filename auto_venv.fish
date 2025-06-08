# auto_venv.fish - Fish version with multi-environment support

if not set -q AUTO_VENV_PYTHON_SEARCH_PATH
    set -gx AUTO_VENV_PYTHON_SEARCH_PATH "/usr/bin"
end

# Variable to store the preferred active environment
set -gx AUTO_VENV_PREFERRED ""

# Fish doesn't have associative arrays, so we use two lists
set -g AUTO_VENV_ENV_NAMES
set -g AUTO_VENV_ENV_PATHS

function __parse_auto_venv_file
    # Parse the .auto_venv file and return available environments
    set -l file_path $argv[1]
    
    # Reset variables
    set -e AUTO_VENV_ENV_NAMES
    set -e AUTO_VENV_ENV_PATHS
    set -g AUTO_VENV_DEFAULT ""
    
    if not test -f "$file_path"
        return 1
    end
    
    # Check if it's the old format (single line)
    set -l line_count (wc -l < "$file_path" | tr -d ' ')
    set -l first_line (head -n1 "$file_path" | tr -d '\n\r' | string trim)
    
    if test $line_count -eq 1; and not string match -q "*:*" "$first_line"
        # Old format - convert it to new format
        echo "[auto_venv] Converting old format .auto_venv file to multi-environment format"
        
        # Create new format file
        set -l temp_file (mktemp)
        echo "default:$first_line" > "$temp_file"
        echo "python:$first_line" >> "$temp_file"
        
        # Replace old file with new format
        mv "$temp_file" "$file_path"
        
        # Parse the newly formatted file
        set -g AUTO_VENV_DEFAULT "$first_line"
        set -a AUTO_VENV_ENV_NAMES "python"
        set -a AUTO_VENV_ENV_PATHS "$first_line"
        return 0
    end
    
    # New multi-environment format
    for line in (cat "$file_path")
        set -l parts (string split ":" "$line")
        if test (count $parts) -eq 2
            set -l key (string trim $parts[1])
            set -l value (string trim $parts[2])
            
            if test -n "$key" -a -n "$value"
                if test "$key" = "default"
                    set -g AUTO_VENV_DEFAULT "$value"
                else
                    set -a AUTO_VENV_ENV_NAMES "$key"
                    set -a AUTO_VENV_ENV_PATHS "$value"
                end
            end
        end
    end
    
    # If no default specified, take the first one
    if test -z "$AUTO_VENV_DEFAULT" -a (count $AUTO_VENV_ENV_PATHS) -gt 0
        set -g AUTO_VENV_DEFAULT $AUTO_VENV_ENV_PATHS[1]
    end
    
    return 0
end

function __get_env_path
    # Get environment path by name
    set -l env_name $argv[1]
    set -l idx 1
    for name in $AUTO_VENV_ENV_NAMES
        if test "$name" = "$env_name"
            echo $AUTO_VENV_ENV_PATHS[$idx]
            return 0
        end
        set idx (math $idx + 1)
    end
    return 1
end

function __select_environment
    # Select the environment to activate
    set -l preferred $argv[1]
    
    # If a preferred environment is specified
    if test -n "$preferred"
        set -l env_path (__get_env_path "$preferred")
        if test -n "$env_path"
            set -g AUTO_VENV_PATH "$env_path"
            set -g AUTO_VENV_SELECTED "$preferred"
        else
            # Preferred environment doesn't exist
            return 1
        end
    # No preference specified, use the default
    else if test -n "$AUTO_VENV_DEFAULT"
        set -g AUTO_VENV_PATH "$AUTO_VENV_DEFAULT"
        set -g AUTO_VENV_SELECTED "default"
    else
        return 1
    end
    
    # Build full path
    if not string match -q "/*" "$AUTO_VENV_PATH"
        set -g AUTO_VENV "$AUTO_VENV_BASE_DIR/$AUTO_VENV_PATH"
    else
        set -g AUTO_VENV "$AUTO_VENV_PATH"
    end
    
    return 0
end

function __validate_venv
    # Function to validate that a virtual environment is valid and functional
    set -l venv_path $argv[1]
    
    # Check that the directory exists
    if not test -d "$venv_path"
        return 1
    end
    
    # Check that the activate script exists
    if not test -f "$venv_path/bin/activate.fish"
        return 1
    end
    
    # Check that the Python executable exists in the environment
    if not test -x "$venv_path/bin/python"
        return 1
    end
    
    # Check that pyvenv.cfg exists (for Python 3+ venv)
    # or that it's a valid Python 2.7 virtualenv
    if not test -f "$venv_path/pyvenv.cfg"
        # Could be a Python 2.7 virtualenv, check the structure
        set -l has_python_lib false
        for dir in "$venv_path"/lib/python*
            if test -d "$dir"
                set has_python_lib true
                break
            end
        end
        
        if not test -f "$venv_path/lib/python2.7/site.py" -a "$has_python_lib" = "false"
            return 1
        end
    end
    
    return 0
end

function __validate_python_version
    # Function to validate that a Python version exists and is executable
    set -l python_version $argv[1]
    set -l python_path "$AUTO_VENV_PYTHON_SEARCH_PATH/$python_version"
    
    # Check that the file exists and is executable
    if not test -x "$python_path"
        return 1
    end
    
    # Check that it's really a Python executable
    if not "$python_path" --version >/dev/null 2>&1
        return 1
    end
    
    return 0
end

function __find_auto_venv_file
    # Function to find the .auto_venv conf file from the current directory up to the root.
    # Triggers __auto_venv_deactivate if no .auto_venv is found.
    
    set -l current_dir "$PWD"
    while test "$current_dir" != "/"
        set -l file_path "$current_dir/.auto_venv"
        if test -f "$file_path"
            set -g AUTO_VENV_BASE_DIR $current_dir
            
            # Parse the file to get environments
            if not __parse_auto_venv_file "$file_path"
                echo "[auto_venv] Error: Failed to parse .auto_venv file in $current_dir" >&2
                return 1
            end
            
            # Select the appropriate environment
            if not __select_environment "$AUTO_VENV_PREFERRED"
                echo "[auto_venv] Error: No valid environment found in $file_path" >&2
                return 1
            end
            
            # Validate the virtual environment
            if not __validate_venv "$AUTO_VENV"
                echo "[auto_venv] Error: Invalid virtual environment at $AUTO_VENV" >&2
                echo "[auto_venv] Environment: $AUTO_VENV_SELECTED" >&2
                echo "[auto_venv] Found in: $file_path" >&2
                echo "[auto_venv] Suggestion: Run 'auto_venv --add $AUTO_VENV_SELECTED' to recreate" >&2
                # Clean variables and stop search
                set -e AUTO_VENV
                set -e AUTO_VENV_BASE_DIR
                set -e AUTO_VENV_PATH
                set -e AUTO_VENV_ENV_NAMES
                set -e AUTO_VENV_ENV_PATHS
                set -e AUTO_VENV_DEFAULT
                set -e AUTO_VENV_SELECTED
                return 1
            end
            
            return 0
        end
        set current_dir (dirname "$current_dir")
    end
    # No .auto_venv file found in the directory tree
    __auto_venv_deactivate
    return 0
end

function __auto_venv_show
    if test -n "$AUTO_VENV"
        echo -n "[auto_venv] $AUTO_VENV"
        if test -n "$AUTO_VENV_SELECTED" -a "$AUTO_VENV_SELECTED" != "default"
            echo -n " ($AUTO_VENV_SELECTED)"
        end
        if test -n "$VIRTUAL_ENV"
            echo " activated ("(python --version 2>&1)")"
        else
            echo " found but not activated"
        end
    end
end

function __auto_venv_activate
    if test -n "$AUTO_VENV"
        # Double check before activation
        if __validate_venv "$AUTO_VENV"
            source "$AUTO_VENV/bin/activate.fish"
            if test "$OLD_AUTO_VENV_BASE_DIR" != "$AUTO_VENV_BASE_DIR" -o -z "$OLD_AUTO_VENV_BASE_DIR"
                __auto_venv_show
            end
        else
            echo "[auto_venv] Error: Cannot activate invalid environment $AUTO_VENV" >&2
            set -e AUTO_VENV
        end
    end
end

function __auto_venv_deactivate
    # Deactivate virtual environment if active
    if test -n "$VIRTUAL_ENV"
        deactivate
    end
    
    set -e AUTO_VENV
    set -e AUTO_VENV_BASE_DIR
    set -e AUTO_VENV_PATH
    set -e AUTO_VENV_ENV_NAMES
    set -e AUTO_VENV_ENV_PATHS
    set -e AUTO_VENV_DEFAULT
    set -e AUTO_VENV_SELECTED
    set -e OLD_AUTO_VENV_BASE_DIR
end

# Hook for directory changes in Fish
function __auto_venv_on_pwd --on-variable PWD
    set -g OLD_AUTO_VENV_BASE_DIR $AUTO_VENV_BASE_DIR
    set -e AUTO_VENV
    
    # Look for .auto_venv file and validate the environment
    __find_auto_venv_file
    
    # If we found a valid environment and it's different from the previous one
    if test -n "$AUTO_VENV" -a "$AUTO_VENV_BASE_DIR" != "$OLD_AUTO_VENV_BASE_DIR"
        __auto_venv_activate
    end
end

function auto_venv
    set -l cmd $argv[1]
    
    if test "$cmd" = "--new" -o "$cmd" = "--add"
        set -l env_name ""
        if test "$cmd" = "--add" -a (count $argv) -ge 2
            set env_name $argv[2]
        end
        
        # Load existing environments if we're in --add
        if test "$cmd" = "--add"
            # Try to find existing .auto_venv file
            if __find_auto_venv_file
                echo "[auto_venv] Found existing environments in $AUTO_VENV_BASE_DIR/.auto_venv"
            end
        end
        
        echo "Available Python versions:"
        
        # List and validate available Python versions
        set -l available_pythons
        for python_exec in "$AUTO_VENV_PYTHON_SEARCH_PATH"/python*
            if test -x "$python_exec"; and string match -qr 'python[23](\.[0-9]+)?$' "$python_exec"
                set -l version_name (basename "$python_exec")
                if __validate_python_version "$version_name"
                    set -a available_pythons "$version_name"
                    
                    # Check if this version is already configured
                    set -l status_marker ""
                    if test "$cmd" = "--add"
                        if contains "$version_name" $AUTO_VENV_ENV_NAMES
                            set status_marker " ✓ (already set)"
                        end
                    end
                    
                    echo "  - $version_name ("("$python_exec" --version 2>&1)")$status_marker"
                end
            end
        end
        
        if test (count $available_pythons) -eq 0
            echo "[auto_venv] Error: No valid Python versions found in $AUTO_VENV_PYTHON_SEARCH_PATH" >&2
            return 1
        end
        
        set -l VENV_MODULE "venv"
        read -P "Python version to use? " PYTHON_VERSION
        
        # If no environment name specified, use Python version
        if test -z "$env_name"
            set env_name "$PYTHON_VERSION"
        end
        
        # Check if this environment is already configured
        if test "$cmd" = "--add"
            if contains "$PYTHON_VERSION" $AUTO_VENV_ENV_NAMES
                echo "[auto_venv] Error: Environment '$PYTHON_VERSION' is already configured" >&2
                set -l idx (contains -i "$PYTHON_VERSION" $AUTO_VENV_ENV_NAMES)
                echo "[auto_venv] Path: $AUTO_VENV_ENV_PATHS[$idx]" >&2
                echo "[auto_venv] Use 'auto_venv --switch $PYTHON_VERSION' to activate it" >&2
                return 1
            end
        end
        
        # Enhanced Python version validation
        if not contains "$PYTHON_VERSION" $available_pythons
            echo "[auto_venv] Error: '$PYTHON_VERSION' is not available. Please choose from: $available_pythons" >&2
            return 1
        end
        
        if not __validate_python_version "$PYTHON_VERSION"
            echo "[auto_venv] Error: Invalid Python version '$PYTHON_VERSION'" >&2
            return 1
        end
        
        if test "$PYTHON_VERSION" = "python2.7"
            set VENV_MODULE "virtualenv"
            # Check that virtualenv is available
            if not command -v virtualenv >/dev/null 2>&1
                echo "[auto_venv] Error: virtualenv is required for Python 2.7 but not found" >&2
                echo "[auto_venv] Install with: pip install virtualenv" >&2
                return 1
            end
        end
        
        set -l default_path ".venv_"(string replace -a "." "_" (string replace -a "/" "_" "$env_name"))
        read -P "Virtual environment path [$default_path]: " VENV_PATH
        if test -z "$VENV_PATH"
            set VENV_PATH "$default_path"
        end
        
        # Check if directory already exists
        if test -d "$VENV_PATH" -a -n (ls -A "$VENV_PATH" 2>/dev/null)
            echo "[auto_venv] Warning: Directory '$VENV_PATH' already exists and is not empty"
            read -P "Continue anyway? [y/N]: " confirm
            if not string match -qr '^[Yy]$' "$confirm"
                echo "[auto_venv] Cancelled"
                return 1
            end
        end
        
        echo "[auto_venv] Creating virtual environment with $PYTHON_VERSION..."
        if "$AUTO_VENV_PYTHON_SEARCH_PATH/$PYTHON_VERSION" -m "$VENV_MODULE" "$VENV_PATH"
            echo "[auto_venv] Virtual environment created successfully"
            
            # Update .auto_venv file
            set -l auto_venv_file "$PWD/.auto_venv"
            set -l is_first_env true
            
            if test -f "$auto_venv_file"
                # File already exists, not the first environment
                set is_first_env false
            end
            
            # Add new environment
            echo "$env_name:$VENV_PATH" >> "$auto_venv_file"
            
            # If it's the first one, set it as default
            if test "$is_first_env" = "true"
                echo "default:$VENV_PATH" >> "$auto_venv_file"
            end
            
            echo "[auto_venv] Updated .auto_venv file"
            
            # Activate new environment
            set -gx AUTO_VENV_PREFERRED "$env_name"
            __find_auto_venv_file
            __auto_venv_activate
        else
            echo "[auto_venv] Error: Failed to create virtual environment" >&2
            return 1
        end
        
    else if test "$cmd" = "--switch"
        if test (count $argv) -lt 2
            echo "[auto_venv] Error: Please specify environment name" >&2
            echo "[auto_venv] Usage: auto_venv --switch <environment>" >&2
            return 1
        end
        
        # Look for .auto_venv file
        if not __find_auto_venv_file
            echo "[auto_venv] Error: No .auto_venv file found" >&2
            return 1
        end
        
        # Set preferred environment and reload
        set -gx AUTO_VENV_PREFERRED $argv[2]
        
        # Deactivate current environment if necessary
        if test -n "$VIRTUAL_ENV"
            deactivate
        end
        
        # Reload with new environment
        if __find_auto_venv_file; and __auto_venv_activate
            echo "[auto_venv] Switched to environment: $AUTO_VENV_PREFERRED"
        else
            echo "[auto_venv] Error: Failed to switch to environment '$argv[2]'" >&2
            echo "[auto_venv] Run 'auto_venv --list' to see available environments" >&2
            return 1
        end
        
    else if test "$cmd" = "--list"
        if not __find_auto_venv_file
            echo "[auto_venv] No .auto_venv file found in current directory tree"
            return 1
        end
        
        echo "[auto_venv] Available environments in $AUTO_VENV_BASE_DIR:"
        set -l idx 1
        for env in $AUTO_VENV_ENV_NAMES
            set -l marker ""
            if test "$env" = "$AUTO_VENV_SELECTED"
                set marker " (active)"
            else if test "$AUTO_VENV_ENV_PATHS[$idx]" = "$AUTO_VENV_DEFAULT"
                set marker " (default)"
            end
            
            set -l path $AUTO_VENV_ENV_PATHS[$idx]
            set -l full_path "$path"
            if not string match -q "/*" "$path"
                set full_path "$AUTO_VENV_BASE_DIR/$path"
            end
            
            if __validate_venv "$full_path"
                echo "  $env: $path$marker"
            else
                echo "  $env: $path [INVALID]$marker"
            end
            set idx (math $idx + 1)
        end
        
    else if test "$cmd" = "--set-default"
        if test (count $argv) -lt 2
            echo "[auto_venv] Error: Please specify environment name" >&2
            echo "[auto_venv] Usage: auto_venv --set-default <environment>" >&2
            return 1
        end
        
        if not __find_auto_venv_file
            echo "[auto_venv] Error: No .auto_venv file found" >&2
            return 1
        end
        
        set -l env_to_default $argv[2]
        set -l env_path (__get_env_path "$env_to_default")
        if test -z "$env_path"
            echo "[auto_venv] Error: Environment '$env_to_default' not found" >&2
            return 1
        end
        
        # Rewrite file with new default
        set -l auto_venv_file "$AUTO_VENV_BASE_DIR/.auto_venv"
        set -l temp_file (mktemp)
        
        echo "default:$env_path" > "$temp_file"
        set -l idx 1
        for env in $AUTO_VENV_ENV_NAMES
            echo "$env:$AUTO_VENV_ENV_PATHS[$idx]" >> "$temp_file"
            set idx (math $idx + 1)
        end
        
        mv "$temp_file" "$auto_venv_file"
        echo "[auto_venv] Set default environment to: $env_to_default"
        
    else if test "$cmd" = "--validate"
        # New option to validate current environment
        if test -z "$AUTO_VENV"
            echo "[auto_venv] No environment found in current directory tree"
            return 1
        end
        
        echo "[auto_venv] Validating environment: $AUTO_VENV"
        if __validate_venv "$AUTO_VENV"
            echo "[auto_venv] ✓ Environment is valid"
            if test -f "$AUTO_VENV/pyvenv.cfg"
                echo "[auto_venv] Python version: "(grep "version = " "$AUTO_VENV/pyvenv.cfg" | cut -d' ' -f3)
            end
            
            # Show all available environments
            if test (count $AUTO_VENV_ENV_NAMES) -gt 1
                echo "[auto_venv] Multiple environments available. Use 'auto_venv --list' to see all."
            end
            return 0
        else
            echo "[auto_venv] ✗ Environment is invalid or corrupted"
            return 1
        end
        
    else if test "$cmd" = "--help"
        echo "Usage: auto_venv [OPTION]"
        echo ""
        echo "Options:"
        echo "  (no option)     Show current environment status"
        echo "  --new           Create a new virtual environment (converts to multi-env format)"
        echo "  --add <n>    Add a new environment with specific name"
        echo "  --switch <n> Switch to a different environment"
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
        if test -z "$AUTO_VENV"
            echo "[auto_venv] No auto_venv found in current directory tree."
        end
        if test "$AUTO_VENV_BASE_DIR" != "$PWD"
            echo "[auto_venv] Use 'auto_venv --new' to create a new auto_venv in $PWD."
        end
        
        # Show available environments if there are multiple
        if test (count $AUTO_VENV_ENV_NAMES) -gt 1
            echo "[auto_venv] Multiple environments available. Use 'auto_venv --list' to see all."
            echo "[auto_venv] Use 'auto_venv --switch <n>' to change environment."
        end
    end
end

# Run auto_venv check on initial load
__find_auto_venv_file
if test -n "$AUTO_VENV"
    __auto_venv_activate
end
