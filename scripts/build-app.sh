#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_dir"
swift build -c release --product TransAtGlance
bin_dir=$(swift build -c release --show-bin-path)
app_dir="$project_dir/build/TransAtGlance.app"
mkdir -p "$app_dir/Contents/MacOS"
cp "$bin_dir/TransAtGlance" "$app_dir/Contents/MacOS/TransAtGlance"
cp "$project_dir/App/Info.plist" "$app_dir/Contents/Info.plist"
echo "$app_dir"
