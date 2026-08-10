package text_edit_example

/*********************************************************************
                        SINGLE LINE TEXT FIELD
                            (using raylib)

 A minimal editable text field. `core:text/edit` supplies the editing
 logic -- caret movement, selection, undo/redo, clipboard -- and raylib
 supplies the window, the input events and the drawing.

 You can
 * Type to insert text
 * Click to place the caret
 * Press <Left>/<Right> to move the caret, hold <Shift> to select
 * Press <Ctrl+Left>/<Ctrl+Right> to move a whole word
 * Press <Home>/<End> to jump to either end
 * Press <Backspace>/<Delete> to erase
 * Press <Ctrl+A> to select all, <Ctrl+C>/<Ctrl+X>/<Ctrl+V> to copy/cut/paste
 * Press <Ctrl+Z> to undo, <Ctrl+Y> to redo
 * Press <Esc> to close the window

 The field moves the caret by grapheme cluster, so a letter followed by
 a combining mark counts as one character even though it is two runes.
 Paste something like "e" + U+0301 in to see it: the caret steps over
 both at once. raylib's default font has no glyph for the combining
 mark or most non-ASCII letters, so those draw as missing-glyph boxes,
 but the caret and selection still land in the right place.

**********************************************************************/

import "core:strings"
import "core:text/edit"
import "core:unicode/utf8"
import rl "vendor:raylib"

WINDOW_WIDTH  :: 800
WINDOW_HEIGHT :: 200

FONT_SIZE      :: 30
FONT_SPACING   :: 2
HINT_FONT_SIZE :: 20

FIELD_PADDING :: 10
FIELD_X       :: 40
FIELD_Y       :: 80
FIELD_W       :: WINDOW_WIDTH - 2 * FIELD_X
FIELD_H       :: FONT_SIZE + 2 * FIELD_PADDING

TEXT_X :: FIELD_X + FIELD_PADDING
TEXT_Y :: FIELD_Y + FIELD_PADDING
HINT_Y :: 40

CARET_WIDTH      :: 2
CARET_BLINK_RATE :: 0.5

COLOR_BACKGROUND :: rl.Color{ 30,  30,  35, 255}
COLOR_FIELD      :: rl.Color{ 20,  20,  24, 255}
COLOR_BORDER     :: rl.Color{ 90,  90, 100, 255}
COLOR_SELECTION  :: rl.Color{ 60,  90, 150, 255}
COLOR_HINT       :: rl.Color{140, 140, 150, 255}

Key_Binding :: struct {
	key:   rl.KeyboardKey,
	ctrl:  bool,
	shift: bool,
	cmd:   edit.Command,
}

// `core:text/edit` has no opinion on which key does what, so the example picks
// the usual bindings. The modifiers have to match exactly, which is what keeps
// <Ctrl+Left> from also triggering the plain <Left> binding.
KEY_BINDINGS :: []Key_Binding{
	{.LEFT,      false, false, .Left},
	{.LEFT,      false, true,  .Select_Left},
	{.LEFT,      true,  false, .Word_Left},
	{.LEFT,      true,  true,  .Select_Word_Left},
	{.RIGHT,     false, false, .Right},
	{.RIGHT,     false, true,  .Select_Right},
	{.RIGHT,     true,  false, .Word_Right},
	{.RIGHT,     true,  true,  .Select_Word_Right},
	{.HOME,      false, false, .Start},
	{.HOME,      false, true,  .Select_Start},
	{.END,       false, false, .End},
	{.END,       false, true,  .Select_End},
	{.BACKSPACE, false, false, .Backspace},
	{.BACKSPACE, true,  false, .Delete_Word_Left},
	{.DELETE,    false, false, .Delete},
	{.DELETE,    true,  false, .Delete_Word_Right},
	{.A,         true,  false, .Select_All},
	{.C,         true,  false, .Copy},
	{.X,         true,  false, .Cut},
	{.V,         true,  false, .Paste},
	{.Z,         true,  false, .Undo},
	{.Y,         true,  false, .Redo},
}

main :: proc() {
	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "core:text/edit text field")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)

	font := rl.GetFontDefault()

	// `core:text/edit` never owns the text: it edits a `strings.Builder` that
	// the caller keeps. Anything can read the current contents at any time by
	// looking at the builder.
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	strings.write_string(&builder, "Edit me!")

	state: edit.State
	edit.init(&state, context.allocator, context.allocator)
	defer edit.destroy(&state)

	// `setup_once` binds the builder and keeps the selection across frames.
	// (`edit.begin`/`edit.end` are for immediate mode GUIs, where a field is
	// only the focused one for the duration of a frame.)
	edit.setup_once(&state, &builder)

	// Without this the caret moves by codepoint, which would step into the
	// middle of a multi-rune character.
	state.translate_by_grapheme = true

	state.set_clipboard = proc(_: rawptr, text: string) -> bool {
		rl.SetClipboardText(strings.clone_to_cstring(text, context.temp_allocator))
		return true
	}
	state.get_clipboard = proc(_: rawptr) -> (text: string, ok: bool) {
		cstr := rl.GetClipboardText()
		return string(cstr), cstr != nil
	}

	for !rl.WindowShouldClose() {
		defer free_all(context.temp_allocator)

		handle_input(&state, font)

		// Read the text only once this frame's editing is done. Reading it any
		// earlier leaves a slice of the buffer as it used to be, which stops
		// matching the selection as soon as anything is typed.
		text := strings.to_string(builder)

		draw(&state, font, text)
	}
}

