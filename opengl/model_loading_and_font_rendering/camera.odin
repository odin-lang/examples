package main

Camera :: struct {
	pos:     [3]f32,
	up:      [3]f32,
	forward: [3]f32,
	fov:     f32,
}

camera_new :: proc(pos: [3]f32 = {0, 1, 0}, up: [3]f32 = {0, 1, 0}, forward: [3]f32 = {0, 0, -1}, fov: f32 = 45) -> Camera {
	return Camera{
		pos     = pos,
		up      = up,
		forward = forward,
		fov     = fov,
	}
}
