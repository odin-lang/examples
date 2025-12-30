#!/usr/bin/env bash

set -euxo pipefail

# NOTE: changing this requires changing the same values in the `web/index.html`.
INITIAL_MEMORY_PAGES=2000
MAX_MEMORY_PAGES=65536

INITIAL_MEMORY_BYTES=$(expr $INITIAL_MEMORY_PAGES \* $MAX_MEMORY_PAGES)
MAX_MEMORY_BYTES=$(expr $MAX_MEMORY_PAGES \* $MAX_MEMORY_PAGES)

ODIN_ROOT=$(odin root)
ODIN_JS="$ODIN_ROOT/core/sys/wasm/js/odin.js"
WGPU_JS="$ODIN_ROOT/vendor/wgpu/wgpu.js"

odin build . -target:js_wasm32 -out:web/triangle.wasm -o:size \
	-extra-linker-flags:"--export-table --import-memory --initial-memory=$INITIAL_MEMORY_BYTES --max-memory=$MAX_MEMORY_BYTES"

cp $ODIN_JS web/odin.js
cp $WGPU_JS web/wgpu.js
