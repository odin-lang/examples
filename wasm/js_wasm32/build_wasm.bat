for /f "delims=" %%i in ('odin.exe root') do set "ODIN_ROOT=%%i"
copy "%ODIN_ROOT%\core\sys\wasm\js\odin.js" "web\odin.js"

call odin.exe build . -target:js_wasm32 -out:web\index.wasm
