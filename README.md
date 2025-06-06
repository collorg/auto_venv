# auto_venv

Automatic Python virtual environment activation based on .auto_venv files when changing directories.

## Overview

`auto_venv` is a lightweight bash script that automatically activates and deactivates Python virtual environments as you navigate between project directories. It uses `.auto_venv` configuration files to determine which virtual environment should be active in each directory tree.

## Features

- **Automatic activation/deactivation** when changing directories
- **Recursive search** for `.auto_venv` files up the directory tree
- **Multiple Python versions** support (Python 2.7 with virtualenv, Python 3+ with venv)
- **Flexible paths** (relative or absolute paths in .auto_venv files)
- **Simple setup** with a single bash script
- **Visual feedback** showing current environment status

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
**IMPORTANT**: make sure you set the variable before the line  `source $(pwd)/auto_venv.sh` in
your `.bashrc` file.

## Usage

### Creating a new virtual environment

Navigate to your project directory and run:
```bash
auto_venv --new
```

This will:
1. Show available Python versions
2. Let you choose a Python version
3. Ask for the virtual environment path (default: current directory)
4. Create the virtual environment
5. Create a `.auto_venv` file with the environment path
6. Automatically activate the environment

### Automatic activation

Once a `.auto_venv` file exists in a directory (or any parent directory), the virtual environment will be automatically activated when you `cd` into that directory tree.

```bash
cd /path/to/my-project     # Automatically activates the virtual environment
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
[auto_venv] /path/to/my-project/venv activated (Python 3.9.2)
```

## Configuration

### .auto_venv file format

The `.auto_venv` file contains a single line with the path to your virtual environment:

```bash
# Relative path (relative to the .auto_venv file location)
./venv

# Absolute path
/home/user/my-project/venv
```

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
# Choose python3.9, use default path (.)
# Creates ./pyvenv.cfg and .auto_venv
```

### Example 2: Shared virtual environment
```bash
cd ~/project-a
echo "/home/user/shared-env" > .auto_venv
cd ~/project-b
echo "/home/user/shared-env" > .auto_venv
# Both projects now share the same virtual environment
```

## How it works

1. When you change directories (`cd`), the script searches for a `.auto_venv` file in the current directory and all parent directories
2. If found, it reads the virtual environment path from the file
3. If no virtual environment is currently active, it activates the found environment
4. If a different environment should be active, it switches environments
5. If leaving a project directory tree, it deactivates the current environment

## Requirements

- Bash shell
- Python (2.7+ or 3.x)
- `virtualenv` (for Python 2.7) or `venv` (for Python 3+)

## Contributing

Contributions are welcome! Please feel free to submit issues, feature requests, or pull requests.

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

## Troubleshooting

### Virtual environment not activating
- Check that the path in `.auto_venv` is correct
- Ensure the virtual environment exists and is valid
- Verify that `AUTO_VENV_PYTHON_SEARCH_PATH` is set correctly

### Python version not found
- List available versions: `ls $AUTO_VENV_PYTHON_SEARCH_PATH | grep -E '^python[23]\.?[0-9]*$'`
- Update `AUTO_VENV_PYTHON_SEARCH_PATH` to point to your Python installation directory

### Script not working after installation
- Ensure you've sourced your `.bashrc`: `source ~/.bashrc`
- Check that the script path in `.bashrc` is correct