#!/bin/sh
set -eu

binary=${1:?Usage: package-app.sh BINARY_PATH APP_PATH}
app=${2:?Usage: package-app.sh BINARY_PATH APP_PATH}
project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

if [ ! -f "$binary" ]; then
    echo "Packaging failed: executable not found: $binary" >&2
    exit 1
fi

mkdir -p "$app/Contents/MacOS"
cp "$binary" "$app/Contents/MacOS/InstaLingo"
cp "$project_dir/App/Info.plist" "$app/Contents/Info.plist"
sh "$project_dir/scripts/sign-product.sh" "$app"

