package main

Material :: struct {
	shininess: f32,
	color:     [3]f32,
}

material_new :: proc(color: [3]f32 = 1, shininess: f32 = 0) -> Material {
	return Material{
		color = color,
		shininess = shininess,
	}
}

