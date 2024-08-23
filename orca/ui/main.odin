package src

/*
Original Source: https://github.com/orca-app/orca/blob/main/samples/ui/src/main.c

Can be run using in the local folder
1. odin.exe build main.odin -file -target:orca_wasm32 -out:module.wasm 
2. orca bundle --name orca_output --resource-dir data module.wasm
3. orca_output\bin\orca_output.exe
*/

import "core:log"
import "base:runtime"
import "core:fmt"
import oc "core:sys/orca"

ctx: runtime.Context

frameSize := oc.vec2{1200, 838}

surface: oc.surface
renderer: oc.canvas_renderer
canvas: oc.canvas_context
fontRegular: oc.font
fontBold: oc.font
ui: oc.ui_context
textArena: oc.arena
logArena: oc.arena
logLines: oc.str8_list

// NOTE(Skytrias): global instead of statics because of odin
labelFont: ^oc.font

cmd :: enum {
	NONE,
	SET_DARK_THEME,
	SET_LIGHT_THEME,
}

command := cmd.NONE

main :: proc() {
	context.logger = oc.create_odin_logger()
	ctx = context

	oc.window_set_title("Orca UI Demo")
	oc.window_set_size(frameSize)

	renderer = oc.canvas_renderer_create()
	surface = oc.canvas_surface_create(renderer)
	canvas = oc.canvas_context_create()
	oc.ui_init(&ui)

	fonts := [2]^oc.font{&fontRegular, &fontBold}
	fontNames := [2]string{"/OpenSans-Regular.ttf", "/OpenSans-Bold.ttf"}
	for i in 0 ..< len(fontNames) {
		scratch := oc.scratch_begin()

		file := oc.file_open(fontNames[i], {.READ}, {})
		if oc.file_last_error(file) != .OK {
			log.errorf("Couldn't open file %s\n", fontNames[i])
		}
		size := oc.file_size(file)
		buffer := cast([^]byte)oc.arena_push(scratch.arena, size)
		oc.file_read(file, size, buffer)
		oc.file_close(file)
		ranges := [?]oc.unicode_range {
			oc.UNICODE_BASIC_LATIN,
			oc.UNICODE_C1_CONTROLS_AND_LATIN_1_SUPPLEMENT,
			oc.UNICODE_LATIN_EXTENDED_A,
			oc.UNICODE_LATIN_EXTENDED_B,
			oc.UNICODE_SPECIALS,
		}

		fonts[i]^ = oc.font_create_from_memory(oc.str8_from_buffer(size, buffer), 5, &ranges[0])
		oc.scratch_end(scratch)
	}
	labelFont = &fontRegular

	oc.arena_init(&textArena)
	oc.arena_init(&logArena)
	oc.list_init(&logLines.list)
}

@(export)
oc_on_raw_event :: proc "c" (event: ^oc.event) {
	oc.ui_process_event(event)
}

@(export)
oc_on_resize :: proc "c" (width, height: u32) {
	frameSize.x = f32(width)
	frameSize.y = f32(height)
}

log_push :: proc(line: string) {
	oc.str8_list_push(&logArena, &logLines, line)
}

log_pushf :: proc(format: string, args: ..any) {
	str := fmt.tprintf(format, ..args)
	oc.str8_list_push(&logArena, &logLines, str)
}

