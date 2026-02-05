#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$SCRIPT_DIR/build-app.sh"
exec "$SCRIPT_DIR/../.build/Connor.app/Contents/MacOS/Connor"
