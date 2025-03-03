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

It will print:

```
Long_Cat is 9 x 46 pixels and 183 bytes large

Round_Cat is 20 x 24 pixels and 317 bytes large
Round_Cat has width > 15, so we loaded it!
The loaded PNG image is indeed 20 pixels wide!

Tuna is 24 x 20 pixels and 318 bytes large
Tuna has width > 15, so we loaded it!
The loaded PNG image is indeed 24 pixels wide!
```