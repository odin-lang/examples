package image_viewer

import "core:image"
import "core:image/png"

// Avoids 'unused import' error: "core:image/png" needs to be imported in order
// to make `img.load_from_bytes` understand PNG format.
_ :: png

import "core:fmt"

/*
This program prints:

	Long_Cat is 9 x 46 pixels and 183 bytes large
	
	Round_Cat is 20 x 24 pixels and 317 bytes large
	Round_Cat has width > 15 we loaded it!
	It is indeed 20 pixels wide!
	
	Tuna is 24 x 20 pixels and 318 bytes large
	Tuna has width > 15 we loaded it!
	It is indeed 24 pixels wide!

Note how it knows width and height before it loads the file. That was written
into `images.odin` by the code generation program in the `generate_image_info`
folder. It also knows the file size: `img.data` contains the data (i.e. the file
contents) for that image. That data is put into the executable at compile time
using the built-in `#load` procedure. The path of the image send into `#load`
is written by the code generation program.
*/
main :: proc() {
	for &img, name in images {
		fmt.printfln("%v is %v x %v pixels and %v bytes large", name, img.width, img.height, len(img.data))

		// Make decisions based pre-computed data before actually loading the image
		if img.width > 15 {
			loaded_img, loaded_img_err := image.load_from_bytes(img.data)

			if loaded_img_err == nil {
				fmt.printfln("%v has width > 15, so we loaded it!", name)
				fmt.printfln("The loaded PNG image is indeed %v pixels wide!", loaded_img.width)
			}
		}

		fmt.println()
	}
}