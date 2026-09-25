#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_dir/Prototypes/nested-meaning"

echo "Nested meaning prototype: http://127.0.0.1:4174/?variant=A"
python3 -m http.server 4174 --bind 127.0.0.1
