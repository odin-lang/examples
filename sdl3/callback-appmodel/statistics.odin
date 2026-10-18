package sdl3_callback_appmodel_example

import reflect "core:reflect"
import slice "core:slice"
import queue "core:container/queue"
import fmt "core:fmt"

Statistic :: enum {
	window,
	timing,
	input,
	render_statistics,
	present,
	event,

	update_position,
	render_clear,
	render_texture,
}

Statistic_Sample :: struct {
	name:          string,
	queue:         queue.Queue(f32),
	sum_in_queue:  f32,
	max:           f32,
}

STATISTICS_QUEUE_SIZE :: 100

statistics : [dynamic]Statistic_Sample

statistics_get_associative_array_length :: proc() -> int {
	values := reflect.enum_field_values(Statistic)
	max, ok := slice.max(values)
	if !ok {
		return 0
	}
	return cast(int)max + 1
}

statistics_record :: proc(id : Statistic, value : f32) {
	if statistics == nil {
		length := statistics_get_associative_array_length()
		statistics = make([dynamic]Statistic_Sample, length)
		for i in 0 ..< length {
			statistics[i].name = reflect.enum_string(cast(Statistic)i)
			queue.init(&statistics[i].queue, STATISTICS_QUEUE_SIZE)
		}
	}
	sample := &statistics[transmute(int)id]
	for queue.len(sample.queue) >= STATISTICS_QUEUE_SIZE {
		popped := queue.dequeue(&sample.queue)
		sample.sum_in_queue -= popped
	}
	queue.enqueue(&sample.queue, value)
	sample.sum_in_queue += value
	if value > sample.max {
		sample.max = value
	}
}

statistics_print :: proc() {
	fmt.println("Statistics:")
	for i in 0 ..< len(statistics) {
		name := statistics[i].name
		avg := statistics[i].sum_in_queue / cast(f32)queue.len(statistics[i].queue)
		max := statistics[i].max
		fmt.printfln("  %v: Avg %.2f - Max %.2f", name, avg, max)
	}
}