column_begin :: proc(header: string, widthFraction: f32) {
	style := oc.ui_style {
		size = {{.PARENT, widthFraction, 1, 0}, {.PARENT, 1, 0, 0}},
		layout = {axis = .Y, margin = {0, 8}, spacing = 24},
		bgColor = ui.theme.bg1,
		borderColor = ui.theme.border,
		borderSize = 1,
		roundness = ui.theme.roundnessSmall,
	}

	style_mask :=
		oc.SIZE +
		{
				.LAYOUT_AXIS,
				.LAYOUT_MARGIN_Y,
				.LAYOUT_SPACING,
				.BG_COLOR,
				.BORDER_COLOR,
				.BORDER_SIZE,
				.ROUNDNESS,
			}

	oc.ui_style_next(style, style_mask)
	oc.ui_box_begin_str8(header, {.DRAW_BACKGROUND, .DRAW_BORDER})

	{
		style = oc.ui_style {
			size = {{.PARENT, 1, 0, 0}, {}},
			layout = {align = {.CENTER, .START}},
		}
		oc.ui_style_next(style, {.SIZE_WIDTH, .LAYOUT_ALIGN_X})
		oc.ui_container("header", {})

		oc.ui_style_next({fontSize = 18}, {.FONT_SIZE})
		oc.ui_label_str8(header)
	}

	style = {
		size = {{.PARENT, 1, 0, 0}, {.PARENT, 1, 1, 0}},
		layout = {align = {.START, .START}, margin = {16, 0}, spacing = 24},
	}
	oc.ui_style_next(style, oc.SIZE + {.LAYOUT_ALIGN_X, .LAYOUT_MARGIN_X, .LAYOUT_SPACING})
	oc.ui_box_begin_str8("contents", {})
}

column_end :: proc() {
	oc.ui_box_end() // contents
	oc.ui_box_end() // column
}

@(deferred_none = column_end)
column :: proc(header: string, widthFraction: f32) {
	column_begin(header, widthFraction)
}

labeled_slider :: proc(label: string, value: ^f32) {
	oc.ui_style_next({layout = {axis = .X, spacing = 8}}, {.LAYOUT_AXIS, .LAYOUT_SPACING})
	oc.ui_container(label, {})

	oc.ui_style_match_after(
		oc.ui_pattern_owner(),
		{size = {{.PIXELS, 100, 0, 0}, {}}},
		{.SIZE_WIDTH},
	)
	oc.ui_label_str8(label)

	oc.ui_style_next({size = {{.PIXELS, 100, 0, 0}, {}}}, {.SIZE_WIDTH})
	oc.ui_slider("slider", value)
}

// reset_next_radio_group_to_dark_theme :: (oc.arena* arena)

