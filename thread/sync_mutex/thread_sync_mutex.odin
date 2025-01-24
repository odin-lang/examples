//
// Demonstrates how to spawn multiple threads and safely access data 
// from each by using a mutex.
//
package thread_sync_example

import "core:fmt"
import "core:math/rand"
import "core:sync"
import "core:thread"
import "core:time"

// Defines an arbitrary work item. To simulate the CPU work on
// these items, each will have a "processing time" that each thread will
// wait for before continuing onto the next item.
Work_Item :: struct {
	item_tag:        i32,
	processing_time: f32,
}

create_randomized_queue :: proc(num_items: int) -> (q: [dynamic]Work_Item) {
	// This initializes the queue with a length of zero, and a capacity of `num_items`.
	// Pre-allocating space when you know how much you need is good!
	q = make([dynamic]Work_Item, 0, num_items)

	// Initialize the items in the queue. Each item will have a unique tag,
	// and a random "processing time".
	for i in 0 ..< num_items {
		item: Work_Item
		item.item_tag = i32(i) + 1
		// This sets the item's processing time to a value between 0.1 and 0.51 (exclusive).
		item.processing_time = rand.float32_range(0.1, 0.51)
		append(&q, item)
	}

	return
}

// This is the procedure that we'll be running in the threads that we spawn later.
process_item :: proc(queue: ^[dynamic]Work_Item, mutex: ^sync.Mutex, thread_identifier: int) {
	// This proc is essentially an infinite loop that breaks once it no longer has any data to process.

	for {
		// First we need to get a lock on our mutex. 
		// That way we know whether we can safely access our queue, or whether 
		// another thread is using it already.
		sync.mutex_lock(mutex)

		// This is the critical point where the mutex being locked matters.
		// Here we attempt to pop the first element off of our queue.
		item, pop_ok := pop_front_safe(queue)

		// Now that we've got the data we need from the queue, we can unlock our mutex 
		// to let other threads access the queue to perform their work.
		sync.mutex_unlock(mutex)

		// If we tried to pop something off but the queue was empty, we have nothing left to
		// process, so we'll just break out of our ininite loop.
		// Once the loop ends, our function will return, and the thread will stop.
		if !pop_ok {
			break
		}

		// Now we can do our item processing! Which in this case is just "processing" it for 
		// the item's `processing_time` in seconds.
		//
		// Since `processing_time` is a f32, you need to cast `time.Second` to a f32, 
		// then back to `time.Duration` to get your fraction of a second.
		time.sleep(time.Duration(f32(time.Second) * item.processing_time))

		// After we've done our "processing" (sleeping on the job, really), we can print
		// some info to the console about our item, and the thread that grabbed it.
		//
		// `fmt.printfln` and the other `fmt` procs that print to stdout are thread-safe, 
		// so nothing to worry about here.
		fmt.printfln(
			"[THREAD %02d] Item %04d processed in %0.2f seconds.",
			thread_identifier,
			item.item_tag,
			item.processing_time,
		)
	}
}

main :: proc() {
	// This `RANDOM_SEED` is just a compile-time constant that will
	// seed the default random generator if specified as a non-zero value.
	// I added this in to allow for predictable, reproducible outputs.
	//
	// When it's 0, Odin's random generator is seeded as it normally would be by default.
	// Otherwise, this `when` clause kicks in at compile-time 
	// and will override the default seeding mechanism.
	//
	// To specify it yourself, you can just add `--define:RANDOM_SEED=...`
	// to your `odin build/run` command.
	RANDOM_SEED: u64 : #config(RANDOM_SEED, 0)
	when RANDOM_SEED > 0 {
		state := rand.create(RANDOM_SEED)
		context.random_generator = rand.default_random_generator(&state)
	}

	// Initialize a randomized set of data to work off of.
	// It'll be a dynamic array of `Work_Items`, which essentially just have an ID number and a duration.
	queue := create_randomized_queue(500)

	// This is a Mutex. (Short for "mutual exclusion lock")
	// It doesn't actually hold any data, but rather it's used in multi-threaded 
	// applications as a way to tell other threads when it's safe to access data.
	//
	// A Mutex starts in an UNLOCKED state. At any time, you can LOCK a Mutex using `sync.lock`.
	// If a Mutex is LOCKED, that means when something else tries to LOCK it, it will halt the 
	// execution of that thread since another thread has already LOCKED it.
	//
	// However, once the Mutex is UNLOCKED, any thread can LOCK it for themselves.
	//
	// Mutexes can be used to guarantee safe access to data across multiple threads. Once a thread locks it, 
	// any other threads that also try to lock it will be forced to wait. 
	// This prevents two threads from reading/writing the same data, which can result in data races.
	mutex: sync.Mutex


	// This constant int is going to define how many threads we actually want to run.
	MAX_THREADS: int : 8
	// And here we define an array that's going to hold all of the Threads that we spawn.
	threads: [MAX_THREADS]^thread.Thread

	// Let's start making some threads.
	for i in 0 ..< len(threads) {
		// Let's get which thread number this is so we can pass it to our threaded proc.
		t_id := i + 1
		// This is where the magic happens. We're going to create up to our MAX number of Threads and store them in our 
		// `threads` array.
		// Since our thread proc takes three arguments, we need a way to pass these in.
		// Luckily, `create_and_start_with_poly_data` exists! It allows you to pass in function arguments that get 
		// consumed by the thread proc easily.
		//
		// Now to explain exactly what these arguments are:
		//      &queue  - A pointer to our queue object. We need to pass it by pointer to pop items off of it!
		//      &mutex  - A pointer to our mutex. This is what our threads will use to signal to each other that they 
		//				need exclusive access to the queue at the critical point where they access it.
		//      t_id    - Just the index of our thread + 1, for printing purposes so we can identify who's working.
		//
		//      process_item - This is our procedure! The thread is going to make this thing run with all of the 
		//		previous arguments passed into it.
		//
		// With all that out of the way, let's create our thread and store it in `threads` at index `i` for later!
		threads[i] = thread.create_and_start_with_poly_data3(&queue, &mutex, t_id, process_item)
	}

	// Now we're going to use `join_multiple` to wait for all of our threads to stop processing.
	// This is why we're holding onto those threads in our array. You wouldn't want to just let them spin off 
	// and never check on them again!
	//
	// `join_multiple` takes a variable number of Thread pointers (`^Thread`), and BLOCKS the main thread 
	// until each one of them is finished processing.
	//
	// Since we have an array of Thread pointers, we can use the `..` operator to expand all of the array 
	// items as arguments to `join_multiple`!
	thread.join_multiple(..threads[:])

	// Once the program ends, we'll clean up after ourselves by destroying each of these threads we created.
	for t in threads {
		thread.destroy(t)
	}

	// Everything's all finished now. Let's print out a "done" message and call it a day!
	fmt.printfln("Processed all items! Exiting.")
}
