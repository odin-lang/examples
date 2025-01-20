#!/bin/bash

odin_js=$(odin root)/core/sys/wasm/js/odin.js
cp "$odin_js" web/odin.js

odin build . -target:js_wasm32 -out:web/index.wasm
