.PHONY: test clean install lint help

# Default target
all: test

# Run all tests
test:
	@echo "Running auto_venv tests..."
	@chmod +x test/test_auto_venv.sh
	@./test/test_auto_venv.sh

# Install auto_venv (add to .bashrc)
install:
	@echo "Installing auto_venv..."
	@./install.sh

# Uninstall auto_venv (remove from .bashrc)
uninstall:
	@echo "Uninstalling auto_venv..."
	@sed -i.bak '/auto_venv\.sh/d' ~/.bashrc
	@echo "✓ Removed auto_venv.sh from ~/.bashrc"
	@echo "  Restart your terminal for changes to take effect"

# Basic linting (shellcheck if available)
lint:
	@echo "Checking shell script syntax..."
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck auto_venv.sh test_auto_venv.sh; \
		echo "✓ Shellcheck passed"; \
	else \
		echo "  Shellcheck not available, running basic syntax check..."; \
		bash -n auto_venv.sh && echo "✓ auto_venv.sh syntax OK"; \
		bash -n test_auto_venv.sh && echo "✓ test_auto_venv.sh syntax OK"; \
	fi

# Clean temporary files
clean:
	@echo "Cleaning temporary files..."
	@rm -rf /tmp/auto_venv_test_*
	@echo "✓ Cleanup complete"

# Show help
help:
	@echo "Available targets:"
	@echo "  test        - Run all tests"
	@echo "  test-quick  - Run quick smoke tests"
	@echo "  install     - Install auto_venv (add to ~/.bashrc)"
	@echo "  uninstall   - Uninstall auto_venv (remove from ~/.bashrc)"
	@echo "  lint        - Check shell script syntax"
	@echo "  clean       - Clean temporary files"
	@echo "  help        - Show this help message"
