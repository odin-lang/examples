/*
Shows how to start a thread and let it do some calculations while the main
thead also does some calculations.
*/

package basic_thread_example

import "core:thread"
import "core:fmt"

Thread_Data :: struct {
	// thread input:
	num_integers_to_sum: int,

	// thread output (don't touch until thread is done!):
	sum: int,
}

thread_proc :: proc(t: ^thread.Thread) {
	fmt.println("Thread starting")
	d := (^Thread_Data)(t.data)

	for i in 0..<d.num_integers_to_sum {
		d.sum += i
	}

	fmt.println("Thread finishing")
}

main :: proc() {
	NUM_INTEGERS_TO_SUM :: 10000000

	d := Thread_Data {
		num_integers_to_sum = NUM_INTEGERS_TO_SUM,
	}

	t := thread.create(thread_proc)
	assert(t != nil)
	t.data = &d

	// Exactly when `thread_proc` starts running isn't certain. The operating
	// system will schedule it to start soon.
	thread.start(t)

	fmt.println("Main thread will do the same thing as the other thread, to make sure it does it correctly!")

	sum: int
	for i in 0..<NUM_INTEGERS_TO_SUM {
		sum += i
	}

	fmt.println("OK. Let's wait for the other thread to finish...")

	// thread.join waits for thread to finish. It will block until it is done.
	thread.join(t)
	thread.destroy(t)

	// Thread is finished, `d.sum` is safe to read.

	fmt.printfln("Main thread calculated this sum: %v", sum)
	fmt.printfln("The other thread calculated this sum: %v", d.sum)
}