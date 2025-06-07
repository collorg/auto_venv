# auto_venv

Automatic Python virtual environment activation with multi-environment support based on .auto_venv files when changing directories.

## Overview

`auto_venv` is a lightweight bash script that automatically activates and deactivates Python virtual environments as you navigate between project directories. It uses `.auto_venv` configuration files to determine which virtual environment should be active in each directory tree. The script now supports multiple Python environments per project, allowing easy switching between different Python versions.

## Features

- **Automatic activation/deactivation** when changing directories
- **Multi-environment support** - manage multiple Python versions per project
- **Automatic format conversion** from old single-environment to new multi-environment format
- **Environment switching** - easily switch between different Python versions
- **Recursive search** for `.auto_venv` files up the directory tree
- **Multiple Python versions** support (Python 2.7 with virtualenv, Python 3+ with venv)
- **Flexible paths** (relative or absolute paths in .auto_venv files)
- **Simple setup** with a single bash script
- **Visual feedback** showing current environment status
- **Environment validation** to ensure virtual environments are properly configured

## Installation

1. Clone this repository:
```bash
git clone https://github.com/collorg/auto_venv.git
cd auto_venv
```

2. Source the script in your `.bashrc`:
```bash
echo "source $(pwd)/auto_venv.sh" >> ~/.bashrc
source ~/.bashrc
```

3. Optionally, set the Python search path (`/usr/bin` by default):
```bash
export AUTO_VENV_PYTHON_SEARCH_PATH="/opt/python/bin"  # your Python installation path
```
**IMPORTANT**: make sure you set the variable before the line  `source $(pwd)/auto_venv.sh` in
your `.bashrc` file.

## Usage

### Creating your first virtual environment

Navigate to your project directory and run:
```bash
auto_venv --new
```

This will:
1. Show available Python versions
2. Let you choose a Python version
3. Ask for the virtual environment path (default: `.venv_<python_version>`)
4. Create the virtual environment
5. Create a `.auto_venv` file with the environment path
6. Automatically activate the environment

### Adding additional environments

To add another Python version to your project:
```bash
auto_venv --add
```

This will show available Python versions (marking already configured ones with ✓) and let you add a new environment.

You can also specify a custom name:
```bash
auto_venv --add myenv
```

### Switching between environments

To switch to a different Python environment:
```bash
auto_venv --switch python3.11
```

### Listing available environments

To see all configured environments:
```bash
auto_venv --list
```

Output example:
```
[auto_venv] Available environments in /path/to/project:
  python3.9: .venv_python3_9 (default)
  python3.11: .venv_python3_11 (active)
  python3.12: .venv_python3_12
```

### Setting the default environment

To change which environment is activated by default:
```bash
auto_venv --set-default python3.11
```

### Validating environments

To check if the current environment is valid:
```bash
auto_venv --validate
```

### Automatic activation

Once a `.auto_venv` file exists in a directory (or any parent directory), the virtual environment will be automatically activated when you `cd` into that directory tree.

```bash
cd /path/to/my-project     # Automatically activates the default environment
cd /path/to/other-project  # Switches to the other project's environment
cd ~                       # Deactivates when leaving project directories
```

### Check current status

Run `auto_venv` without arguments to see the current environment status:
```bash
auto_venv
```

Output example:
```
[auto_venv] /path/to/my-project/.venv_python3_11 (python3.11) activated (Python 3.11.0)
[auto_venv] Multiple environments available. Use 'auto_venv --list' to see all.
[auto_venv] Use 'auto_venv --switch <name>' to change environment.
```

## Configuration

### .auto_venv file format

The `.auto_venv` file now supports multiple environments:

```
default:.venv_python3_9
python3.9:.venv_python3_9
python3.11:.venv_python3_11
python3.12:.venv_python3_12
```

- **default**: specifies which environment to activate by default
- **environment_name:path**: maps environment names to their paths

Old single-line format files are automatically converted to the new format when accessed.

### Python search path

Set the `AUTO_VENV_PYTHON_SEARCH_PATH` environment variable to specify where Python versions are located:

```bash
export AUTO_VENV_PYTHON_SEARCH_PATH="/usr/bin" # default
# or
export AUTO_VENV_PYTHON_SEARCH_PATH="/opt/python/bin"
```

## Examples

### Example 1: Simple project setup
```bash
cd ~/my-python-project
auto_venv --new
# Choose python3.9
# Creates .venv_python3_9 and .auto_venv
```

### Example 2: Multi-environment project
```bash
cd ~/my-python-project
auto_venv --new              # Create first environment (python3.9)
auto_venv --add              # Add python3.11
auto_venv --add              # Add python3.12
auto_venv --list             # See all environments
auto_venv --switch python3.11 # Switch to Python 3.11
auto_venv --set-default python3.11 # Make it the default
```

### Example 3: Testing compatibility
```bash
# Test your code with different Python versions
auto_venv --switch python3.9
python -m pytest

auto_venv --switch python3.11
python -m pytest

auto_venv --switch python3.12
python -m pytest
```

### Example 4: Shared virtual environment
```bash
cd ~/project-a
echo "default:/home/user/shared-env" > .auto_venv
echo "shared:/home/user/shared-env" >> .auto_venv

cd ~/project-b
echo "default:/home/user/shared-env" > .auto_venv
echo "shared:/home/user/shared-env" >> .auto_venv
# Both projects now share the same virtual environment
```

## Command Reference

- `auto_venv` - Show current environment status
- `auto_venv --new` - Create a new virtual environment (first environment)
- `auto_venv --add [name]` - Add a new environment with optional custom name
- `auto_venv --switch <name>` - Switch to a different environment
- `auto_venv --list` - List all available environments
- `auto_venv --set-default <name>` - Set the default environment
- `auto_venv --validate` - Validate the current environment
- `auto_venv --help` - Show help message

## How it works

1. When you change directories (`cd`), the script searches for a `.auto_venv` file in the current directory and all parent directories
2. If found, it parses the file to get available environments
3. It selects the appropriate environment (preferred, default, or first available)
4. If no virtual environment is currently active, it activates the selected environment
5. If a different environment should be active, it switches environments
6. If leaving a project directory tree, it deactivates the current environment

## Requirements

- Bash shell
- Python (2.7+ or 3.x)
- `virtualenv` (for Python 2.7) or `venv` (for Python 3+)

## Migration from Old Format

If you have existing `.auto_venv` files with the old single-line format, they will be automatically converted to the new multi-environment format when you first access them. The conversion preserves your existing environment and allows you to add more.

Old format:
```
./venv
```

Automatically converted to:
```
default:./venv
python:./venv
```

## Contributing

Contributions are welcome! Please feel free to submit issues, feature requests, or pull requests.

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

## Troubleshooting

### Virtual environment not activating
- Check that the path in `.auto_venv` is correct
- Run `auto_venv --validate` to check environment integrity
- Ensure the virtual environment exists and is valid
- Verify that `AUTO_VENV_PYTHON_SEARCH_PATH` is set correctly

### Python version not found
- List available versions: `ls $AUTO_VENV_PYTHON_SEARCH_PATH | grep -E '^python[23]\.?[0-9]*$'`
- Update `AUTO_VENV_PYTHON_SEARCH_PATH` to point to your Python installation directory

### Environment already configured
- Use `auto_venv --list` to see existing environments
- Use `auto_venv --switch <name>` to activate an existing environment
- Environment names must be unique within a project

### Script not working after installation
- Ensure you've sourced your `.bashrc`: `source ~/.bashrc`
- Check that the script path in `.bashrc` is correct
- Verify that the script has been loaded: `type auto_venv`
