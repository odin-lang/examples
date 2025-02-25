package simd_example

import "base:intrinsics"
import "core:fmt"
import "core:math/rand"
import "core:simd"
import "core:time"

NUM_DATA :: #config(NUM, 10_000_000) // The amount of data points to generate and process
NUM_REPETITIONS :: #config(REP, 100) // The number of times to run each proc, for performance measurement
WIDTH :: #config(WIDTH, 16)

// A single moving point. A point has a position and a velocity, and in this example they will
// travel in a straight line and bounce when reaching the edge of a bounding rectangle.
Point :: struct {
	// Components are separate fields so that they'll be stored in separate arrays when used as #soa
	pos_x, pos_y, vel_x, vel_y: f32,
}

// Updates a SoA slice of points, with given the bounds and delta-time.
// This implementation uses straightforward scalar logic.
update_points_scalar :: proc (points: #soa[]Point, bounds: [2][2]f32, dt: f32) {
	for &point in points {
		if point.pos_x <= bounds[0].x { point.vel_x = +abs(point.vel_x) }
		if point.pos_x >= bounds[1].x { point.vel_x = -abs(point.vel_x) }
		if point.pos_y <= bounds[0].y { point.vel_y = +abs(point.vel_y) }
		if point.pos_y >= bounds[1].y { point.vel_y = -abs(point.vel_y) }

		point.pos_x += dt * point.vel_x
		point.pos_y += dt * point.vel_y
	}
}

// Updates a SoA slice of points, with given the bounds and delta-time
// This implementation uses SIMD logic.
update_points_simd :: proc (points: #soa[]Point, bounds: [2][2]f32, dt: f32) {
	process_chunk :: proc (points: #soa[]Point, mask: #simd[WIDTH]u32, bounds: [2][2]f32, dt: f32) {
		px_ptr := cast(^#simd[WIDTH]f32)points.pos_x
		py_ptr := cast(^#simd[WIDTH]f32)points.pos_y
		vx_ptr := cast(^#simd[WIDTH]f32)points.vel_x
		vy_ptr := cast(^#simd[WIDTH]f32)points.vel_y

		// Read the vectors of positions and velocities, as specified by the mask. Any values that
		// are masked out are just populated with 0 (from the second parameter).
		// 
		// Each component is in a separate vector, so the math is vaguely similar to the math for
		// doing just one at a time, as opposed to the "vectors" in the traditional sense
		// corresponding to a SIMD vector. This allows for better parallelism, especially in 2D.
		// Using a SIMD vector to represent a 2D vector would give relatively little benefit (2x
		// parallelism at most, often less), whereas using a SIMD vector to represent a single
		// component across multiple vectors allows this to scale (processing 4/8/16+ points at a
		// time).
		px := simd.masked_load(px_ptr, cast(#simd[WIDTH]f32)0, mask)
		py := simd.masked_load(py_ptr, cast(#simd[WIDTH]f32)0, mask)
		vx := simd.masked_load(vx_ptr, cast(#simd[WIDTH]f32)0, mask)
		vy := simd.masked_load(vy_ptr, cast(#simd[WIDTH]f32)0, mask)

		// Select elements where the X position is less than the minimum, replace the corresponding
		// velocity with its absolute value.
		// 
		// Rather than doing this with normal conditionals, it's done via lane-wise comparisons and
		// select. This means the absolute value is calculated for every element regardless of
		// whether it's used, but this allows for better parallelism.
		// 
		// If the computation is something more expensive, you can use a conditional to simplify
		// cases where all/none are matched via simd.reduce_and/reduce_or on the mask, but in this
		// case it's not worth it.
		min_x_mask := simd.lanes_le(px, cast(#simd[WIDTH]f32)bounds[0].x)
		vx = simd.select(min_x_mask, +simd.abs(vx), vx)

		// As above, but with the Y component
		min_y_mask := simd.lanes_le(py, cast(#simd[WIDTH]f32)bounds[0].y)
		vy = simd.select(min_y_mask, +simd.abs(vy), vy)

		// As above, but with the maximums
		max_x_mask := simd.lanes_ge(px, cast(#simd[WIDTH]f32)bounds[1].x)
		vx = simd.select(max_x_mask, -simd.abs(vx), vx)

		max_y_mask := simd.lanes_ge(py, cast(#simd[WIDTH]f32)bounds[1].y)
		vy = simd.select(max_y_mask, -simd.abs(vy), vy)

		// Updating the positions, at least, is straightforward
		px += dt * vx
		py += dt * vy

		// Write the modified positions/velocities back
		// As with reads, only the positions that are selected in the mask are actually written to
		// in memory
		simd.masked_store(px_ptr, px, mask)
		simd.masked_store(py_ptr, py, mask)
		simd.masked_store(vx_ptr, vx, mask)
		simd.masked_store(vy_ptr, vy, mask)
	}

	points := points
	for len(points) >= WIDTH {
		process_chunk(points, max(u32), bounds, dt)
		points = points[WIDTH:]
	}

	if len(points) > 0 {
		index := iota(#simd[WIDTH]i32)
		mask := simd.lanes_lt(index, cast(#simd[WIDTH]i32)len(points))
		process_chunk(points, mask, bounds, dt)
	}
}

main :: proc() {
	if ODIN_OPTIMIZATION_MODE <= .Minimal {
		fmt.println("WARNING: For best results, run benchmarks in an optimized build!")
	}

	bounds := [2][2]f32 {
		{-100, -100},
		{+100, +100},
	}
	dt := f32(0.1)

	points := make(#soa[]Point, NUM_DATA, context.temp_allocator)
	for &point in points {
		point.pos_x = rand.float32_range(bounds[0].x, bounds[1].x)
		point.pos_y = rand.float32_range(bounds[0].y, bounds[1].y)
		point.vel_x = rand.float32_range(-1, +1)
		point.vel_y = rand.float32_range(-1, +1)
	}

	fmt.printfln("Motion (Scalar): %v", benchmark(update_points_scalar, points, bounds, dt))
	fmt.printfln("Motion (SIMD): %v", benchmark(update_points_simd, points, bounds, dt))
}

benchmark :: proc (p: proc (points: #soa[]Point, bounds: [2][2]f32, dt: f32), points: #soa[]Point, bounds: [2][2]f32, dt: f32) -> time.Duration {
	best_elapsed := max(time.Duration)
	for _ in 0..<NUM_REPETITIONS {
		start := time.tick_now()
		p(points, bounds, dt)
		best_elapsed = min(time.tick_since(start), best_elapsed)
	}
	return best_elapsed
}

iota :: proc ($V: typeid/#simd[$N]$E) -> (result: V) {
	for i in 0..<N {
		result = simd.replace(result, i, E(i))
	}
	return
}

