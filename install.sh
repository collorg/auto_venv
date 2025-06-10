#!/bin/sh
# install.sh

echo "Installing auto_venv..."

INSTALL_DIR=$(pwd)
INSTALLED=0

# Fonction pour ajouter auto_venv à un fichier RC
add_to_rc() {
    local rc_file="$1"
    local shell_name="$2"
    local source_file="${3:-auto_venv}"  # Par défaut, source auto_venv

    if [ -f "$rc_file" ]; then
        if ! grep -q "auto_venv" "$rc_file"; then
            if [ "$shell_name" = 'Fish' ]; then
                echo "set AUTO_VENV_PYTHON_SEARCH_PATH \"$AUTO_VENV_PYTHON_SEARCH_PATH\"" >> "$rc_file"
            else
                echo "AUTO_VENV_PYTHON_SEARCH_PATH=$AUTO_VENV_PYTHON_SEARCH_PATH" >> "$rc_file"
            fi
            echo "source $INSTALL_DIR/$source_file" >> "$rc_file"
            echo "✓ Added auto_venv to $rc_file ($shell_name)"
            INSTALLED=$((INSTALLED + 1))
        else
            echo "✓ auto_venv already in $rc_file ($shell_name)"
        fi
    elif [ -n "$2" ]; then
        # Le fichier RC n'existe pas mais on sait que le shell est présent
        echo "  Note: $rc_file doesn't exist. Create it if you use $shell_name."
    fi
}

if [ -z "$AUTO_VENV_PYTHON_SEARCH_PATH" ]; then
    read -p "Enter python search path [/usr/bin]: " AUTO_VENV_PYTHON_SEARCH_PATH
    AUTO_VENV_PYTHON_SEARCH_PATH=${AUTO_VENV_PYTHON_SEARCH_PATH:-/usr/bin}
    echo $AUTO_VENV_PYTHON_SEARCH_PATH
fi

echo "Detecting installed shells..."

# Bash
if command -v bash >/dev/null 2>&1; then
    add_to_rc "$HOME/.bashrc" "Bash"
fi

# Zsh
if command -v zsh >/dev/null 2>&1; then
    add_to_rc "$HOME/.zshrc" "Zsh"
fi

# Fish
if command -v fish >/dev/null 2>&1; then
    mkdir -p "$HOME/.config/fish"
    # Fish a besoin de sourcer directement auto_venv.fish
    add_to_rc "$HOME/.config/fish/config.fish" "Fish" "auto_venv.fish"
fi

# POSIX sh (toujours présent)
add_to_rc "$HOME/.profile" "POSIX sh"

# Résumé
echo ""
if [ $INSTALLED -gt 0 ]; then
    echo "Installation complete! auto_venv was added to $INSTALLED shell configuration(s)."
    echo "Reload your shell or run 'source <rc_file>' to activate."
else
    echo "auto_venv is already installed in all detected shells."
fi
