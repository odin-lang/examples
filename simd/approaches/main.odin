package simd_approaches

import "base:intrinsics"
import "core:fmt"
import "core:math/rand"
import "core:simd"
import "core:time"

// The number of elements to use for SIMD vectors (in cases where the width is variable).
WIDTH :: #config(WIDTH, 8)

// The number of objects to use in benchmarking.
NUM_OBJECTS :: #config(NUM_OBJECTS, 1_000_000)

// Extra padding to add in to the Object. As this increases, *any* AoS solution will suffer due to
// the decreasing effectiveness of memory caching.
PADDING :: #config(PADDING, 0)

// Straightforward data layout.
Object :: struct {
	pos, vel: [3]f32,
	_: [PADDING]f32,
}

// A straightforward implementation using array programming.
step_aos_scalar :: proc (data: []Object, dt: f32) {
	for &obj in data {
		obj.pos += obj.vel * dt
	}
}

/*
We can use SIMD within an object, where a SIMD vector is used similarly to a mathematical vector.
This can provide moderate speedup without requiring the layout of your data to change
significantly, but doesn't necessarily scale. Even if your hardware can support wider SIMD
(e.g. 16 f32s with AVX-512), this approach will only allow you to SIMD up to a single
(mathematical) vector's worth of values.

However, most any SIMD hardware can handle 128-bit vectors, and as such will benefit from this.
While it may not technically be the fastest, it can still be a significant speedup.

Using masked loads and stores, you can potentially benefit from SIMD without needing to change
the data layout at all. Note that on amd64, this approach is comparable to the scalar approach
with default settings, but becomes significantly more effective with AVX enabled
(-target-features:avx or -microarch:x86-64-v3). AVX is available on any remotely-recent amd64
system.
*/

