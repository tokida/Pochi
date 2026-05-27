#!/bin/bash
# Pochi .mcpb パッケージビルドスクリプト
# Usage: ./build-mcpb.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

OUTPUT="pochi.mcpb"
MCPB_DIR="mcpb"
SERVER_DIR="$MCPB_DIR/server"

echo "=== Pochi .mcpb Builder ==="

# 1. Release build
echo "[1/4] Building release binary..."
swift build -c release

# 2. Locate built binary
BINARY="$(swift build -c release --show-bin-path)/Pochi"
if [ ! -f "$BINARY" ]; then
    echo "Error: Built binary not found at $BINARY"
    exit 1
fi
echo "  Binary: $BINARY"

# 3. Copy binary into mcpb/server/
echo "[2/4] Copying binary to $SERVER_DIR..."
mkdir -p "$SERVER_DIR"
cp "$BINARY" "$SERVER_DIR/Pochi"
chmod +x "$SERVER_DIR/Pochi"

# 4. Create .mcpb (ZIP archive)
echo "[3/4] Creating $OUTPUT..."
rm -f "$OUTPUT"
cd "$MCPB_DIR"
zip -r "../$OUTPUT" manifest.json server/
cd "$SCRIPT_DIR"

# 5. Cleanup
echo "[4/4] Cleaning up..."
rm -rf "$SERVER_DIR"

echo ""
echo "Done! Created $OUTPUT ($(du -h "$OUTPUT" | cut -f1))"
echo ""
echo "Install: Claude Desktop → Settings → Install Extension... → select $OUTPUT"
