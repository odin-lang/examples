package main

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"

print_file_info :: proc(fi: os.File_Info) {
	// Split the path into directory and filename
	_, filename := filepath.split(fi.fullpath)

	SIZE_WIDTH :: 12
	buf: [SIZE_WIDTH]u8

	// Print size to string backed by buf on stack, no need to free
	_size := "-" if fi.is_dir else fmt.bprintf(buf[:], "%v", fi.size)

	// Right-justify size for display, heap allocated
	size := strings.right_justify(_size, SIZE_WIDTH, " ")
	defer delete(size)

	if fi.is_dir {
		fmt.printf("%v [%v]\n", size, filename)
	} else {
		fmt.printf("%v %v\n", size, filename)
	}
}

main :: proc() {
	cwd := os.get_current_directory()
	fmt.println("Current working directory:", cwd)

	f, err := os.open(cwd)
	defer os.close(f)

	if err != os.ERROR_NONE {
		// Print error to stderr and exit with errorcode
		fmt.eprintln("Could not open directory for reading", err)
		os.exit(1)
	}

	fis: []os.File_Info
	defer os.file_info_slice_delete(fis) // fis is a slice, we need to remember to free it

	fis, err = os.read_dir(f, -1) // -1 reads all file infos
	if err != os.ERROR_NONE {
		fmt.eprintln("Could not read directory", err)
		os.exit(2)
	}

	for fi in fis {
		print_file_info(fi)
	}
}

