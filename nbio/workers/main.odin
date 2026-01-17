/*
Example shows how you can execute CPU intensive (or blocking IO),
without blocking the event loop thread.

It creates a thread pool, starts a TCP server, which creates a task on the thread pool
for each connection (the task currently just sleeps, but could do anything).

Once the work on the worker thread is done, it uses `nbio.next_tick`,
passing it the main event loop. This will queue that callback onto the main event loop.

When the main thread runs it's next tick, it will see that queued work and execute it's callback.
That callback finally sends the result to the client, and once it is sent, cleans up.

You can run this with the netcat utility as the client like so: `nc 127.0.0.1 1234`.
*/
package main

import "core:nbio"
import "core:thread"
import "core:time"

Connection :: struct {
	loop:   ^nbio.Event_Loop,
	socket: nbio.TCP_Socket,
}

main :: proc() {
	// accept, put work on worker, worker adds back on main thread

	// Set up a thread pool with 2 workers.
	workers: thread.Pool
	thread.pool_init(&workers, context.allocator, 2)
	thread.pool_start(&workers)

	ep, ok := nbio.parse_endpoint("127.0.0.1:1234")
	assert(ok)

	err := nbio.acquire_thread_event_loop()
	defer nbio.release_thread_event_loop()
	assert(err == nil)

	server, listen_err := nbio.listen_tcp(ep)
	assert(listen_err == nil)
	nbio.accept_poly(server, &workers, on_accept)

	err = nbio.run()
	assert(err == nil)

	on_accept :: proc(op: ^nbio.Operation, workers: ^thread.Pool) {
		assert(op.accept.err == nil)

		// Accept next connection.
		nbio.accept_poly(op.accept.socket, workers, on_accept)

		// Add work to worker.
		thread.pool_add_task(workers, context.allocator, do_work, new_clone(Connection{
			loop   = op.l,
			socket = op.accept.client,
		}))
	}

	do_work :: proc(t: thread.Task) {
		connection := (^Connection)(t.data)

		// Imagine CPU intensive work.
		time.sleep(time.Second * 5)

		// Work has been done, we can now tell the client about it.
		// NOTE: that we pass the event loop of the main IO thread here so it queues it on that.
		nbio.send_poly(connection.socket, {transmute([]byte)string("Hellope!\n")}, connection, on_sent, l=connection.loop)
	}

	on_sent :: proc(op: ^nbio.Operation, connection: ^Connection) {
		assert(op.send.err == nil)
		// Client got our message, clean up.
		nbio.close(connection.socket)
		free(connection)
	}
}
