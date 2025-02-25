package main

import "base:intrinsics"
import "core:fmt"
import "core:math/rand"
import "core:simd"
import "core:time"

MISALIGN :: #config(MISALIGN, false) // Whether to misalign the data, for testing purposes
NUM_DATA :: #config(NUM, 10_000_000) // The amount of data points to generate and process
NUM_REPETITIONS :: #config(REP, 100) // The number of times to run each proc, for performance measurement

// Calculates the sum of an array of f32, the basic way.
// Due to LLVM math settings that Odin doesn't provide a way to set, this won't (currently) be
// autovectorized.
sum_scalar :: proc (s: []f32) -> (sum: f32) {
	for x in s {
		sum += x
	}
	return
}

// Calculates the sum of an array of f32, the basic way, using f64s to hold the sum.
// This gives a more precise result, as floating-point precision results in a cumulative error
// when adding many numbers together. The performance cost is negligible compared to summing in f32
// (on amd64).
sum_scalar_wide :: proc (s: []f32) -> f32 {
	sum : f64
	for x in s {
		sum += f64(x)
	}
	return f32(sum)
}

// The number of elements to use in SIMD vectors.
// The best value for this will depend on the available SIMD instructions, and possibly the hardware
// itself.
//
// On amd64, the default target only uses SSE4, which has 128-bit SIMD registers. This means that
// #simd[4]f32 would be the native vector size on that target--but that doesn't always give the
// fastest results, as larger vectors allow for better instruction-level parallelism. For larger
// vectors, LLVM will automatically spread the data over multiple SIMD registers, but if the SIMD
// vector is too large this starts to become a detriment to performance. Try comparing the results
// between 4, 8, and 16! This particular example isn't complex enough to suffer from too large of
// vectors, even with a WIDTH of 64.
// 
// You will likely see a performance boost, particularly in the f64 case, by enabling AVX, and
// around 97% of PCs support that (according to the October 2024 Steam hardware survey). You can
// enable that by building with -target-features:avx (or -microarch:x86-64-v3, for a number of CPU
// features available on many modern systems). However, note that doing so will cause the program to
// crash on systems that don't support these features!
WIDTH :: #config(WIDTH, 16)

