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
	Tuna is 24 x 20 pixels and 318 bytes large

Note how it knows the size: `img.data` contains the data! It is loaded at
compile time. The information about the width and height and which file to
actually load is determined by the code generation program in the
`generate_image_info` folder.
*/
main :: proc() {
	for &img, name in images {
		fmt.printfln("%v is %v x %v pixels and %v bytes large", name, img.width, img.height, len(img.data))

		// Make decisions based pre-computed data before actually loading the image
		if img.width > 15 {
			loaded_img, loaded_img_err := image.load_from_bytes(img.data)

			if loaded_img_err == nil {
				fmt.printfln("%v has width > 15 we loaded it!", name)
				fmt.printfln("It is indeed %v pixels wide!", loaded_img.width)
			}
		}

		fmt.println()
	}
}