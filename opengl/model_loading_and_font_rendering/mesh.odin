package main
import "core:log"
import "vendor:cgltf"
import gl "vendor:OpenGL"

Mesh :: struct {
	vao: u32,
	vbo: u32,
	ebo: u32,
	num_indices: i32,
}

Primitive :: enum {
	Plane,
	Cube,
}

mesh_new :: proc(verts: []f32, indices: []u32) -> Mesh {
	mesh := Mesh{}
	mesh.num_indices = i32(len(indices))
	gl.GenVertexArrays(1, &mesh.vao)
	gl.BindVertexArray(mesh.vao)
	gl.GenBuffers(1, &mesh.vbo)
	gl.GenBuffers(1, &mesh.ebo)
	gl.BindBuffer(gl.ARRAY_BUFFER, mesh.vbo)
	gl.BufferData(gl.ARRAY_BUFFER, size_of(f32) * len(verts), raw_data(verts), gl.STATIC_DRAW)
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, mesh.ebo)
	gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(f32) * len(indices), raw_data(indices), gl.STATIC_DRAW)
	// Specify how to interpret vertex data (position)
	gl.EnableVertexAttribArray(0)
	gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 8 * size_of(f32), 0)
	// Specify how to interpret vertex data (normals)
	gl.EnableVertexAttribArray(1)
	gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 8 * size_of(f32), 3 * size_of(f32))
	// Specify how to interpret vertex data (texture coords)
	gl.EnableVertexAttribArray(2)
	gl.VertexAttribPointer(2, 2, gl.FLOAT, gl.FALSE, 8 * size_of(f32), 6 * size_of(f32))
	gl.BindVertexArray(0)
	return mesh
}

mesh_destroy :: proc(mesh: ^Mesh) {
	gl.DeleteVertexArrays(1, &mesh.vao)
	gl.DeleteBuffers(1, &mesh.vbo)
	gl.DeleteBuffers(1, &mesh.ebo)
}

mesh_load_primitives :: proc(primitives: ^[Primitive]Mesh) {
	for primitive in Primitive {
		switch primitive {
		case .Plane:
			verts := [?]f32 {
				// Vertex coords:    Normals:            Texture coords:
				-0.5,  0.0,  0.5,    0.0,  1.0,  0.0,    0.0, 1.0,
				 0.5,  0.0,  0.5,    0.0,  1.0,  0.0,    1.0, 1.0,
				-0.5,  0.0, -0.5,    0.0,  1.0,  0.0,    0.0, 0.0,
				 0.5,  0.0, -0.5,    0.0,  1.0,  0.0,    1.0, 0.0,
			}
			indices := [?]u32 {
				0, 1, 2,
				2, 1, 3,
			}
			primitives[.Plane] = mesh_new(verts[:], indices[:])
		case .Cube:
			verts := [?]f32 {
				// Vertex coords:    Normals:            Texture coords:
				// Front face
				-0.5,  0.5,  0.5,    0.0,  0.0,  1.0,    0.0, 1.0,
				 0.5,  0.5,  0.5,    0.0,  0.0,  1.0,    1.0, 1.0,
				-0.5, -0.5,  0.5,    0.0,  0.0,  1.0,    0.0, 0.0,
				 0.5, -0.5,  0.5,    0.0,  0.0,  1.0,    1.0, 0.0,
				// Rear face
				 0.5,  0.5, -0.5,    0.0,  0.0, -1.0,    0.0, 1.0,
				-0.5,  0.5, -0.5,    0.0,  0.0, -1.0,    1.0, 1.0,
				 0.5, -0.5, -0.5,    0.0,  0.0, -1.0,    0.0, 0.0,
				-0.5, -0.5, -0.5,    0.0,  0.0, -1.0,    1.0, 0.0,
				// Left face
				-0.5,  0.5, -0.5,   -1.0,  0.0,  0.0,    0.0, 1.0,
				-0.5,  0.5,  0.5,   -1.0,  0.0,  0.0,    1.0, 1.0,
				-0.5, -0.5, -0.5,   -1.0,  0.0,  0.0,    0.0, 0.0,
				-0.5, -0.5,  0.5,   -1.0,  0.0,  0.0,    1.0, 0.0,
				// Right face
				 0.5,  0.5,  0.5,    1.0,  0.0,  0.0,    0.0, 1.0,
				 0.5,  0.5, -0.5,    1.0,  0.0,  0.0,    1.0, 1.0,
				 0.5, -0.5,  0.5,    1.0,  0.0,  0.0,    0.0, 0.0,
				 0.5, -0.5, -0.5,    1.0,  0.0,  0.0,    1.0, 0.0,
				// Top face
				-0.5,  0.5, -0.5,    0.0,  1.0,  0.0,    0.0, 1.0,
				 0.5,  0.5, -0.5,    0.0,  1.0,  0.0,    1.0, 1.0,
				-0.5,  0.5,  0.5,    0.0,  1.0,  0.0,    0.0, 0.0,
				 0.5,  0.5,  0.5,    0.0,  1.0,  0.0,    1.0, 0.0,
				// Bottom face
				-0.5, -0.5,  0.5,    0.0, -1.0,  0.0,    0.0, 1.0,
				 0.5, -0.5,  0.5,    0.0, -1.0,  0.0,    1.0, 1.0,
				-0.5, -0.5, -0.5,    0.0, -1.0,  0.0,    0.0, 0.0,
				 0.5, -0.5, -0.5,    0.0, -1.0,  0.0,    1.0, 0.0,
			}
			indices := [?]u32 {
				// Front face
				 0,  2,  1,
				 1,  2,  3,
				// Rear face
				 4,  6,  5,
				 5,  6,  7,
				// Left face
				 8, 10,  9,
				 9, 10, 11,
				// Right face
				12, 14, 13,
				13, 14, 15,
				// Top face
				16, 18, 17,
				17, 18, 19,
				// Top face
				20, 22, 21,
				21, 22, 23,
			}
			primitives[.Cube] = mesh_new(verts[:], indices[:])
		}
	}
}

