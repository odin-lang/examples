package main

import "base:runtime"
import "core:fmt"
import "core:math/rand"
import "core:mem"
import "core:thread"

// The number of threads in the pool.
THREAD_COUNT :: 8

// The number of tasks we want to perform.
// These tasks will be distributed among threads of the pool.
TASK_COUNT :: 64

main :: proc() {
	// Declare a variable for the thread pool.
	// The pool is not initialized and no threads are running.
	pool: thread.Pool

	// The thread pool requires an allocator which it either owns,
	// or which is thread safe.
	pool_allocator: mem.Allocator
	
	// For simplicity's sake, we use the default context allocator.
	// We can do it because in this example we will not allocate
	// anything after the pool is initialized.
	pool_allocator = context.allocator

	// Here we initialize the thread pool.
	// We provide an allocator and tell how many threads in the pool we need.
	thread.pool_init(&pool, pool_allocator, THREAD_COUNT)
	// After this point, it's not allowed to change the pool's memory address.

	// Now we start the pool, which internally starts all the threads.
	thread.pool_start(&pool)
	// After this point, it's not allowed to access pool's members directly,
	// since it might lead to VERY nasty bugs.
	// 
	// Instead, we should interact with the pool via `thread.pool_...` procedures
	// (`thread.pool_add_task`, `thread.pool_num_done`, `thread.pool_is_empty`, etc.).


	// Defer the pool destruction at the end of the current scope.
	// This ensures that the pool will be properly destroyed at the end,
	// and used resources will be freed.
	defer thread.pool_destroy(&pool)

	
	// Usually a task takes some input data and outputs some results.
	// In order to do so we have to create a chunk of memory that persists
	// for the whole duration of a task lifetime:
	// from the moment when it's added, while it waits to be performed,
	// when it's done, until you get and process the result.
	// 
	// For simplicity, we just create an array that contains space
	// for all tasks we plan to perform in this example.
	task_data_array: [TASK_COUNT]Add_Task_Data
	// NOTE: This memory is created on the stack, which does not violate
	// the allocation limitation described above.

	// Here is a loop where we add tasks to the pool.
	for task_index in 0..<TASK_COUNT {
		// A task also requires an allocator which it either owns,
		// or which is thread safe.
		task_allocator: mem.Allocator

		// However, the allocator is necessary only if you need to allocate memory
		// inside the task procedure. Since we know for a fact that our task
		// does not allocate memory, we can use `nil_allocator`.
		// 
		// Use of `nil_allocator` also protects you in case of accidental allocation.
		// Instead of a nasty memory bug, you'll get an allocator error.
		task_allocator = runtime.nil_allocator()

		// Here we select a "chunk" from our data array for the task we create.
		task_data := &task_data_array[task_index]
		
		// We initialize the input data for the task with random integers
		// in the range from 0 to 99 (max value is exclusive).
		task_data^ = {
			in_number_a = int(rand.int31_max(100)),
			in_number_b = int(rand.int31_max(100)),
		}

		// Now we finally add a new task to the pool. Besides the allocator,
		// the task creation requires a procedure that will be executed in another thread, 
		// alongside a pointer to the task data that will be passed to that procedure;
		// the last argument is `user_index` which is basically a task ID.
		thread.pool_add_task(&pool, task_allocator, add_task_handler, task_data, task_index)
	}

	fmt.println("Wait for all tasks to finish...")
	// We call `pool_finish` to stop the execution of the main thread and wait
	// for all tasks to be done. Actually, the main thread is not just waiting;
	// it also completes tasks, which effectively increases the pool threads by 1.
	thread.pool_finish(&pool)

	fmt.println("Preview results of the first three tasks:")
	for _ in 0..<3 {
		// Here we take one complete task from the pool. 
		// Tasks are taken in order of completion:
		//      pool_pop_done() -> a task finished first
		//      pool_pop_done() -> a task finished second
		task, _ := thread.pool_pop_done(&pool)
		// NOTE: We ignore the second return value since we already know all tasks are done.
		
		// Cast the task data to the type we expected.
		data := cast(^Add_Task_Data)task.data
		// And print the result.
		fmt.printfln(" %v + %v = %v", data.in_number_a, data.in_number_b, data.out_results)
	}
}

// This struct contains input data for the task
// and a place to store the result.
Add_Task_Data :: struct {
	in_number_a: int,
	in_number_b: int,
	out_results: int,
}

// This procedure handles the add task.
// It expects two numbers and outputs their sum.
add_task_handler :: proc(task: thread.Task) {
	// The data is passed as a `rawptr`,
	// so we cast it to the type expected by the task.
	data := cast(^Add_Task_Data)task.data

	// Compute and store the sum.
	data.out_results = data.in_number_a + data.in_number_b
}
