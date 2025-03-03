This shows some basic code generation / meta programming.

The code generation is done by running a separate program that generates some Odin code.

Generate `images.odin` by running:

```
odin run generate_image_info
```

The following will build the program that actually uses `images.odin`:

```
odin run .
```
