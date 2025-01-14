# Echo Server in Odin

An Echo Server is a simple network server that sends back to the client whatever data it receives. It is often used as a basic example to test networking functionality.

## Requirements

- [Odin Compiler](https://odin-lang.org/download/) (latest stable version).
- A terminal or command prompt to run the application.

## Installation and Usage

1. Run the server:
    ```bash
    odin run server
    ```
2. Run one or more clients:
    ```bash
    odin run client
    ```
3. Or use `telnet`:
    ```bash
    telnet 127.0.0.1 8080
    ```

To terminate the client send `Ctrl-D` or `Ctrl-C` or an empty line pressing *Enter* (`\r\n`, `\n`).