mesh_gltf_load ::proc(meshes: ^[dynamic]Mesh, path: cstring) {
	// Load gltf file
	options: cgltf.options
	data, result := cgltf.parse_file(options, path)
	if result != .success {
		log.panic("cgltf file parsing failed.")
	}
	// Load buffers from gltf file
	result = cgltf.load_buffers(options, data, path)
	if result != .success {
		log.panic("cgltf buffer loading failed.")
	}
	// Select mesh and primitive
	for mesh in data.meshes {
		for primitive in mesh.primitives {
			// Read indices
			index_accessor := primitive.indices
			num_indices := index_accessor.count
			indices := make([dynamic]u32, num_indices)
			if cgltf.accessor_unpack_indices(index_accessor, raw_data(indices), uint(size_of(u32)), num_indices) < uint(num_indices) {
				log.panic("cgltf vertex index reading failed.")
			}
			// Find vertex position attribute
			pos_accessor: ^cgltf.accessor
			for attrib in primitive.attributes {
				if attrib.type == .position {
					pos_accessor = attrib.data
					break
				}
			}
			if pos_accessor == nil {
				log.panic("cgltf position attribute not found.")
			}
			// Find vertex normal attribute
			normal_accessor: ^cgltf.accessor
			for attrib in primitive.attributes {
				if attrib.type == .normal {
					normal_accessor = attrib.data
					break
				}
			}
			if normal_accessor == nil {
				log.panic("cgltf normal attribute not found.")
			}
			// Find vertex texture coordinate attribute
			texcoord_accessor: ^cgltf.accessor
			for attrib in primitive.attributes {
				if attrib.type == .texcoord {
					texcoord_accessor = attrib.data
					break
				}
			}
			if texcoord_accessor == nil {
				log.panic("cgltf texcoord attribute not found.")
			}
			// Read vertices
			num_verts := pos_accessor.count
			verts := make([dynamic]f32, num_verts * 8)
			for i in 0..< num_verts {
				// Read vertex positions
				if !cgltf.accessor_read_float(pos_accessor, i, &verts[i * 8], 3) {
					log.panic("cgltf vertex position reading failed.")
				}
				// Read vertex normals
				if !cgltf.accessor_read_float(normal_accessor, i, &verts[i * 8 + 3], 3) {
					log.panic("cgltf vertex normal reading failed.")
				}
				// Read vertex texture coordinates
				if i < 10 && !cgltf.accessor_read_float(texcoord_accessor, i, &verts[i * 8 + 3 + 3], 2) {
					log.panic("cgltf vertex texture coordinates reading failed.")
				}
			}
			// Assign mesh to map of meshes
			append(meshes, mesh_new(verts[:], indices[:]))
			// Free allocated memory
			delete(verts)
			delete(indices)
		}
	}
	cgltf.free(data)
}