// Calculates the sum of an array of f32 using SIMD.
// Like with the scalar version, this is susceptible to limitations of floating-point precision--
// however, you'll notice that the result is often different! This is why LLVM won't auto-vectorize
// that version. By default, LLVM handles floating-point math in a strict fashion, where it will
// only perform optimizations that don't change the order of the math operations (as that can change
// the result).
sum_simd :: proc (s: []f32) -> f32 {
	s := s

	vec_sum : #simd[WIDTH]f32
	for len(s) >= WIDTH {
		chunk_ptr := cast(^#simd[WIDTH]f32)raw_data(s)
		s = s[WIDTH:]

		// SIMD vectors are sensitive to alignment, so an unaligned load is used here.
		// A f32 has an alignment of 4 bytes, whereas SIMD registers often have an alignment of
		// 16/32/64 bytes. The input slice may not meet this alignment, so an unaligned load is
		// used. A regular dereference will load the vector with strict alignment, and if the
		// pointer isn't correctly aligned that will crash the program!
		// 
		// There are other ways of dealing with this too (e.g. process in scalar
		// until you reach the appropriate alignment), but using an unaligned load is
		// simple and has a negligible cost on most modern systems.
		chunk := intrinsics.unaligned_load(chunk_ptr)

		// While it may be intuitive to reduce the intermediate vector to a single value here, that
		// will actually reduce the parallelism and hurt performance! Generally, for best SIMD
		// performance, stay wide as long as possible.
		vec_sum += chunk
	}

	// Reduces all of the elements in the vector to a single value by adding them (also known as a
	// horizontal add). In this case, this gives the sum of all the values processed so far.
	sum := simd.reduce_add_ordered(vec_sum)

	// Since the vectorized part above worked in chunks of size WIDTH, any leftover needs to be
	// handled separately. There are multiple ways to do this; in this case, we just process the
	// remaining few values in scalar fashion.
	// 
	// Note that for more complex logic, this could result in a duplication of logic! See
	// sum_simd_masked for an alternative.
	for x in s {
		sum += x
	}
	return sum
}

// Calculates the sum of an array of f32 using SIMD, using f64s to hold the sum.
// This gives a more precise result, as floating-point precision results in a cumulative error
// when adding many numbers together. Unlike with the scalar procs, though, the performance cost vs.
// the pure f32 version is much more significant (but still much faster than the non-SIMD variants).
// This is because half as many f64s can fit in a single SIMD register, reducing parallelism. It's
// still significantly faster than the scalar versions, though!
sum_simd_wide :: proc (s: []f32) -> f32 {
	s := s

	vec_sum : #simd[WIDTH]f64
	for len(s) >= WIDTH {
		chunk_ptr := cast(^#simd[WIDTH]f32)raw_data(s)
		s = s[WIDTH:]

		chunk := cast(#simd[WIDTH]f64)intrinsics.unaligned_load(chunk_ptr)
		vec_sum += chunk
	}

	sum := simd.reduce_add_ordered(vec_sum)
	for x in s {
		sum += f64(x)
	}
	return f32(sum)
}

// Calculates the sum of an array of f32 using SIMD with masking to handle non-multiples-of-WIDTH.
sum_simd_masked :: proc (s: []f32) -> f32 {
	s := s

	process_chunk :: proc (chunk_ptr: ^#simd[WIDTH]f32, mask: #simd[WIDTH]u32, sum: #simd[WIDTH]f32) -> #simd[WIDTH]f32 {
		// Masked loads only load the elements that are selected in the mask. Memory locations that
		// are not selected in the mask are effectively not touched, so it's safe for some elements
		// to be "past the end" of the available data, as long as they aren't selected by the mask.
		// Values that aren't selected in the mask receive their values from the corresponding
		// element in the second parameter instead (in this case, 0).
		//
		// Masked loads and stores don't have the strict alignment requirements that raw dereferences do.
		chunk := simd.masked_load(chunk_ptr, cast(#simd[WIDTH]f32)0, mask)

		// In this case the operation is trivial--but for more complex operations, sharing the code
		// can be beneficial. See the motion example for a more complex example.
		return sum + chunk
	}

	vec_sum : #simd[WIDTH]f32

	for len(s) >= WIDTH {
		chunk_ptr := cast(^#simd[WIDTH]f32)raw_data(s)
		s = s[WIDTH:]

		mask := cast(#simd[WIDTH]u32)max(u32) // Selects every element
		vec_sum = process_chunk(chunk_ptr, mask, vec_sum)
	}

	// Handle any leftovers via masking. This can be combined with the above loop, but that will result in worse performance
	if len(s) > 0 {
		chunk_ptr := cast(^#simd[WIDTH]f32)raw_data(s)

		// This mask will select vector elements where the element's value in index is less than the
		// remaining length of the slice (in this case, the elements that are within the bounds of
		// the slice)
		// Comparisons generate a vector with integer elements, where each element is either 0
		// (false) or non-zero (true), depending on the result of the comparison
		index := iota(#simd[WIDTH]i32)
		mask := simd.lanes_lt(index, cast(#simd[WIDTH]i32)len(s))

		vec_sum = process_chunk(chunk_ptr, mask, vec_sum)
	}

	return simd.reduce_add_ordered(vec_sum)
}

main :: proc() {
	if ODIN_OPTIMIZATION_MODE <= .Minimal {
		fmt.println("WARNING: For best results, run benchmarks in an optimized build!")
	}

	when MISALIGN {
		data_original := make([]f32, NUM_DATA + 1, context.temp_allocator)
		data := ([^]f32)(uintptr(raw_data(data_original)) + 1)[:NUM_DATA]
	} else {
		data := make([]f32, NUM_DATA, context.temp_allocator)
	}

	for &x in data {
		x = rand.float32()
	}

	fmt.printfln("Sum (Scalar f32): %0.5f (%v)", benchmark(sum_scalar, data))
	fmt.printfln("Sum (SIMD f32): %0.5f (%v)", benchmark(sum_simd, data))
	fmt.printfln("Sum (Masked SIMD f32): %0.5f (%v)", benchmark(sum_simd_masked, data))
	fmt.printfln("Sum (Scalar f64): %0.5f (%v)", benchmark(sum_scalar_wide, data))
	fmt.printfln("Sum (SIMD f64): %0.5f (%v)", benchmark(sum_simd_wide, data))
}

benchmark :: proc (p: proc ([]f32) -> f32, s: []f32) -> (f32, time.Duration) {
	best_elapsed := max(time.Duration)
	result : f32
	for _ in 0..<NUM_REPETITIONS {
		start := time.tick_now()
		result = p(s)
		best_elapsed = min(time.tick_since(start), best_elapsed)
	}
	return result, best_elapsed
}

iota :: proc ($V: typeid/#simd[$N]$E) -> (result: V) {
	for i in 0..<N {
		result = simd.replace(result, i, E(i))
	}
	return
}

