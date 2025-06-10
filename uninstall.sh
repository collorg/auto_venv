# uninstall.sh

echo "Uninstalling auto_venv..."

# Function to remove lines from RC files
remove_from_rc() {
    local rc_file="$1"
    if [ -f "$rc_file" ]; then
        # Create backup
        cp "$rc_file" "$rc_file.auto_venv_backup"
        
        # Remove auto_venv lines
        grep -vi "auto_venv" "$rc_file" > "$rc_file.tmp"
        mv "$rc_file.tmp" "$rc_file"
        
        echo "✓ Cleaned $rc_file (backup: $rc_file.auto_venv_backup)"
    fi
}

# Clean all RC files
remove_from_rc "$HOME/.bashrc"
remove_from_rc "$HOME/.zshrc"
remove_from_rc "$HOME/.config/fish/config.fish"
remove_from_rc "$HOME/.profile"

echo ""
echo "auto_venv has been removed from shell configurations."
echo "Please restart your shell or source your RC file."
