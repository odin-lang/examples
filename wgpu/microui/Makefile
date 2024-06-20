FILES := $(wildcard *)

# NOTE: changing this requires changing the same values in the `web/index.html`.
INITIAL_MEMORY_PAGES := 2000
MAX_MEMORY_PAGES     := 65536

PAGE_SIZE := 65536
INITIAL_MEMORY_BYTES := $(shell expr $(INITIAL_MEMORY_PAGES) \* $(PAGE_SIZE))
MAX_MEMORY_BYTES     := $(shell expr $(MAX_MEMORY_PAGES) \* $(PAGE_SIZE))

WGPU_JS    := $(shell odin root)/vendor/wgpu/wgpu.js
RUNTIME_JS := $(shell odin root)/vendor/wasm/js/runtime.js

web/microui.wasm: $(FILES) $(WGPU_JS) $(RUNTIME_JS)
	odin build . \
		-target:js_wasm32 -out:web/microui.wasm -o:size \
        -extra-linker-flags:"--export-table --import-memory --initial-memory=$(INITIAL_MEMORY_BYTES) --max-memory=$(MAX_MEMORY_BYTES)"

	cp $(WGPU_JS) web/wgpu.js
	cp $(RUNTIME_JS) web/runtime.js
