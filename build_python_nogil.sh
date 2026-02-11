#!/bin/bash
set -e

VERSION="3.14.3"
INSTALL_DIR="$HOME/.local/python3.14-nogil"
TEMP_DIR=$(mktemp -d)

echo "Installing build dependencies..."
brew install openssl readline sqlite3 xz zlib tcl-tk

cd "$TEMP_DIR"
echo "Downloading Python $VERSION..."
curl -O "https://www.python.org/ftp/python/$VERSION/Python-$VERSION.tgz"
tar -xzf "Python-$VERSION.tgz"
cd "Python-$VERSION"

echo "Configuring Python with no-GIL..."
./configure \
  --prefix="$INSTALL_DIR" \
  --enable-optimizations \
  --with-lto \
  --disable-gil \
  CPPFLAGS="-I$(brew --prefix openssl)/include -I$(brew --prefix readline)/include" \
  LDFLAGS="-L$(brew --prefix openssl)/lib -L$(brew --prefix readline)/lib"

echo "Building Python (this will take 10-30 minutes)..."
make -j$(sysctl -n hw.ncpu)

echo "Installing Python..."
make altinstall

echo "Cleaning up..."
cd ~
rm -rf "$TEMP_DIR"

echo ""
echo "✅ Python 3.14.3 with no-GIL installed to: $INSTALL_DIR"
echo ""
echo "Add to PATH:"
echo "  echo 'export PATH=\"$INSTALL_DIR/bin:\$PATH\"' >> ~/.zshrc"
echo "  source ~/.zshrc"
echo ""
echo "Verify:"
echo "  python3.14 -c \"import sys; print('GIL disabled:', not sys._is_gil_enabled())\""