@(export)
oc_on_frame_refresh :: proc "c" () {
	context = ctx

	scratch := oc.scratch_begin()

	#partial switch command {
	case .SET_DARK_THEME:
		oc.ui_set_theme(&oc.UI_DARK_THEME)
	case .SET_LIGHT_THEME:
		oc.ui_set_theme(&oc.UI_LIGHT_THEME)
	}
	command = .NONE

	defaultStyle := oc.ui_style {
		font = fontRegular,
	}
	{
		oc.ui_frame(frameSize, defaultStyle, {.FONT})
		//--------------------------------------------------------------------------------------------
		// Menu bar
		//--------------------------------------------------------------------------------------------
		{
			oc.ui_menu_bar("menu_bar")

			{
				oc.ui_menu("File")
				if oc.ui_menu_button("Quit").pressed {
					oc.request_quit()
				}
			}

			{
				oc.ui_menu("Theme")
				if oc.ui_menu_button("Dark theme").pressed {
					command = .SET_DARK_THEME
				}
				if oc.ui_menu_button("Light theme").pressed {
					command = .SET_LIGHT_THEME
				}
			}
		}

		{
			oc.ui_panel("main panel", {})
			oc.ui_style_next(
				{
					size = {{.PARENT, 1, 0, 0}, {.PARENT, 1, 1, 0}},
					layout = {axis = .X, margin = 16, spacing = 16},
				},
				oc.SIZE + oc.LAYOUT_MARGINS + {.LAYOUT_AXIS, .LAYOUT_SPACING},
			)

			{
				oc.ui_container("background", {.DRAW_BACKGROUND})
				{
					column("Widgets", f32(1.0) / 3)

					{
						oc.ui_style_next(
							{size = {{.PARENT, 1, 0, 0}, {}}, layout = {axis = .X, spacing = 32}},
							{.SIZE_WIDTH, .LAYOUT_AXIS, .LAYOUT_SPACING},
						)
						oc.ui_container("top", {})

						{
							oc.ui_style_next(
								{layout = {axis = .Y, spacing = 24}},
								{.LAYOUT_AXIS, .LAYOUT_SPACING},
							)
							oc.ui_container("top_left", {})

							//-----------------------------------------------------------------------------
							// Label
							//-----------------------------------------------------------------------------
							oc.ui_label("Label")

							//-----------------------------------------------------------------------------
							// Button
							//-----------------------------------------------------------------------------
							if oc.ui_button("Button").clicked {
								log_push("Button clicked")
							}

							oc.ui_style_next(
								{layout = {axis = .X, align = {{}, .CENTER}, spacing = 8}},
								{.LAYOUT_AXIS, .LAYOUT_ALIGN_Y, .LAYOUT_SPACING},
							)

							{
								oc.ui_container("checkbox", {})

								//-------------------------------------------------------------------------
								// Checkbox
								//-------------------------------------------------------------------------
								@(static)
								checked := false
								if oc.ui_checkbox("checkbox", &checked).clicked {
									if checked {
										log_push("Checkbox checked")
									} else {
										log_push("Checkbox unchecked")
									}
								}

								oc.ui_label("Checkbox")
							}
						}

						//---------------------------------------------------------------------------------
						// Vertical slider
						//---------------------------------------------------------------------------------
						@(static)
						vSliderValue := f32(0)
						@(static)
						vSliderLoggedValue := f32(0)
						@(static)
						vSliderLogTime := f64(0)
						oc.ui_style_next({size = {{}, {.PIXELS, 130, 0, 0}}}, {.SIZE_HEIGHT})
						oc.ui_slider("v_slider", &vSliderValue)
						now := oc.clock_time(.MONOTONIC)
						if (now - vSliderLogTime) >= 0.2 && vSliderValue != vSliderLoggedValue {
							log_pushf("Vertical slider moved to %f", vSliderValue)
							vSliderLoggedValue = vSliderValue
							vSliderLogTime = now
						}

						{
							oc.ui_style_next(
								{layout = {axis = .Y, spacing = 24}},
								{.LAYOUT_AXIS, .LAYOUT_SPACING},
							)
							oc.ui_container("top_right", {})

							//-----------------------------------------------------------------------------
							// Tooltip
							//-----------------------------------------------------------------------------
							if oc.ui_label("Tooltip").hovering {
								oc.ui_tooltip("Hi")
							}

							//-----------------------------------------------------------------------------
							// Radio group
							//-----------------------------------------------------------------------------
							@(static)
							radioSelected: i32 = 0
							options := [?]oc.str8{"Radio 1", "Radio 2"}
							radioGroupInfo := oc.ui_radio_group_info {
								selectedIndex = radioSelected,
								optionCount   = 2,
								options       = &options[0],
							}
							result := oc.ui_radio_group("radio_group", &radioGroupInfo)
							radioSelected = result.selectedIndex
							if result.changed {
								log_pushf("Selected Radio %i", result.selectedIndex + 1)
							}

							//-----------------------------------------------------------------------------
							// Horizontal slider
							//-----------------------------------------------------------------------------
							@(static)
							hSliderValue := f32(0)
							@(static)
							hSliderLoggedValue := f32(0)
							@(static)
							hSliderLogTime := f64(0)
							oc.ui_style_next({size = {{.PIXELS, 130, 0, 0}, {}}}, {.SIZE_WIDTH})
							oc.ui_slider("h_slider", &hSliderValue)
							now = oc.clock_time(.MONOTONIC)
							if (now - hSliderLogTime) >= 0.2 &&
							   hSliderValue != hSliderLoggedValue {
								log_pushf("Slider moved to %f", hSliderValue)
								hSliderLoggedValue = hSliderValue
								hSliderLogTime = now
							}
						}
					}

					//-------------------------------------------------------------------------------------
					// Text box
					//-------------------------------------------------------------------------------------
					oc.ui_style_next({size = {{.PIXELS, 305, 0, 0}, {.TEXT, 0, 0, 0}}}, oc.SIZE)
					@(static)
					text: oc.str8
					res := oc.ui_text_box("text", scratch.arena, text)
					if res.changed {
						oc.arena_clear(&textArena)
						text = oc.str8_push_copy(&textArena, res.text)
					}
					if res.accepted {
						log_pushf("Entered text \"%s\"", text)
					}

					//-------------------------------------------------------------------------------------
					// Select
					//-------------------------------------------------------------------------------------
					@(static)
					selected: i32 = -1
					options := [?]oc.str8{"Option 1", "Option 2"}
					info := oc.ui_select_popup_info {
						selectedIndex = selected,
						optionCount   = 2,
						options       = &options[0],
						placeholder   = "Select",
					}
					result := oc.ui_select_popup("select", &info)
					if result.selectedIndex != selected {
						log_pushf("Selected %s", options[result.selectedIndex])
					}
					selected = result.selectedIndex

					//-------------------------------------------------------------------------------------
					// Scrollable panel
					//-------------------------------------------------------------------------------------
					oc.ui_style_next(
						{
							size = {{.PARENT, 1, 0, 0}, {.PARENT, 1, 1, 0}},
							bgColor = ui.theme.bg2,
							borderColor = ui.theme.border,
							borderSize = 1,
							roundness = ui.theme.roundnessSmall,
						},
						oc.SIZE + {.BG_COLOR, .BORDER_COLOR, .BORDER_SIZE, .ROUNDNESS},
					)

					{
						oc.ui_panel("log", {.DRAW_BACKGROUND, .DRAW_BORDER})

						{
							oc.ui_style_next(
								{layout = {margin = 16}},
								oc.LAYOUT_MARGINS + {.LAYOUT_SPACING},
							)
							oc.ui_container("contents", {})

							if oc.list_empty(logLines.list) {
								oc.ui_style_next({_color = ui.theme.text2}, {.COLOR})
								oc.ui_label("Log")
							}

							iter: ^oc.list_elt
							i: int
							for logLine in oc.list_for(
								&logLines.list,
								&iter,
								oc.str8_elt,
								"listElt",
							) {
								id := fmt.tprintf("%d", i)

								oc.ui_container(id, {})
								oc.ui_label_str8(logLine.string)

								i += 1
							}
						}
					}
				}

				//-----------------------------------------------------------------------------------------
				// Styling
				//-----------------------------------------------------------------------------------------
				// Initial values here are hardcoded from the dark theme and everything is overridden all
				// the time. In a real program you'd only override what you need and supply the values from
				// ui.theme or ui.theme.palette.
				//
				// Rule-based styling is described at
				// https://www.forkingpaths.dev/posts/23-03-10/rule_based_styling_imgui.html
				{
					column("Styling", f32(2.0) / 3)
					@(static)
					unselectedWidth := f32(16)
					@(static)
					unselectedHeight := f32(16)
					@(static)
					unselectedRoundness := f32(8)
					@(static)
					unselectedBgColor := oc.color{{0.086, 0.086, 0.102, 1}, .RGB}
					@(static)
					unselectedBorderColor := oc.color{{0.976, 0.976, 0.976, 0.35}, .RGB}
					@(static)
					unselectedBorderSize := f32(1)
					@(static)
					unselectedWhenStatus: oc.ui_status

					@(static)
					selectedWidth := f32(16)
					@(static)
					selectedHeight := f32(16)
					@(static)
					selectedRoundness := f32(8)
					@(static)
					selectedCenterColor := oc.color{{1, 1, 1, 1}, .RGB}
					@(static)
					selectedBgColor := oc.color{{0.33, 0.66, 1, 1}, .RGB}
					@(static)
					selectedWhenStatus: oc.ui_status

					@(static)
					labelFontColor := oc.color{{0.976, 0.976, 0.976, 1}, .RGB}
					@(static)
					labelFontSize := f32(14)

					oc.ui_style_next(
						{
							size = {{.PARENT, 1, 0, 0}, {.PIXELS, 152, 0, 0}},
							layout = {margin = {320, 16}},
							bgColor = oc.UI_DARK_THEME.bg0,
							roundness = oc.UI_DARK_THEME.roundnessSmall,
						},
						oc.SIZE + oc.LAYOUT_MARGINS + {.BG_COLOR, .ROUNDNESS},
					)

					{
						oc.ui_container("styled_radios", {.DRAW_BACKGROUND, .DRAW_BORDER})
						reset_next_radio_group_to_dark_theme(scratch.arena)

						unselectedPattern := oc.ui_pattern{}
						oc.ui_pattern_push(
							scratch.arena,
							&unselectedPattern,
							{kind = .TAG, tag = oc.ui_tag_make_str8("radio")},
						)

						if unselectedWhenStatus != {} {
							oc.ui_pattern_push(
								scratch.arena,
								&unselectedPattern,
								{op = .AND, kind = .STATUS, status = unselectedWhenStatus},
							)
						}
						oc.ui_style_match_after(
							unselectedPattern,
							{
								size = {
									{.PIXELS, unselectedWidth, 0, 0},
									{.PIXELS, unselectedHeight, 0, 0},
								},
								bgColor = unselectedBgColor,
								borderColor = unselectedBorderColor,
								borderSize = unselectedBorderSize,
								roundness = unselectedRoundness,
							},
							oc.SIZE + {.BG_COLOR, .BORDER_COLOR, .BORDER_SIZE, .ROUNDNESS},
						)

						selectedPattern := oc.ui_pattern{}
						oc.ui_pattern_push(
							scratch.arena,
							&selectedPattern,
							{kind = .TAG, tag = oc.ui_tag_make_str8("radio_selected")},
						)

						if selectedWhenStatus != {} {
							oc.ui_pattern_push(
								scratch.arena,
								&selectedPattern,
								{op = .AND, kind = .STATUS, status = selectedWhenStatus},
							)
						}
						oc.ui_style_match_after(
							selectedPattern,
							{
								size = {
									{.PIXELS, selectedWidth, 0, 0},
									{.PIXELS, selectedHeight, 0, 0},
								},
								_color = selectedCenterColor,
								bgColor = selectedBgColor,
								roundness = selectedRoundness,
							},
							oc.SIZE + {.COLOR, .BG_COLOR, .ROUNDNESS},
						)

						labelPattern := oc.ui_pattern{}
						labelTag := oc.ui_tag_make_str8("label")
						oc.ui_pattern_push(
							scratch.arena,
							&labelPattern,
							{kind = .TAG, tag = labelTag},
						)
						oc.ui_style_match_after(
							labelPattern,
							{_color = labelFontColor, font = labelFont^, fontSize = labelFontSize},
							{.COLOR, .FONT, .FONT_SIZE},
						)

						@(static)
						selectedIndex: i32 = 0
						options := [?]oc.str8{"I", "Am", "Stylish"}
						radioGroupInfo := oc.ui_radio_group_info {
							selectedIndex = selectedIndex,
							optionCount   = len(options),
							options       = &options[0],
						}
						result := oc.ui_radio_group("radio_group", &radioGroupInfo)
						selectedIndex = result.selectedIndex
					}

					{
						oc.ui_style_next(
							{layout = {axis = .X, spacing = 32}},
							{.LAYOUT_AXIS, .LAYOUT_SPACING},
						)
						oc.ui_container("controls", {})

						{
							oc.ui_style_next(
								{layout = {axis = .Y, spacing = 16}},
								{.LAYOUT_AXIS, .LAYOUT_SPACING},
							)
							oc.ui_container("unselected", {})

							oc.ui_style_next({fontSize = 16}, {.FONT_SIZE})
							oc.ui_label("Radio style")

							{
								oc.ui_style_next({layout = {spacing = 4}}, {.LAYOUT_SPACING})
								oc.ui_container("size", {})

								widthSlider := f32(unselectedWidth - 8) / 16
								labeled_slider("Width", &widthSlider)
								unselectedWidth = 8 + widthSlider * 16

								heightSlider := f32(unselectedHeight - 8) / 16
								labeled_slider("Height", &heightSlider)
								unselectedHeight = 8 + heightSlider * 16

								roundnessSlider := f32(unselectedRoundness - 4) / 8
								labeled_slider("Roundness", &roundnessSlider)
								unselectedRoundness = 4 + roundnessSlider * 8
							}

							{
								oc.ui_style_next({layout = {spacing = 4}}, {.LAYOUT_SPACING})
								oc.ui_container("background", {})

								labeled_slider("Background R", &unselectedBgColor.r)
								labeled_slider("Background G", &unselectedBgColor.g)
								labeled_slider("Background B", &unselectedBgColor.b)
								labeled_slider("Background A", &unselectedBgColor.a)
							}

							{
								oc.ui_style_next({layout = {spacing = 4}}, {.LAYOUT_SPACING})
								oc.ui_container("border", {})

								labeled_slider("Border R", &unselectedBorderColor.r)
								labeled_slider("Border G", &unselectedBorderColor.g)
								labeled_slider("Border B", &unselectedBorderColor.b)
								labeled_slider("Border A", &unselectedBorderColor.a)
							}

							borderSizeSlider := f32(unselectedBorderSize) / 5
							labeled_slider("Border size", &borderSizeSlider)
							unselectedBorderSize = borderSizeSlider * 5

							{
								oc.ui_style_next({layout = {spacing = 10}}, {.LAYOUT_SPACING})
								oc.ui_container("status_override", {})

								oc.ui_label("Override")

								@(static)
								statusIndex: i32 = 0
								statusOptions := [?]oc.str8 {
									"Always",
									"When hovering",
									"When active",
								}
								statusInfo := oc.ui_radio_group_info {
									selectedIndex = statusIndex,
									optionCount   = len(statusOptions),
									options       = &statusOptions[0],
								}
								result := oc.ui_radio_group("status", &statusInfo)
								statusIndex = result.selectedIndex
								switch statusIndex {
								case 0:
									unselectedWhenStatus = {}
								case 1:
									unselectedWhenStatus = {.HOVER}
								case 2:
									unselectedWhenStatus = {.ACTIVE}
								}
							}
						}

						{
							oc.ui_style_next(
								{layout = {axis = .Y, spacing = 16}},
								{.LAYOUT_AXIS, .LAYOUT_SPACING},
							)
							oc.ui_container("selected", {})

							oc.ui_style_next({fontSize = 16}, {.FONT_SIZE})
							oc.ui_label("Radio selected style")

							{
								oc.ui_style_next({layout = {spacing = 4}}, {.LAYOUT_SPACING})
								oc.ui_container("size", {})

								widthSlider := f32(selectedWidth - 8) / 16
								labeled_slider("Width", &widthSlider)
								selectedWidth = 8 + widthSlider * 16

								heightSlider := f32(selectedHeight - 8) / 16
								labeled_slider("Height", &heightSlider)
								selectedHeight = 8 + heightSlider * 16

								roundnessSlider := f32(selectedRoundness - 4) / 8
								labeled_slider("Roundness", &roundnessSlider)
								selectedRoundness = 4 + roundnessSlider * 8
							}

							{
								oc.ui_style_next({layout = {spacing = 4}}, {.LAYOUT_SPACING})
								oc.ui_container("color", {})

								labeled_slider("Center R", &selectedCenterColor.r)
								labeled_slider("Center G", &selectedCenterColor.g)
								labeled_slider("Center B", &selectedCenterColor.b)
								labeled_slider("Center A", &selectedCenterColor.a)
							}

							{
								oc.ui_style_next({layout = {spacing = 4}}, {.LAYOUT_SPACING})
								oc.ui_container("background", {})

								labeled_slider("Background R", &selectedBgColor.r)
								labeled_slider("Background G", &selectedBgColor.g)
								labeled_slider("Background B", &selectedBgColor.b)
								labeled_slider("Background A", &selectedBgColor.a)
							}

							{
								oc.ui_style_next({layout = {spacing = 10}}, {.LAYOUT_SPACING})
								oc.ui_container("status_override", {})

								oc.ui_style_next(
									{size = {{}, {.PIXELS, 30, 0, 0}}},
									{.SIZE_HEIGHT},
								)
								oc.ui_box_make_str8("spacer", {})
								oc.ui_label("Override")

								@(static)
								statusIndex: i32 = 0
								statusOptions := [?]oc.str8 {
									"Always",
									"When hovering",
									"When active",
								}
								statusInfo := oc.ui_radio_group_info {
									selectedIndex = statusIndex,
									optionCount   = len(statusOptions),
									options       = &statusOptions[0],
								}
								result := oc.ui_radio_group("status", &statusInfo)
								statusIndex = result.selectedIndex
								switch statusIndex {
								case 0:
									selectedWhenStatus = {}
								case 1:
									selectedWhenStatus = {.HOVER}
								case 2:
									selectedWhenStatus = {.ACTIVE}
								}
							}
						}

						{
							oc.ui_style_next(
								{layout = {axis = .Y, spacing = 16}},
								{.LAYOUT_AXIS, .LAYOUT_SPACING},
							)
							oc.ui_container("label", {})

							oc.ui_style_next({fontSize = 16}, {.FONT_SIZE})
							oc.ui_label("Label style")

							{
								oc.ui_style_next(
									{layout = {axis = .X, spacing = 8}},
									{.LAYOUT_AXIS, .LAYOUT_SPACING},
								)
								oc.ui_container("font_color", {})

								oc.ui_style_match_after(
									oc.ui_pattern_owner(),
									{size = {{.PIXELS, 100, 0, 0}, {}}},
									{.SIZE_WIDTH},
								)
								oc.ui_label("Font color")

								@(static)
								colorSelected: i32 = 0
								colorNames := [?]oc.str8 {
									"Default",
									"Red",
									"Orange",
									"Amber",
									"Yellow",
									"Lime",
									"Light Green",
									"Green",
								}
								colors := [?]oc.color {
									oc.UI_DARK_THEME.text0,
									oc.UI_DARK_THEME.palette.red5,
									oc.UI_DARK_THEME.palette.orange5,
									oc.UI_DARK_THEME.palette.amber5,
									oc.UI_DARK_THEME.palette.yellow5,
									oc.UI_DARK_THEME.palette.lime5,
									oc.UI_DARK_THEME.palette.lightGreen5,
									oc.UI_DARK_THEME.palette.green5,
								}
								colorInfo := oc.ui_select_popup_info {
									selectedIndex = colorSelected,
									optionCount   = len(colorNames),
									options       = &colorNames[0],
								}
								colorResult := oc.ui_select_popup("color", &colorInfo)
								colorSelected = colorResult.selectedIndex
								labelFontColor = colors[colorSelected]
							}

							{
								oc.ui_style_next(
									{layout = {axis = .X, spacing = 8}},
									{.LAYOUT_AXIS, .LAYOUT_SPACING},
								)
								oc.ui_container("font", {})

								oc.ui_style_match_after(
									oc.ui_pattern_owner(),
									{size = {{.PIXELS, 100, 0, 0}, {}}},
									{.SIZE_WIDTH},
								)
								oc.ui_label("Font")

								@(static)
								fontSelected: i32 = 0
								fontNames := [?]oc.str8{"Regular", "Bold"}
								fonts := [?]^oc.font{&fontRegular, &fontBold}
								fontInfo := oc.ui_select_popup_info {
									selectedIndex = fontSelected,
									optionCount   = len(fontNames),
									options       = &fontNames[0],
								}
								fontResult := oc.ui_select_popup("font_style", &fontInfo)
								fontSelected = fontResult.selectedIndex
								labelFont = fonts[fontSelected]
							}

							fontSizeSlider := f32(labelFontSize - 8) / 16
							labeled_slider("Font size", &fontSizeSlider)
							labelFontSize = 8 + fontSizeSlider * 16
						}
					}
				}
			}
		}
	}

	oc.canvas_context_select(canvas)

	oc.set_color(ui.theme.bg0)
	oc.clear()

	oc.ui_draw()
	oc.canvas_render(renderer, canvas, surface)
	oc.canvas_present(renderer, surface)

	oc.scratch_end(scratch)
}

