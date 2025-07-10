# UDP Echo Server in Odin

This example demonstrates how to make an Echo Server in Odin using UDP protocol.
An Echo Server is a simple network server that sends back to the client whatever data it receives.
It is often used as a basic example to test networking functionality.

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
3. Type something in the client terminal

To terminate the client send an empty line pressing *Enter* (`\r\n`, `\n`).
