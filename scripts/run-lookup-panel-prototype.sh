#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_dir/Prototypes/lookup-panel"

echo "Lookup panel prototype: http://127.0.0.1:4173/?variant=A"
python3 -m http.server 4173 --bind 127.0.0.1
