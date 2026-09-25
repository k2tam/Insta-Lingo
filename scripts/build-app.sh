#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_dir"
if [ "$(xcode-select -p)" = /Library/Developer/CommandLineTools ] &&
   [ -d /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk ]; then
    set -- --sdk /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk
else
    set --
fi
swift build "$@" -c release --product InstaLingo
bin_dir=$(swift build "$@" -c release --show-bin-path)
app_dir="$project_dir/build/Insta Lingo.app"
sh "$project_dir/scripts/package-app.sh" "$bin_dir/InstaLingo" "$app_dir"
echo "$app_dir"
