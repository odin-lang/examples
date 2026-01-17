/*
Example shows how you could poll completions instead of being pushed completions through callbacks.

Completions are added to a queue by a single simple callback, and handled whenever wanted.

It is a UDP echo server.
*/
package main

import "core:container/queue"
import "core:fmt"
import "core:nbio"

main :: proc() {
	nbio.acquire_thread_event_loop()
	defer nbio.release_thread_event_loop()

	socket, err := nbio.create_udp_socket(.IP4)
	if err != nil {
		fmt.eprintfln("create_udp_socket: %v", err)
		return
	}
	if err := nbio.bind(socket, {nbio.IP4_Loopback, 1234}); err != nil {
		fmt.eprintfln("bind: %v", err)
		return
	}

	buf: [1024]byte
	nbio.recv(socket, {buf[:]}, queue_callback)

	for {
		fmt.println("tick")

		for op in queue.pop_front_safe(&g_queue) {
			defer nbio.reattach(op) // Releases ownership of the operation.

			fmt.printfln("%v completed", op.type)

			#partial switch op.type {
			case .Recv:
				if op.recv.err != nil {
					fmt.eprintfln("recv: %v", op.recv.err)
					nbio.recv(socket, {buf[:]}, queue_callback)
					continue
				}

				fmt.printfln("received %M", op.recv.received)
				nbio.send(socket, {buf[:op.recv.received]}, queue_callback, op.recv.source)

			case .Send:
				if op.send.err != nil {
					fmt.eprintfln("send: %v", op.send.err)
				}
				fmt.printfln("sent %M", op.send.sent)
				nbio.recv(socket, {buf[:]}, queue_callback)

			case:
				fmt.eprintfln("unimplemented: %v", op.type)
			}
		}

		if err := nbio.tick(); err != nil {
			fmt.eprintfln("tick: %v", err)
		}
	}
}

g_queue: queue.Queue(^nbio.Operation)

queue_callback :: proc(op: ^nbio.Operation) {
	nbio.detach(op) // Takes ownership of the operation.
	queue.push_back(&g_queue, op)
}
