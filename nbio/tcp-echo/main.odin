/*
This example shows a simple TCP server that echos back anything it receives.

Better error handling and closing/freeing connections are left for the reader.

You can run this with the netcat utility as the client like so: `nc 127.0.0.1 1234`.
*/
package main

import "core:container/xar"
import "core:fmt"
import "core:nbio"

Server :: struct {
	socket:      nbio.TCP_Socket,
	// Xar is used in favor of `[dynamic]Connection` so pointers are stable.
	connections: xar.Array(Connection, 4),
}

Connection :: struct {
	server: ^Server,
	sock:   nbio.TCP_Socket,
	buf:    [50]byte,
}

main :: proc() {
	err := nbio.acquire_thread_event_loop()
	fmt.assertf(err == nil, "Could not initialize nbio: %v", err)
	defer nbio.release_thread_event_loop()

	server: Server

	socket, listen_err := nbio.listen_tcp({nbio.IP4_Any, 1234})
	fmt.assertf(listen_err == nil, "Error listening on localhost:1234: %v", err)
	server.socket = socket

	nbio.accept_poly(socket, &server, on_accept)

	rerr := nbio.run()
	fmt.assertf(rerr == nil, "Server stopped with error: %v", rerr)
}

on_accept :: proc(op: ^nbio.Operation, server: ^Server) {
	fmt.assertf(op.accept.err == nil, "Error accepting a connection: %v", op.accept.err)

	// Register a new accept for the next client.
	nbio.accept_poly(server.socket, server, on_accept)

	connection, alloc_err := xar.push_back_elem_and_get_ptr(&server.connections, Connection{
		server = server,
		sock   = op.accept.client,
	})
	assert(alloc_err == nil)

	nbio.recv_poly(op.accept.client, {connection.buf[:]}, connection, on_recv)
}

on_recv :: proc(op: ^nbio.Operation, connection: ^Connection) {
	fmt.assertf(op.recv.err == nil, "Error receiving from client: %v", op.recv.err)
	if op.recv.received == 0 {
		// NOTE: leaking `connection`.
		nbio.close(connection.sock)
		return
	}

	nbio.send_poly(connection.sock, {connection.buf[:op.recv.received]}, connection, on_sent)
}

on_sent :: proc(op: ^nbio.Operation, connection: ^Connection) {
	fmt.assertf(op.send.err == nil, "Error sending to client: %v", op.send.err)

	// Accept the next message, to then ultimately echo back again.
	nbio.recv_poly(connection.sock, {connection.buf[:]}, connection, on_recv)
}
