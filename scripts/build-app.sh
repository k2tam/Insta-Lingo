#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
if ! xcodebuild -version >/dev/null 2>&1; then
    echo "Building the app requires full Xcode. Select it with xcode-select or set DEVELOPER_DIR." >&2
    exit 1
fi

set --
if [ -n "${CODE_SIGN_IDENTITY:-}" ]; then
    set -- "CODE_SIGN_IDENTITY=$CODE_SIGN_IDENTITY"
fi
xcodebuild -project "$project_dir/InstaLingo.xcodeproj" \
    -scheme InstaLingo -configuration Release -destination 'platform=macOS' \
    -derivedDataPath "$project_dir/build/DerivedData" \
    "CONFIGURATION_BUILD_DIR=$project_dir/build" "$@" build

echo "$project_dir/build/Insta Lingo.app"