// This makes sure the light theme doesn't break the styling overrides
// You won't need it in a real program as long as your colors come from ui.theme or ui.theme.palette
reset_next_radio_group_to_dark_theme :: proc "c" (arena: ^oc.arena) {
	defaultTag := oc.ui_tag_make_str8("radio")
	defaultPattern := oc.ui_pattern{}
	oc.ui_pattern_push(arena, &defaultPattern, {kind = .TAG, tag = defaultTag})
	defaultStyle := oc.ui_style {
		borderColor = oc.UI_DARK_THEME.text3,
		borderSize  = 1,
	}
	defaultMask: oc.ui_style_mask = {.BORDER_COLOR, .BORDER_SIZE}
	oc.ui_style_match_after(defaultPattern, defaultStyle, defaultMask)

	hoverPattern := oc.ui_pattern{}
	oc.ui_pattern_push(arena, &hoverPattern, {kind = .TAG, tag = defaultTag})
	oc.ui_pattern_push(arena, &hoverPattern, {op = .AND, kind = .STATUS, status = {.HOVER}})
	hoverStyle := oc.ui_style {
		bgColor     = oc.UI_DARK_THEME.fill0,
		borderColor = oc.UI_DARK_THEME.primary,
	}
	hoverMask: oc.ui_style_mask = {.BG_COLOR, .BORDER_COLOR}
	oc.ui_style_match_after(hoverPattern, hoverStyle, hoverMask)

	activePattern := oc.ui_pattern{}
	oc.ui_pattern_push(arena, &activePattern, {kind = .TAG, tag = defaultTag})
	oc.ui_pattern_push(arena, &activePattern, {op = .AND, kind = .STATUS, status = {.ACTIVE}})
	activeStyle := oc.ui_style {
		bgColor     = oc.UI_DARK_THEME.fill1,
		borderColor = oc.UI_DARK_THEME.primary,
	}
	activeMask: oc.ui_style_mask = {.BG_COLOR, .BORDER_COLOR}
	oc.ui_style_match_after(activePattern, activeStyle, activeMask)

	selectedTag := oc.ui_tag_make_str8("radio_selected")
	selectedPattern := oc.ui_pattern{}
	oc.ui_pattern_push(arena, &selectedPattern, {kind = .TAG, tag = selectedTag})
	selectedStyle := oc.ui_style {
		_color  = oc.UI_DARK_THEME.palette.white,
		bgColor = oc.UI_DARK_THEME.primary,
	}
	selectedMask: oc.ui_style_mask = {.COLOR, .BG_COLOR}
	oc.ui_style_match_after(selectedPattern, selectedStyle, selectedMask)

	selectedHoverPattern := oc.ui_pattern{}
	oc.ui_pattern_push(arena, &selectedHoverPattern, {kind = .TAG, tag = selectedTag})
	oc.ui_pattern_push(
		arena,
		&selectedHoverPattern,
		{op = .AND, kind = .STATUS, status = {.HOVER}},
	)
	selectedHoverStyle := oc.ui_style {
		bgColor = oc.UI_DARK_THEME.primaryHover,
	}
	oc.ui_style_match_after(selectedHoverPattern, selectedHoverStyle, {.BG_COLOR})

	selectedActivePattern := oc.ui_pattern{}
	oc.ui_pattern_push(arena, &selectedActivePattern, {kind = .TAG, tag = selectedTag})
	oc.ui_pattern_push(
		arena,
		&selectedActivePattern,
		{op = .AND, kind = .STATUS, status = {.ACTIVE}},
	)
	selectedActiveStyle := oc.ui_style {
		bgColor = oc.UI_DARK_THEME.primaryActive,
	}
	oc.ui_style_match_after(selectedActivePattern, selectedActiveStyle, {.BG_COLOR})
}
