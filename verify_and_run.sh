#!/bin/bash

# Ensure the virtual environment is activated
if [ -f "venv/bin/activate" ]; then
    source venv/bin/activate
    echo "Virtual environment activated."
else
    echo "Error: Virtual environment not found or activation script missing."
    exit 1
fi

# Install packages if not already installed
if ! command -v mdformat &> /dev/null; then
    pip install mdformat mdformat-myst pymarkdownlnt emoji
    echo "Installed packages."
fi

# Run mdlint check
python3 /home/nator/.cline/skills/mdlint/scripts/mdlint.py check .
execute_verify_and_run