// Loads a [3]f32 into a #simd[4]f32 using masking. The fourth element is filled with 0. This
// approach allows for SIMD to be used with minimal alterations to existing data layouts.
load_vec :: proc (src: ^[3]f32) -> #simd[4]f32 {
	mask := #simd[4]u32{ 0..<3 = max(u32) }
	return simd.masked_load(cast(^#simd[4]f32)src, cast(#simd[4]f32)0, mask)
}

// Stores the first three elements of a #simd[4]f32 into a [3]f32 using masking. This approach
// allows for SIMD to be used with minimal alterations to existing data layouts.
store_vec :: proc (dst: ^[3]f32, src: #simd[4]f32) {
	mask := #simd[4]u32{ 0..<3 = max(u32) }
	simd.masked_store(cast(^#simd[4]f32)dst, src, mask)
}

// Using the above load_vec and store_vec, we can SIMD the update without needing to make any
// changes to the data layout at all. The code itself stays pretty simple too.
step_aos_within_mask :: proc (data: []Object, dt: f32) {
	for &obj in data {
		pos := load_vec(&obj.pos)
		vel := load_vec(&obj.vel)
		store_vec(&obj.pos, pos + vel * dt)
	}
}

/*
As another potential improvement, we can actually change the layout of the object so that the
mathematical vectors are stored as SIMD vectors. This makes loading them easier and possibly
faster--though this depends on the target.

This also has the downside that it affects the layout of your structs, resulting in a larger
alignment and a bit of padding after each vector. Additionally, any code which *does* need to
deal with the individual components of a vector will have a harder time doing so since #simd
vectors can't be indexed directly.
*/
Object_Simd :: struct {
	pos, vel: #simd[4]f32,
	_: [PADDING]int,
}

step_aos_within_simd :: proc (data: []Object_Simd, dt: f32) {
	for &obj in data {
		obj.pos += obj.vel * dt
	}
}

/*
What if we want to take advantage of the full width of the SIMD vectors? Modern hardware can have
as many as 16-float wide vectors (AVX-512), it sure seems restrictive to only be able to use 3.
`core:simd` has gather and scatter intrinsics that we can use to load and store each element of
a vector from arbitrary locations, provided as pointers. In theory, this allows us to take
advantage of the full width of the SIMD vector without needing to rearrange the struct at all!

There's just one problem: this approach is often very slow--possibly even significantly slower
than the scalar version, depending on your hardware.

On amd64, the gather instruction is only available with AVX2, so it can't be used with the
default compilation settings. Even then LLVM will tend to avoid using the actual gather
instruction in the x86-64-v3 microarch, and with good reason--it's quite slow on many CPUs. This
isn't just on old CPUs, either--even on a recent Ryzen 9950X, the alternative code that LLVM
generates to load the values in scalar fashion and load them into a vector is *still* faster than
the version it generates that uses the actual gather instruction. This may vary depending on the
hardware, so test on your target hardware if you know what it will be (and avoid gather if you
don't). Scatter is supported by even less hardware.

For amd64, to enable the use of hardware gather instructions, use
-target-features:avx2,fast-gather . Hardware scatter requires AVX-512
( -target-features:avx512f,avx512vl ), but that's rare and may not fare much better even on
hardware that has it.
*/
step_aos_gather :: proc (data: []Object, dt: f32) {
	data := data

	do_add :: #force_inline proc (base: ^Object, dt: f32, mask: #simd[WIDTH]u32 = max(u32)) {
		index := iota(#simd[WIDTH]uintptr)
		step := index * size_of(Object)

		// Generate a pointer to each value of interest
		px_ptr := cast(#simd[WIDTH]rawptr)(uintptr(&base.pos.x) + step)
		vx_ptr := cast(#simd[WIDTH]rawptr)(uintptr(&base.vel.x) + step)
		px := simd.gather(px_ptr, cast(#simd[WIDTH]f32)0, mask)
		px += simd.gather(vx_ptr, cast(#simd[WIDTH]f32)0, mask) * dt
		simd.scatter(px_ptr, px, mask)

		py_ptr := cast(#simd[WIDTH]rawptr)(uintptr(&base.pos.y) + step)
		vy_ptr := cast(#simd[WIDTH]rawptr)(uintptr(&base.vel.y) + step)
		py := simd.gather(py_ptr, cast(#simd[WIDTH]f32)0, mask)
		py += simd.gather(vy_ptr, cast(#simd[WIDTH]f32)0, mask) * dt
		simd.scatter(py_ptr, py, mask)

		pz_ptr := cast(#simd[WIDTH]rawptr)(uintptr(&base.pos.z) + step)
		vz_ptr := cast(#simd[WIDTH]rawptr)(uintptr(&base.vel.z) + step)
		pz := simd.gather(pz_ptr, cast(#simd[WIDTH]f32)0, mask)
		pz += simd.gather(vz_ptr, cast(#simd[WIDTH]f32)0, mask) * dt
		simd.scatter(pz_ptr, pz, mask)
	}

	for len(data) >= WIDTH {
		do_add(raw_data(data), dt)
		data = data[WIDTH:]
	}

	if len(data) > 0 {
		mask := simd.lanes_lt(iota(#simd[WIDTH]u32), cast(#simd[WIDTH]u32)len(data))
		do_add(raw_data(data), dt, mask)
	}
}

/*
Finally, if we want to go all-out and take full advantage of the hardware, we need to rearrange
our data layout. Rather than storing all of the data for each object together, in
Array-of-Structs form, we separate them so that each field's data is stored in a separate array.
We call this Struct-of-Arrays (SoA) form, as its in memory layout more closely resembles a struct
where each field is an array, rather than an array where each value is a complete struct.

Odin's #soa tag helps significantly with this, allowing you to write code that accesses SoA data
but still looks mostly like AoS data. We do, unfortunately, have to sacrifice the fixed arrays
for pos/vel as otherwise the compiler will still group their components together.

For this particular update procedure, this data layout can be extremely fast. All of the data it
uses is stored consecutively with no gaps, so the SIMD loads and stores can operate directly on
it and also take advantage of the full width of the SIMD vector. Try playing with WIDTH in
conjunction with AVX and/or AVX512 (if you have it)!

Because each field's data is stored separately, it's also unaffected by other data that may be
stored in the struct that isn't being used here. Try increasing PADDING--the other approaches
will tend to slow down as the data they operate on becomes spaced further apart, but this one
will not since the position and velocity will always be tightly-packed. However, for random
access of the data in the array it can end up being slower, due to the possibility of being
multiple cache misses instead of just one (not shown in these benchmarks).
*/
Object_Split :: struct {
	px, py, pz: f32,
	vx, vy, vz: f32,
	_: [PADDING]int,
}

step_soa :: proc (data: #soa[]Object_Split, dt: f32) {
	data := data

	do_add :: #force_inline proc (base: #soa[]Object_Split, first: int, dt: f32, mask: #simd[WIDTH]u32 = max(u32)) {
		px := intrinsics.unaligned_load(cast(^#simd[WIDTH]f32)base.px[first:])
		px += intrinsics.unaligned_load(cast(^#simd[WIDTH]f32)base.vx[first:]) * dt
		intrinsics.unaligned_store(cast(^#simd[WIDTH]f32)base.px[first:], px)

		py := intrinsics.unaligned_load(cast(^#simd[WIDTH]f32)base.py[first:])
		py += intrinsics.unaligned_load(cast(^#simd[WIDTH]f32)base.vy[first:]) * dt
		intrinsics.unaligned_store(cast(^#simd[WIDTH]f32)base.py[first:], py)

		pz := intrinsics.unaligned_load(cast(^#simd[WIDTH]f32)base.pz[first:])
		pz += intrinsics.unaligned_load(cast(^#simd[WIDTH]f32)base.vz[first:]) * dt
		intrinsics.unaligned_store(cast(^#simd[WIDTH]f32)base.pz[first:], pz)
	}

	i: int
	for i = 0; i+WIDTH <= len(data); i += WIDTH {
		do_add(data, i, dt)
	}

	if i < len(data) {
		left := len(data) - i
		mask := simd.lanes_lt(iota(#simd[WIDTH]u32), cast(#simd[WIDTH]u32)left)
		do_add(data, i, dt, mask)
	}
}

main :: proc () {
	if ODIN_OPTIMIZATION_MODE <= .Minimal {
		fmt.println("WARNING: For best results, run benchmarks in an optimized build!")
	}

	aos_data := make([]Object, 1_000_000)
	for &o in aos_data {
		o = make_object()
	}

	aos_simd_data := make([]Object_Simd, NUM_OBJECTS)
	for &o in aos_simd_data {
		temp := make_object()
		o = {
			pos = {temp.pos.x, temp.pos.y, temp.pos.z, 0},
			vel = {temp.vel.x, temp.vel.y, temp.vel.z, 0},
		}
	}

	soa_data := make(#soa[]Object_Split, NUM_OBJECTS)
	for &o in soa_data {
		temp := make_object()
		o = {
			px = temp.pos.x, py = temp.pos.y, pz = temp.pos.z,
			vx = temp.vel.x, vy = temp.vel.y, vz = temp.vel.z,
		}
	}

	bench_2("AoS Scalar", step_aos_scalar, aos_data, 1.0/60.0)
	bench_2("AoS Within (Masking)", step_aos_within_mask, aos_data, 1.0/60.0)
	bench_2("AoS Within (Vector Storage)", step_aos_within_simd, aos_simd_data, 1.0/60.0)
	bench_2("AoS Across (Gather)", step_aos_gather, aos_data, 1.0/60.0)
	bench_2("SoA Across", step_soa, soa_data, 1.0/60.0)
}

make_object :: proc () -> Object {
	return {
		pos = {
			rand.float32_range(-1000, 1000),
			rand.float32_range(-1000, 1000),
			rand.float32_range(-1000, 1000),
		},

		vel = {
			rand.float32_range(-10, 10),
			rand.float32_range(-10, 10),
			rand.float32_range(-10, 10),
		},
	}
}

bench_2 :: proc (name: string, p: proc($A, $B), a: A, b: B) {
	fmt.print(name, "... ", sep="")

	iterations, done := 1, 0
	start := time.tick_now()
	for time.tick_since(start) < time.Second {
		for _ in 0..<iterations {
			p(a, b)
		}

		done += iterations
		iterations += iterations
	}
	elapsed := time.tick_since(start)
	ips := f64(done) / f64(time.duration_seconds(elapsed))
	fmt.println(ips, "per sec")
}

iota :: proc ($T: typeid/#simd[$N]$E) -> (result: T) {
	for i in 0..<N {
		result = simd.replace(result, i, E(i))
	}
	return
}

