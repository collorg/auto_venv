# auto_venv

<div align="center">

⚠️ **ALPHA VERSION** ⚠️

**This software is not yet stable. Expect bugs and breaking changes until v1.0**

[![Version](https://img.shields.io/badge/version-0.3.0--alpha-orange)](https://github.com/collorg/auto_venv)
[![Status](https://img.shields.io/badge/status-alpha-red)](https://github.com/collorg/auto_venv)
[![Tests](https://github.com/collorg/auto_venv/actions/workflows/ci.yml/badge.svg)](https://github.com/collorg/auto_venv)

</div>

Automatic Python virtual environment activation with multi-environment and multi-shell support based on .auto_venv files when changing directories.

## Overview

`auto_venv` is a lightweight shell tool that automatically activates and deactivates Python virtual environments as you navigate between project directories. It uses `.auto_venv` configuration files to determine which virtual environment should be active in each directory tree. The tool now supports multiple Python environments per project and works seamlessly across Bash, Zsh, and Fish shells.

## Features

- **Multi-shell support** - Works with Bash, Zsh, and Fish shells
- **Automatic activation/deactivation** when changing directories
- **Multi-environment support** - manage multiple Python versions per project
- **Environment switching** - easily switch between different Python versions
- **Recursive search** for `.auto_venv` files up the directory tree
- **Multiple Python versions** support (Python 2.7 with virtualenv, Python 3+ with venv)
- **Flexible paths** (relative or absolute paths in .auto_venv files)
- **Universal installation** - single install script for all shells
- **Visual feedback** showing current environment status
- **Environment validation** to ensure virtual environments are properly configured

## Compatibility

`auto_venv` is designed for Unix-type shells. It has been tested on Ubuntu and should work with any Linux distribution. For Windows users, it requires a Unix-like environment such as WSL (Windows Subsystem for Linux), Git Bash, Cygwin or MSYS2.

## Installation

### Automatic Installation (Recommended)

1. Clone this repository:
```bash
git clone https://github.com/collorg/auto_venv.git
cd auto_venv
```

2. Run the installation script:
```bash
./install.sh
```

The installation script will:
- Ask for your Python search path (default: `/usr/bin`)
- Detect all installed shells (Bash, Zsh, Fish)
- Add the Python search path to each shell's RC file
- Add the appropriate `source` command to each shell's RC file
- Configure the universal dispatcher for Bash and Zsh
- Set up direct sourcing for Fish

Example installation:
```
$ ./install.sh
Installing auto_venv...
Enter python search path [/usr/bin]: /opt/homebrew/bin
/opt/homebrew/bin
Detecting installed shells...
✓ Added auto_venv to /home/user/.bashrc (Bash)
✓ Added auto_venv to /home/user/.zshrc (Zsh)
✓ Added auto_venv to /home/user/.config/fish/config.fish (Fish)
✓ Added auto_venv to /home/user/.profile (POSIX sh)

Installation complete! auto_venv was added to 4 shell configuration(s).
Reload your shell or run 'source <rc_file>' to activate.
```

3. Reload your shell or start a new terminal session

### Manual Installation

For Bash or Zsh:
```bash
# Add Python search path (if different from /usr/bin)
echo "AUTO_VENV_PYTHON_SEARCH_PATH=/opt/python/bin" >> ~/.bashrc  # For Bash
echo "AUTO_VENV_PYTHON_SEARCH_PATH=/opt/python/bin" >> ~/.zshrc   # For Zsh

# Add source command
echo "source $(pwd)/auto_venv" >> ~/.bashrc   # For Bash
echo "source $(pwd)/auto_venv" >> ~/.zshrc    # For Zsh
```

For Fish:
```bash
# Add Python search path (if different from /usr/bin)
echo 'set AUTO_VENV_PYTHON_SEARCH_PATH "/opt/python/bin"' >> ~/.config/fish/config.fish

# Add source command
echo "source $(pwd)/auto_venv.fish" >> ~/.config/fish/config.fish
```

### Configuration

The Python search path is configured during installation. To change it later:

For Bash/Zsh:
```bash
export AUTO_VENV_PYTHON_SEARCH_PATH="/opt/python/bin"  # your Python installation path
```

For Fish:
```fish
set AUTO_VENV_PYTHON_SEARCH_PATH "/opt/python/bin"
```

**Note**: Make sure this variable is set before the `source` line in your RC file.

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

### Example 5: Working across different shells
```bash
# Setup in any shell
cd ~/my-project
auto_venv --new

# Works seamlessly when switching shells
bash    # Enters bash - environment activated automatically
zsh     # Switch to zsh - environment still active
fish    # Switch to fish - environment remains active
```

## Command Reference

- `auto_venv` - Show current environment status
- `auto_venv --new` - Create a new virtual environment
- `auto_venv --switch <name>` - Switch to a different environment
- `auto_venv --list` - List all available environments
- `auto_venv --set-default <name>` - Set the default environment
- `auto_venv --validate` - Validate the current environment
- `auto_venv --help` - Show help message

## File Structure

```
auto_venv/
├── README.md          # This file
├── auto_venv          # Universal dispatcher (detects shell and loads appropriate version)
├── auto_venv.sh       # Bash/POSIX implementation
├── auto_venv.zsh      # Zsh implementation (uses chpwd hook)
├── auto_venv.fish     # Fish implementation (uses PWD event)
├── install.sh         # Universal installation script
├── uninstall.sh       # uninstallation script
└── test
    └── test_auto_venv.sh  # Test suite for POSIX shells
```

## How it works

1. The universal dispatcher (`auto_venv`) automatically detects your shell and sources the appropriate implementation
2. When you change directories (`cd` in Bash, `chpwd` hook in Zsh, or PWD change in Fish), the script searches for a `.auto_venv` file in the current directory and all parent directories
3. If found, it parses the file to get available environments
4. It selects the appropriate environment (preferred, default, or first available)
5. If no virtual environment is currently active, it activates the selected environment
6. If a different environment should be active, it switches environments
7. If leaving a project directory tree, it deactivates the current environment

## Requirements

- **Supported shells**: Bash, Zsh, or Fish
- **Python**: 2.7+ or 3.x
- **Python packages**:
  - `virtualenv` (for Python 2.7)
  - `venv` module (built-in for Python 3.3+)

## Why auto_venv?

Unlike other virtual environment managers, auto_venv offers:

- **True multi-shell support**: Native implementations for Bash, Zsh, and Fish
- **Zero learning curve**: Just `cd` into your project
- **Multi-environment per project**: Test across Python versions easily  
- **No dependencies**: Pure shell implementation
- **Universal interface**: Same commands work across all shells

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

### Shell-specific issues

#### Script not working after installation
- Ensure you've reloaded your shell configuration:
  - Bash: `source ~/.bashrc`
  - Zsh: `source ~/.zshrc`
  - Fish: `source ~/.config/fish/config.fish`
- Verify that the script has been loaded: `type auto_venv`

#### Fish shell errors
- Fish requires direct sourcing of `auto_venv.fish`, not the universal dispatcher
- Make sure your `config.fish` contains: `source /path/to/auto_venv.fish`

#### Zsh command not found
- Ensure the auto_venv directory is in a stable location
- Check that the path in `.zshrc` is absolute, not relative

#### Performance issues
- In Zsh, the `chpwd` hook is called on every directory change
- In Fish, the PWD watcher runs on every directory change
- Consider disabling in directories with heavy I/O if needed

## Development Process

This project was developed using AI-assisted programming. 
See [DEVELOPMENT.md](DEVELOPMENT.md) for details on the development process
and how AI tools were used to accelerate development while maintaining
code quality and human oversight.

## Project Status

**Current version: 0.3.0-alpha**

This project is under active development. Until we reach v1.0:

- ❌ **Not production-ready**
- ⚠️ **API may change** 
- 🐛 **Bugs are expected**
- 📝 **Documentation may be incomplete**

### Roadmap to v1.0

- [ ] Fix all known bugs in multi-shell support
- [ ] Complete test coverage for all shells
- [ ] Stabilize API and configuration format
- [ ] Add comprehensive error handling
- [ ] Performance optimization
- [ ] Full documentation

### How to Help

1. **Test it** and report bugs
2. **Contribute** fixes and improvements
3. **Share feedback** on the API design
4. **Star the repo** if you find it useful

Estimated v1.0 release: When it's ready™
