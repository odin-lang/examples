# Odin js_wasm32 example

This is an example of how to build Odin for the `js_wasm32` target and call a function from the browser.

## Building

- The WASM file is already including in this example, but you can also built it again.

```bash
odin build . -target:js_wasm32 -out:web/index.wasm
```

- Note that the `odin.js` file in this example comes from the [core Odin library](https://github.com/odin-lang/Odin/blob/master/core/sys/wasm/js/odin.js). You need this file in your project in order to utilize the the WASM build correctly and easily.

## Running

You need to run a local webserver in the `web` directory in order to serve the site. There are few, simple options for this.

- Navigate to the `web` directory.

```bash
cd web
```

- Run a webserver.

```bash
# If you have Python installed.
python -m http.server
```

```bash
# If you have Node.js installed.
npx http-server -p 8000 .
```

- Visit [http://localhost:8000](http://localhost:8000)
