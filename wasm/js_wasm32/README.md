# Odin js_wasm32 example

This is an example of how to build an Odin program using the `js_wasm32` target. The example features a website that can call an Odin procedure.

## Building

Run `build.bat` (Windows) or `build.sh` (mac / Linux).

This builds the WASM module and also copies `odin.js` from the [core Odin library](https://github.com/odin-lang/Odin/blob/master/core/sys/wasm/js/odin.js) as it's required for a `js_wasm32` build.

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
