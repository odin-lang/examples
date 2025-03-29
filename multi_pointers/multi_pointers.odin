package multi_pointers

import "core:fmt"
import "core:slice"
import "core:c/libc"

main :: proc() {
	// overview: 
	// a multi pointer is just a regular pointer with syntactic sugar that llows you to index into a buffer or array
	// multi-pointer indicates that we are dealing with a pointer to a buffer, not just a single object
	// in odin a regular pointer cannot be indexed 
	
	// multi-pointer declaration
	mptr: [^]int

	// multi-pointer pointing to the first element of a static array
	arr: [8]int = {0, 1, 2, 3, 4, 5, 6, 7}
	mptr = &arr[0]
	fmt.println(mptr)

	// casting multi-pointer to regular pointer
	ptr := cast(^int) mptr
	fmt.println(ptr)
	// implicit cast works too
	ptr_implicit := mptr
	fmt.println(ptr_implicit)

	// this is not allowed
	// ptr[3]

	// but this is allowed, it indexes element at the 3rd index via the multi-pointer
	mptr[3] = 5
	fmt.println(mptr[3])

	// remember to not access outside the array using a multi-pointer
	// mptr[10]

	// differentiating slices, pointers to slices and multi-pointers
	{
		// this is a slice
		just_a_slice: []int = {1, 2, 3}
		
		// this is a pointer to a slice and not a multi-pointer
		sliceptr: ^[]int = &just_a_slice
		fmt.println(sliceptr)
	
		// a multi-pointer doesnt store length like a slice does
		#assert(size_of([^]int) == 8)   // just a pointer with array sugar
		#assert(size_of(^[]int) == 8)   // just a pointer to a slice
		#assert(size_of([]int) == 16)   // just a slice, pointer + length
	}

	// multi-pointer args/returns in c libs indicate we are passing/returning a buffer
	{
		greet: cstring = "hellope"
		copied_greet: [8]byte
		// first arg implicitly casted from ^byte to [^]byte, also returns the pointer to the copy
		ret: [^]byte = libc.strncpy(&copied_greet[0], greet, len(copied_greet))

		fmt.println(cast(cstring) &copied_greet[0])
		fmt.println(cast(cstring) ret)
	}
	
	// constructing a slice from a multi-pointer and length
	{
		known_length := 8
		
		// implicitly casted from [^]int to ^int
		created_slice := slice.from_ptr(mptr, known_length)
		fmt.println(created_slice)

		another_created_slice := mptr[0:known_length]
		fmt.println(another_created_slice)
	}

	// multi-pointers are great for getting an offset into a buffer of data
	{
		Example_Struct :: struct {
			value1: u32,
			value2: u32,
		}

		data := [4]Example_Struct{
			{42, 420},
			{69, 690},
			{121, 156},
			{128, 255},
		}

		data_mptr: [^]Example_Struct = &data[0]
		byte_data_mptr := cast([^]byte) &data[0]

		fmt.println(data_mptr[3].value1, data_mptr[3].value2)
		fmt.println(byte_data_mptr[:4 * size_of(Example_Struct)])
	}
}