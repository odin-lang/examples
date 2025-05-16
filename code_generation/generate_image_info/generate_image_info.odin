/*
This program generates `images.odin` by going through the `images` folder and
opening each file. From each PNG file in there it will:

- Generate a pretty enum name for it
- Make a list of images where it maps each pretty enum name to an Image struct
- The Image struct contains the width and the height. This is determined by
    opening the PNG files.
- The Image struct also contains a `data = #load(THE_FILENAME)` field. That will
    make the compiler that later tries to compile `images.odin` load the file
    data at compile-time.
*/
package generate_image_info

import "core:os"
import "core:strings"
import "core:fmt"
import "core:path/slashpath"
import "core:image/png"
import "core:image"

// Avoids 'unused import' error: "core:image/png" needs to be imported in order
// to make `img.load_from_bytes` understand PNG format.
_ :: png

INPUT_DIR :: "images"
OUTPUT_FILE :: "images.odin"

main :: proc() {
	d, d_err := os.open(INPUT_DIR, os.O_RDONLY)
	assert(d_err == nil, "Failed opening '" + INPUT_DIR + "' folder")
	defer os.close(d)

	input_files, _ := os.read_dir(d, -1)

	f, _ := os.open(OUTPUT_FILE, os.O_WRONLY | os.O_CREATE | os.O_TRUNC, 0o644)
	defer os.close(f)

	images: [dynamic]os.File_Info

	for i in input_files {
		if !strings.has_suffix(i.name, ".png") {
			continue
		}

		append(&images, i)
	}

	fmt.fprintln(f,
`// This file is generated. Re-generate it by running:
//	odin run generate_image_info
package image_viewer

Image :: struct {
	width: int,
	height: int,
	data: []u8,
}

Image_Name :: enum {`,
)

	for i in images {
		fmt.fprintfln(f, "	%v,", strings.to_ada_case(slashpath.name(i.name)))
	}

	fmt.fprintln(f,
`}

images := [Image_Name]Image {`,
)

	for i in images {
		img, img_err := image.load_from_file(i.fullpath)

		if img_err == nil {
			enum_name := strings.to_ada_case(slashpath.name(i.name))
			fmt.fprintfln(f, "	.%v = {{ data = #load(\"images/%v\"), width = %v, height = %v }},", enum_name, i.name, img.width, img.height)
		}
	}

	fmt.fprintln(f, "}")
}