package hellobox

import "core:fmt"
import "vendor:box2d"

// Translation of https://box2d.org/documentation/hello.html


main :: proc() {
    
	// Create World
	world_def := box2d.DefaultWorldDef()
	world_def.gravity = [2]f32{0.0,-10.0}
	world_id := box2d.CreateWorld(world_def)

	// Create Ground
	ground_bodydef := box2d.DefaultBodyDef()
	ground_bodydef.position = box2d.Vec2{0.0,-10.0}
	ground_Id := box2d.CreateBody(world_id,ground_bodydef)
	// Create Body 

	ground_box := box2d.MakeBox(50.0,10.0)

	ground_shape_def := box2d.DefaultShapeDef()
	ground_polygon := box2d.CreatePolygonShape(ground_Id,ground_shape_def,ground_box)

	// create dynamic body
	body_def := box2d.DefaultBodyDef()
	body_def.type = box2d.BodyType.dynamicBody
	body_def.position = box2d.Vec2{0.0,4.0}
	body_id := box2d.CreateBody(world_id,body_def)

	dynamic_box := box2d.MakeBox(1.0,1.0)
	shape_def := box2d.DefaultShapeDef()
	// Reset friction and density
	shape_def.density = 1.0
	shape_def.material.friction = 0.3
	
	shape_body:=box2d.CreatePolygonShape(body_id,shape_def,dynamic_box)

	// simulation time step
	time_step := 1.0/60.0

	substep_count := 4

	// Keep handles for potential use
	// They are not needed explicitly, but the results will be wrong without them
	_ = ground_polygon
	_ = shape_body

	// Simulation steps
	for i:=0;i<90;i+=1 {
		box2d.World_Step(world_id,f32(time_step),i32(substep_count))
		pos := box2d.Body_GetPosition(body_id)
		rot := box2d.Body_GetRotation(body_id)
		
		fmt.printfln("%4.2f %4.2f %4.2f\n", pos.x, pos.y, box2d.Rot_GetAngle(rot))
    }
	box2d.DestroyWorld(world_id)

}