handle_input :: proc(state: ^edit.State, font: rl.Font) {
	// The undo system groups edits that happen close together in time, so it
	// needs to be told what "now" is before any editing happens.
	edit.update_time(state)

	for r := rl.GetCharPressed(); r != 0; r = rl.GetCharPressed() {
		edit.input_rune(state, r)
	}

	ctrl  := rl.IsKeyDown(.LEFT_CONTROL) || rl.IsKeyDown(.RIGHT_CONTROL)
	shift := rl.IsKeyDown(.LEFT_SHIFT)   || rl.IsKeyDown(.RIGHT_SHIFT)

	for binding in KEY_BINDINGS {
		// `IsKeyPressedRepeat` is what makes a held down key keep firing.
		pressed := rl.IsKeyPressed(binding.key) || rl.IsKeyPressedRepeat(binding.key)
		if pressed && binding.ctrl == ctrl && binding.shift == shift {
			edit.perform_command(state, binding.cmd)
		}
	}

	if rl.IsMouseButtonPressed(.LEFT) {
		caret := caret_at(font, strings.to_string(state.builder^), rl.GetMousePosition().x)
		state.selection = {caret, caret}
	}
}

draw :: proc(state: ^edit.State, font: rl.Font, text: string) {
	rl.BeginDrawing()
	defer rl.EndDrawing()

	rl.ClearBackground(COLOR_BACKGROUND)

	field := rl.Rectangle{FIELD_X, FIELD_Y, FIELD_W, FIELD_H}
	rl.DrawRectangleRec(field, COLOR_FIELD)
	rl.DrawRectangleLinesEx(field, 2, COLOR_BORDER)

	// The selection is drawn behind the text. `sorted_selection` puts the two
	// ends in left to right order, because `selection[0]` is the moving end and
	// can sit on either side of the anchor.
	if lo, hi := edit.sorted_selection(state); lo != hi {
		lo_x := TEXT_X + text_width(font, text[:lo])
		hi_x := TEXT_X + text_width(font, text[:hi])
		rl.DrawRectangleRec({lo_x, TEXT_Y, hi_x - lo_x, FONT_SIZE}, COLOR_SELECTION)
	}

	rl.DrawTextEx(font, strings.clone_to_cstring(text, context.temp_allocator),
	              {TEXT_X, TEXT_Y}, FONT_SIZE, FONT_SPACING, rl.RAYWHITE)

	if int(rl.GetTime() / CARET_BLINK_RATE) % 2 == 0 {
		caret_x := TEXT_X + text_width(font, text[:state.selection[0]])
		rl.DrawRectangleRec({caret_x, TEXT_Y, CARET_WIDTH, FONT_SIZE}, rl.RAYWHITE)
	}

	rl.DrawTextEx(font, "Type to edit. Arrows move, Shift selects, Ctrl+Z undoes.",
	              {FIELD_X, HINT_Y}, HINT_FONT_SIZE, FONT_SPACING, COLOR_HINT)
}

text_width :: proc(font: rl.Font, text: string) -> f32 {
	cstr := strings.clone_to_cstring(text, context.temp_allocator)
	return rl.MeasureTextEx(font, cstr, FONT_SIZE, FONT_SPACING).x
}

// Find the grapheme boundary closest to `mouse_x`. Walking the grapheme clusters
// rather than the bytes is what stops a click from dropping the caret inside a
// multi-rune character.
//
// Every candidate is measured from the start of the text rather than by adding
// up cluster widths, because the spacing between glyphs belongs to neither of
// the two clusters it sits between.
caret_at :: proc(font: rl.Font, text: string, mouse_x: f32) -> (caret: int) {
	best := abs(TEXT_X - mouse_x)

	it := utf8.decode_grapheme_iterator_make(text)
	for _, grapheme in utf8.decode_grapheme_iterate(&it) {
		end := grapheme.byte_index + len(grapheme.text)
		if distance := abs(TEXT_X + text_width(font, text[:end]) - mouse_x); distance < best {
			caret, best = end, distance
		}
	}
	return
}
