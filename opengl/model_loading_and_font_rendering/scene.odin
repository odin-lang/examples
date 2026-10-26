package main

Scene :: enum {
	Default,
}

load_scene :: proc(app: ^App, scene: Scene) {
	// Set ambient light
	app.ambient_light = 0.05
	
	// Load meshes
	mesh_gltf_load(&app.meshes, "./assets/logo.glb")
	
	// Materials
	append(&app.materials, material_new(
		color = {0.5, 0.5, 0.5},
		shininess = 32.0,
	))

	// Models
	append(&app.models, model_new(
		mesh     = &app.meshes[0],
		material = &app.materials[0],
		pos      = {0, 1, -5},
		scale    = 0.75,
	))
	append(&app.models, model_new(
		mesh     = &app.primitives[.Plane],
		material = &app.materials[0],
		pos      = {2, 0, 0},
		scale    = 100,
	))
}
