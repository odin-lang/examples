/*
This example shows a simple UDP server that echos back anything it receives.

You can run this with the netcat utility as the client like so: `nc -u 127.0.0.1 1234`.
*/
package main

import "core:fmt"
import "core:nbio"

main :: proc() {
	if err := nbio.acquire_thread_event_loop(); err != nil {
		fmt.eprintln("acquire_thread_event_loop: %v", nbio.error_string(err))
		return
	}
	defer nbio.release_thread_event_loop()

	socket, create_err := nbio.create_socket(.IP4, .UDP)
	if create_err != nil {
		fmt.eprintfln("create_socket: %v", nbio.error_string(create_err))
		return
	}

	if err := nbio.bind(socket, {nbio.IP4_Loopback, 1234}); err != nil {
		fmt.eprintfln("bind to 127.0.0.1:1234: %v", nbio.error_string(err))
		return
	}

	BUF_LEN :: 1024
	buf := make([]byte, BUF_LEN)
	defer delete(buf)

	nbio.recv(socket, {buf}, on_recv)

	on_recv :: proc(op: ^nbio.Operation) {
		if op.recv.err != nil {
			fmt.eprintfln("recv: %v", nbio.error_string_recv(op.recv.err))
			return
		}

		fmt.eprintfln("received %M from %v", op.recv.received, nbio.endpoint_to_string(op.recv.source))

		nbio.send(op.recv.socket, {op.recv.bufs[0][:op.recv.received]}, on_sent, op.recv.source)
	}

	on_sent :: proc(op: ^nbio.Operation) {
		if op.send.err != nil {
			fmt.eprintfln("send: %v", nbio.error_string_send(op.send.err))
			return
		}

		fmt.eprintfln("sent %M to %v", op.send.sent, nbio.endpoint_to_string(op.send.endpoint))

		nbio.recv(op.send.socket, {raw_data(op.send.bufs[0])[:BUF_LEN]}, on_recv)
	}

	if err := nbio.run(); err != nil {
		fmt.eprintfln("run: %v", nbio.error_string(err))
	}
}
