#!/bin/bash
# Script to add Python 3.14 to PATH

PYTHON_PATH="$HOME/.local/python3.14-nogil/bin"

# Check if Python 3.14 is installed
if [ ! -f "$PYTHON_PATH/python3.14" ]; then
    echo "⚠️  Python 3.14 not found at $PYTHON_PATH"
    echo "   Please build Python 3.14 first using the build script."
    exit 1
fi

# Check if already in PATH
if grep -q "python3.14-nogil" ~/.zshrc 2>/dev/null; then
    echo "✅ Python 3.14 is already in your PATH"
    echo "   Current PATH entry:"
    grep "python3.14-nogil" ~/.zshrc
else
    # Add to PATH
    echo "" >> ~/.zshrc
    echo "# Python 3.14 with no-GIL" >> ~/.zshrc
    echo 'export PATH="$HOME/.local/python3.14-nogil/bin:$PATH"' >> ~/.zshrc
    echo "✅ Added Python 3.14 to PATH in ~/.zshrc"
    echo ""
    echo "To apply changes, run:"
    echo "  source ~/.zshrc"
    echo ""
    echo "Or open a new terminal window."
fi

