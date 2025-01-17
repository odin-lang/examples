# Odin Examples

Learn [Odin](https://github.com/odin-lang/Odin) through idiomatic examples that show you how to:
- Use the language
- Use `core` libraries
- Use `vendor` libraries

The examples are meant to be well written while following Odin best practices.

Also check out [demo.odin](https://github.com/odin-lang/Odin/blob/master/examples/demo/demo.odin) and the [overview](https://odin-lang.org/docs/overview/).

## Running the examples

Clone this repository. Most examples can be run by navigating into the folder and executing: `odin run .`

Some examples have a `README` with additional information and instructions.

## License
The contents of this repository is available under two licenses. Choose the one that you prefer:

- [Public Domain](https://unlicense.org)
or
- [Odin's BSD-3 license](https://github.com/odin-lang/Odin/blob/master/LICENSE)

Assets and third-party libraries are provided under their own license. If in doubt, check the `LICENSE*` and `COPYING*` file(s) in a particular directory for clarification.

## Example suggestions
Add example suggestions [here](https://github.com/odin-lang/examples/issues/73).

## Contributions
Contributions via Pull Requests are warmly welcome. Before submitting your Pull Request, make sure of the following:

- The example compiles with flags `-vet -strict-style -vet-tabs -disallow-do -warnings-as-errors`
- Add the example to `.github/workflows/check.yml`
- Your code follows the Odin naming convention: https://github.com/odin-lang/Odin/wiki/Naming-Convention (exception can be made for direct ports of examples that need to match 1:1 to the source of the port).
- Note that your code will fall under the licenses listed above. Only for third-party dependencies are other licenses allowed.
