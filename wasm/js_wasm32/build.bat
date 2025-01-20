@echo off

for /f "delims=" %%i in ('odin.exe root') do set "ODIN_PATH=%%i"
copy "%ODIN_PATH%\core\sys\wasm\js\odin.js" "web\odin.js"

call odin.exe build . -target:js_wasm32 -out:web\index.wasm
