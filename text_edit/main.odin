package main

/*
	core:text/edit example

	This core package provides procedures for implementing 
	text input fields. This is a simple example showcasing 
	how to create a single line text edit field.
*/

                          // Using the packages below for:
import rl "vendor:raylib" // - rendering and keyboard input
import "core:text/edit"   // - text editing logic
import "core:strings"     // - string builder and string to cstring conversion

FONT_SIZE :: 50

/* HELPER PROCEDURES */

/* NOT the same as IsKeyDown */
is_key_held :: proc(key: rl.KeyboardKey) -> bool {
	return rl.IsKeyPressed(key) || rl.IsKeyPressedRepeat(key)
}

is_ctrl_down :: proc() -> bool {
	return rl.IsKeyDown(.LEFT_CONTROL) || rl.IsKeyDown(.RIGHT_CONTROL)
}

is_shift_down :: proc() -> bool {
	return rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.RIGHT_SHIFT)
}

main :: proc() {
	/* Creating a window. */
	rl.InitWindow(1024, 800, "core:text/edit example")

	/* Initialising string builder
	   for dynamically creating strings
	   in runtime. */
	builder: strings.Builder
	strings.builder_init(&builder)

	/* This is the edit state. 
	   It stores information about current selection, caret position,
	   undo and redo arrays, and clipboard interface. */
	state: edit.State

	/* Initialise the edit state, we pass default allocator
	   for undo data */
	edit.init(&state, context.allocator, context.allocator)

	/* Before editing we need to tell the state that this is what we're editing.
	   Note that we're NOT calling it every frame (as in every loop iteration),
	   although the documentation might suggest otherwise. */
	edit.begin(&state, 1, &builder)

	/* Main loop */
	for !rl.WindowShouldClose() {
		/* Update the time for the state. Useful with undo operation. 
		   The state struct contains the information about the time since the last edit.
		   If it exceeds the timeout, it is then pushed to the undo array.
		   Default timeout is 300 ms. */
		edit.update_time(&state)

		if !is_ctrl_down() {
			/* Normal input */
			c := rl.GetCharPressed()

			/* NOTE: this skips the newline characters.
		             Depending on your goals (e.g. multiline field), 
					 you might want to change this condition to something else */
			if c >= rune(' ') {
				/* Input the rune into the state */
				edit.input_rune(&state, c)
			}
		} else { // Handle Ctrl+key combinations
			switch {
			case rl.IsKeyPressed(.Z): // undo
				edit.perform_command(&state, .Undo)
			case rl.IsKeyPressed(.Y): // redo
				edit.perform_command(&state, .Redo)
				/* WARN: the following commands require that you set
				         the clipboard procedures in the state struct.
				 	     In current implementation they don't work. */
			case rl.IsKeyPressed(.C): // copy
				edit.perform_command(&state, .Copy)
			case rl.IsKeyPressed(.V): // paste
				edit.perform_command(&state, .Paste)
			case rl.IsKeyPressed(.X): // cut
				edit.perform_command(&state, .Cut)
			}
		}
		
		/* Movement in the text field
		   - Shift + arrow expands the selection in the direction of the arrow
		   - Ctrl + arrow moves the caret to the next word
		   - Shift + Ctrl + arrow combines both operations */
		if is_key_held(.LEFT) {
			cmd := edit.Command.Left
			if is_shift_down() && is_ctrl_down() {
				cmd = .Select_Word_Left
			} else if is_ctrl_down() {
				cmd = .Word_Left
			} else if is_shift_down() {
				cmd = .Select_Left
			}
			edit.perform_command(&state, cmd)
		}
		
		if is_key_held(.RIGHT) {
			cmd := edit.Command.Right
			if is_shift_down() && is_ctrl_down() {
				cmd = .Select_Word_Right
			} else if is_ctrl_down() {
				cmd = .Word_Right
			} else if is_shift_down() {
				cmd = .Select_Right
			}
			edit.perform_command(&state, cmd)
		}

		/* Deleting characters. `Backspace` deletes before the caret, `Delete` after
		   - Ctrl + key deletes entire word in the respective direction */
		if is_key_held(.BACKSPACE) {
			cmd := edit.Command.Backspace
			if is_ctrl_down() {
				cmd = .Delete_Word_Left
			}
			edit.perform_command(&state, cmd)
		}

		if is_key_held(.DELETE) {
			cmd := edit.Command.Delete
			if is_ctrl_down() {
				cmd = .Delete_Word_Right
			}
			edit.perform_command(&state, cmd)
		}
		
		/* Our result string */
		str := strings.to_string(builder)

		/* raylib operates on cstrings, so we need to convert
		   our string from builder to a cstring */
		cstr := strings.to_cstring(&builder)

		/* This will be used for determining the position of the caret on screen. 
		   Note that for this demo we're using MeasureText, because we use the default
		   raylib font. If you want to use a different font, look into MeasureTextEx.*/
		substr := strings.clone_to_cstring(str[:state.selection[0]], context.temp_allocator)
		caret_x := rl.MeasureText(substr, FONT_SIZE)

		/* Calculate selection size */
		selection_str := str[:state.selection[1]]
		selection_cstr := strings.clone_to_cstring(selection_str, context.temp_allocator)
		selection_x := rl.MeasureText(selection_cstr, FONT_SIZE)

		/* The edit state stores the selection information as a 2-element array.
		   1st element (index 0) is the current caret position.
		   2nd element (index 1) marks the end of the selection.
		   If both elements are equal, then there's no selection.
		   Note that either element can be bigger than the other. This means that
		   we need to choose the lower element to start from, and then calculate
		   the width as the absolute value of the difference. */

		/* Main drawing section
		   Keep that in mind if you're learning raylib, because without it, your program will freeze! */
		rl.BeginDrawing()
		rl.ClearBackground(rl.WHITE)

		rl.DrawText("core:text/edit example", 20, 20, 20, rl.RED)

		rl.DrawRectangle(0, 340, 1024, 70, rl.LIGHTGRAY) // background
		if edit.has_selection(&state) {                  // selection
			rl.DrawRectangle(caret_x if caret_x < selection_x else selection_x, // ternary expression! equivalent to
                             340, 												// caret_x < selection_x ? caret_x : selection_x
                             abs(selection_x - caret_x), 
                             70,
                             rl.SKYBLUE)
		}
		rl.DrawText(cstr, 0, 350, FONT_SIZE, rl.RED)     // text
		rl.DrawLine(caret_x, 350, caret_x, 400, rl.RED)  // caret
			
		rl.EndDrawing()
	}
	/* We call this procedure to signal that we're done editing
	   that input field */
	edit.end(&state)

	/* At the end of the program, release the resources allocated at the start */
	edit.destroy(&state)

	/* Finally, close window */
	rl.CloseWindow()
}
