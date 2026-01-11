package main

import "base:runtime"

import "core:nbio"
import "core:time"

main :: proc() {
	nbio.acquire_thread_event_loop()
	defer nbio.release_thread_event_loop()

	{
		context.user_index = 2

		// By default, the context you receive in callbacks is the one that `nbio.run`/`tick` receives.
		nbio.timeout(time.Second, proc(op: ^nbio.Operation) {
			assert(context.user_index == 1)
		})

		// If you want to pass through the current context, you could clone it, pass it through user data, and restore it.
		nbio.timeout_poly(time.Second, new_clone(context), proc(op: ^nbio.Operation, ctx: ^runtime.Context) {
			context = ctx^
			free(ctx)
			assert(context.user_index == 2)
		})
	}

	context.user_index = 1
	nbio.run()
}
