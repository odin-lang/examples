// This file is generated. Re-generate it by running:
//	odin run generate_image_info
package image_viewer

Image :: struct {
	width: int,
	height: int,
	data: []u8,
}

Image_Name :: enum {
	Long_Cat,
	Round_Cat,
	Tuna,
}

images := [Image_Name]Image {
	.Long_Cat = { data = #load("images/long_cat.png"), width = 9, height = 46 },
	.Round_Cat = { data = #load("images/round_cat.png"), width = 20, height = 24 },
	.Tuna = { data = #load("images/tuna.png"), width = 24, height = 20 },
}
