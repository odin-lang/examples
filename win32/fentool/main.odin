package fen_tool

import runtime "base:runtime"
import fmt "core:fmt"
import log "core:log"
import os "core:os"
import strings "core:strings"
import win "core:sys/windows"

@(thread_local) window_context_tls: runtime.Context

MAIN_WNDCLASS_NAME :: "fen_tool_main"

main :: proc() {

	startup_info : win.STARTUPINFOW
	win.GetStartupInfoW(&startup_info)
	nCmdShow := (startup_info.dwFlags & win.STARTF_USESHOWWINDOW) != 0 ? cast(win.c_int)startup_info.wShowWindow : win.SW_SHOWDEFAULT

	// For testing purposes - toggles the language of loaded resources.
	//win.SetThreadUILanguage(0x0413)

	context.logger = log.create_console_logger()

	hInstance := cast(win.HINSTANCE)win.GetModuleHandleW(nil)
	board_control_register_class(hInstance)

	icce: win.INITCOMMONCONTROLSEX
	icce.dwSize = size_of(win.INITCOMMONCONTROLSEX)
	icce.dwICC = win.ICC_BAR_CLASSES // Enables status bar and toolbar classes
	win.InitCommonControlsEx(&icce)

	window_context_tls = context

	hdlg := win.CreateDialogW(hInstance, "IDD_MAIN", nil, dlg_proc)
	assert(hdlg != nil, "Could not create main dialog. Is 'resource.rc' compiled properly?")
	fudge_window_starting_position(hdlg)

	win.ShowWindow(hdlg, nCmdShow)

	accelerator_table := win.LoadAcceleratorsW(hInstance, "IDC_ACCELERATOR_TABLE")

	msg: win.MSG
	for win.GetMessageW(&msg, nil, 0, 0) != 0 {
		if win.TranslateAcceleratorW(hdlg, accelerator_table, &msg) == 0 {
			if !win.IsDialogMessageW(hdlg, &msg) {
				win.TranslateMessage(&msg)
				win.DispatchMessageW(&msg)
			}
		}
		free_all(context.temp_allocator)
	}

	log.debugf("Exit code: %v", msg.wParam)
	os.exit(cast(int)msg.wParam)
}

Main_Ctx :: struct {
	runtime_context: ^runtime.Context,
	// Used to suppress any change notifications while we're
	// updating control contents programmatically.
	updating: int,
	current_pieces: Board_Pieces,
	// Last opened or saved file path.
	// Used as the save path in `IDM_SAVE`.
	// When empty, no project file is active.
	// NOTE: This instance owns the memory associated with the string.
	active_project_file_path: string,
	project_dirty: bool,
}

get_main_ctx :: proc "contextless" (hdlg: win.HWND) -> ^Main_Ctx {
	return cast(^Main_Ctx)cast(uintptr)win.GetWindowLongPtrW(hdlg, win.DWLP_USER)
}

dlg_proc :: proc "system" (hdlg: win.HWND, msg: win.UINT, wparam: win.WPARAM, lparam: win.LPARAM) -> win.INT_PTR {

	switch msg {

	case win.WM_INITDIALOG:
		// Setup main window context
		context = window_context_tls
		ctx := new(Main_Ctx)
		ctx.runtime_context = &window_context_tls
		win.SetWindowLongPtrW(hdlg, win.DWLP_USER, cast(win.LONG_PTR)cast(uintptr)ctx)

		// Load and set the window icon.
		hInstance := cast(win.HINSTANCE)win.GetModuleHandleW(nil)
		idi_main := cast(rawptr)cast(uintptr)IDI_MAIN
		icon_big   := win.LoadImageW(hInstance, cast(win.LPCWSTR)idi_main, win.IMAGE_ICON, win.GetSystemMetrics(win.SM_CXICON),   win.GetSystemMetrics(win.SM_CYICON),   win.LR_DEFAULTCOLOR | win.LR_SHARED)
		icon_small := win.LoadImageW(hInstance, cast(win.LPCWSTR)idi_main, win.IMAGE_ICON, win.GetSystemMetrics(win.SM_CXSMICON), win.GetSystemMetrics(win.SM_CYSMICON), win.LR_DEFAULTCOLOR | win.LR_SHARED)
		win.SendMessageW(hdlg, win.WM_SETICON, win.ICON_BIG,   cast(win.LPARAM)cast(uintptr)icon_big)
		win.SendMessageW(hdlg, win.WM_SETICON, win.ICON_SMALL, cast(win.LPARAM)cast(uintptr)icon_small)

		// Check initial visuals option.
		hmenu := win.GetMenu(hdlg)
		win.CheckMenuRadioItem(hmenu, IDM_VISUALS_NORMAL, IDM_VISUALS_GINGER, IDM_VISUALS_NORMAL, win.MF_BYCOMMAND)

		reset_to_starting_position(hdlg, ctx, set_dirty = false)

	case win.WM_NCDESTROY:
		ctx := get_main_ctx(hdlg)
		context = ctx.runtime_context^
		delete(ctx.active_project_file_path)
		ctx.active_project_file_path = ""
		free(ctx)

	case win.WM_DESTROY:
		ctx := get_main_ctx(hdlg)
		context = ctx.runtime_context^
		// Main window destroyed - quit message loop.
		win.PostQuitMessage(0)
		// Return 1 to stop DefDlgProc message handling - we handle this explicitly because we're the application's main window.
		return 1

	case win.WM_CLOSE:
		ctx := get_main_ctx(hdlg)
		context = ctx.runtime_context^
		if prompt_if_project_dirty(hdlg, ctx) {
			win.DestroyWindow(hdlg)
		}
		// Return 1 to stop DefDlgProc message handling - we handle this explicitly because we're the application's main window.
		return 1

	case win.WM_SIZE:
		ctx := get_main_ctx(hdlg)
		context = ctx.runtime_context^
		// The status bar will adjust itself to the window size, it just needs a WM_SIZE message to trigger it.
		status_bar := win.GetDlgItem(hdlg, IDC_STATUSBAR)
		win.SendMessageW(status_bar, win.WM_SIZE, 0, 0)

	case win.WM_COMMAND:

		ctx := get_main_ctx(hdlg)
		context = ctx.runtime_context^
		id := win.LOWORD(wparam)
		nc := win.HIWORD(wparam)

		switch id {

		case IDM_RESET_TO_STARTING_POSITION:
			reset_to_starting_position(hdlg, ctx, prompt_for_confirmation = true)

		case IDM_NEW:
			file_new(hdlg, ctx)

		case IDM_OPEN:
			file_open(hdlg, ctx)

		case IDM_SAVE:
			file_save(hdlg, ctx)

		case IDM_SAVE_AS:
			file_save_as(hdlg, ctx)

		case IDM_EXIT:
			if prompt_if_project_dirty(hdlg, ctx) {
				win.DestroyWindow(hdlg)
			}

		case IDM_PLAY_SOUND:
			// Toggle Play Sound option.
			hmenu := win.GetMenu(hdlg)
			mii: win.MENUITEMINFOW
			mii.cbSize = size_of(win.MENUITEMINFOW)
			mii.fMask = win.MIIM_STATE
			win.GetMenuItemInfoW(hmenu, IDM_PLAY_SOUND, false, &mii)
			checked := (mii.fState & win.MFS_CHECKED) != 0
			if checked {
				win.CheckMenuItem(hmenu, IDM_PLAY_SOUND, win.MF_BYCOMMAND | win.MF_UNCHECKED)
			} else {
				win.CheckMenuItem(hmenu, IDM_PLAY_SOUND, win.MF_BYCOMMAND | win.MF_CHECKED)
			}

		case IDM_VISUALS_NORMAL:
			hmenu := win.GetMenu(hdlg)
			win.CheckMenuRadioItem(hmenu, IDM_VISUALS_NORMAL, IDM_VISUALS_GINGER, IDM_VISUALS_NORMAL, win.MF_BYCOMMAND)
			board_control := win.GetDlgItem(hdlg, IDC_BOARD_CONTROL)
			board_control_set_spritemap(board_control, .normal)

		case IDM_VISUALS_GINGER:
			hmenu := win.GetMenu(hdlg)
			win.CheckMenuRadioItem(hmenu, IDM_VISUALS_NORMAL, IDM_VISUALS_GINGER, IDM_VISUALS_GINGER, win.MF_BYCOMMAND)
			board_control := win.GetDlgItem(hdlg, IDC_BOARD_CONTROL)
			board_control_set_spritemap(board_control, .ginger)

		case IDM_ABOUT:
			about_show_dialog(hdlg)

		case IDC_TEXTBOX_FEN:
			if nc == win.EN_CHANGE {
				if ctx.updating == 0 {
					reparse_fen(hdlg, ctx, interactive = true)
					set_project_dirty(hdlg, ctx)
				}
			}

		case IDC_RADIOBUTTON_WHITE_TO_MOVE,
		     IDC_RADIOBUTTON_BLACK_TO_MOVE:
			if nc == win.BN_CLICKED {
				// Check the clicked radio button.
				win.CheckRadioButton(hdlg, IDC_RADIOBUTTON_WHITE_TO_MOVE, IDC_RADIOBUTTON_BLACK_TO_MOVE, auto_cast id)
				update_from_control_states(hdlg, ctx)
			}

		case IDC_CHECKBOX_WHITE_CASTLE_KINGSIDE,
		     IDC_CHECKBOX_WHITE_CASTLE_QUEENSIDE,
		     IDC_CHECKBOX_BLACK_CASTLE_KINGSIDE,
		     IDC_CHECKBOX_BLACK_CASTLE_QUEENSIDE:
			if nc == win.BN_CLICKED {
				// Toggle the check state of the clicked check box.
				current_state := win.IsDlgButtonChecked(hdlg, auto_cast id) == win.BST_CHECKED
				new_state := current_state ? win.BST_UNCHECKED : win.BST_CHECKED
				win.CheckDlgButton(hdlg, auto_cast id, auto_cast new_state)
				update_from_control_states(hdlg, ctx)
			}

		case IDC_TEXTBOX_EN_PASSANT_TARGET_SQUARE:
			if nc == win.EN_CHANGE {
				if ctx.updating == 0 {
					show_en_passant_validation_tip(hdlg)
					update_from_control_states(hdlg, ctx)
				}
			}

		case IDC_TEXTBOX_HALFMOVE_CLOCK,
		     IDC_TEXTBOX_FULLMOVE_NUMBER:
			if nc == win.EN_CHANGE {
				if ctx.updating == 0 {
					update_from_control_states(hdlg, ctx)
				}
			}

		case IDC_BUTTON_CLEAR_EN_PASSANT:
			ctx.updating += 1
			defer ctx.updating -= 1
			set_dialog_item_text(hdlg, IDC_TEXTBOX_EN_PASSANT_TARGET_SQUARE, "-")
			update_from_control_states(hdlg, ctx)
		}

	case win.WM_NOTIFY:

		switch wparam {

		case IDC_BOARD_CONTROL:

			ctx := get_main_ctx(hdlg)
			context = ctx.runtime_context^
			nm := cast(^NM_BOARD_CONTROL_NOTIFICATION)cast(uintptr)lparam
			code := cast(Board_Control_Notification_Code)nm.hdr.code

			switch code {

			case .none:

			case .hover:
				if nm.hovering {
					// Build a string like "A1 - Rook (White)"
					square := nm.square
					rank := square.rank
					file := square.file
					piece := ctx.current_pieces[rank * 8 + file]
					piece_str := format_piece_display_text(piece, context.temp_allocator)
					pos_str := board_format_position(square, context.temp_allocator)
					status_text: string
					if piece_str != "" {
						status_text = fmt.tprintf("%v - %v", pos_str, piece_str)
					} else {
						status_text = pos_str
					}
					set_dialog_item_text(hdlg, IDC_STATUSBAR, status_text)
				} else {
					set_dialog_item_text(hdlg, IDC_STATUSBAR, "")
				}

			case .place_piece:
				rank := nm.square.rank
				file := nm.square.file
				piece := nm.piece
				ctx.current_pieces[rank * 8 + file] = piece
				update_from_control_states(hdlg, ctx)
				play_piece_placing_sound_if_enabled(hdlg)

			case .set_en_passant_target_square:
				square := nm.square
				set_en_passant_target_square(hdlg, square)
				update_from_control_states(hdlg, ctx)

			case .set_castling_right:
				castling_right := nm.castling_right
				state := nm.castling_right_state
				button_state: win.UINT
				switch state {
				case .allow:     button_state = win.BST_CHECKED
				case .disallow:  button_state = win.BST_UNCHECKED
				case: unreachable()
				}
				switch castling_right {
				case .white_kingside:   win.CheckDlgButton(hdlg, IDC_CHECKBOX_WHITE_CASTLE_KINGSIDE,  button_state)
				case .white_queenside:  win.CheckDlgButton(hdlg, IDC_CHECKBOX_WHITE_CASTLE_QUEENSIDE, button_state)
				case .black_kingside:   win.CheckDlgButton(hdlg, IDC_CHECKBOX_BLACK_CASTLE_KINGSIDE,  button_state)
				case .black_queenside:  win.CheckDlgButton(hdlg, IDC_CHECKBOX_BLACK_CASTLE_QUEENSIDE, button_state)
				}
				update_from_control_states(hdlg, ctx)

			case .exchange_pieces:
				rank1 := nm.square.rank
				file1 := nm.square.file
				rank2 := nm.square2.rank
				file2 := nm.square2.file
				tmp := ctx.current_pieces[rank1 * 8 + file1]
				ctx.current_pieces[rank1 * 8 + file1] = ctx.current_pieces[rank2 * 8 + file2]
				ctx.current_pieces[rank2 * 8 + file2] = tmp
				update_from_control_states(hdlg, ctx)
				play_piece_placing_sound_if_enabled(hdlg)
			}
		}

	case win.WM_MENUSELECT:
		// User is hovering over any menu item.
		// Try to get a help hint for the status bar by looking for a string resource
		// with the same ID as the hovered menu item ID.
		// This works because by convention, we share resource IDs in this particular way.
		ctx := get_main_ctx(hdlg)
		context = ctx.runtime_context^
		menu_item_id := cast(win.UINT)win.LOWORD(wparam)
		flags := win.HIWORD(wparam)
		hmenu := cast(win.HMENU)cast(uintptr)lparam
		if flags == 0xffff && hmenu == nil {
			set_dialog_item_text(hdlg, IDC_STATUSBAR, "")
		} else {
			hInstance := cast(win.HINSTANCE)win.GetModuleHandleW(nil)
			// NOTE: If no matching string exists for the specified menu item ID, this will return "",
			//       in which case the status bar shows nothing.
			string_resource, _ := load_string_resource(hInstance, menu_item_id, context.temp_allocator)
			set_dialog_item_text(hdlg, IDC_STATUSBAR, string_resource)
		}
	}

	return 0
}

//
// File New/Open/Save/SaveAs
//

file_new :: proc(hdlg: win.HWND, ctx: ^Main_Ctx) -> bool {
	if !prompt_if_project_dirty(hdlg, ctx) {
		return false
	}
	delete(ctx.active_project_file_path)
	ctx.active_project_file_path = ""
	reset_to_starting_position(hdlg, ctx, set_dirty = false)
	set_project_dirty(hdlg, ctx, false)
	return true
}

file_open :: proc(hdlg: win.HWND, ctx: ^Main_Ctx) -> bool {

	if !prompt_if_project_dirty(hdlg, ctx) {
		return false
	}

	filters := get_file_dialog_filters()
	dialog_confirmed, file_path := file_dialog(
		owner = hdlg,
		mode = .open,
		filters = filters[:],
		allocator = context.allocator,
	)

	if !dialog_confirmed {
		return false
	}

	data, error := os.read_entire_file_from_path(file_path, context.temp_allocator)
	if error != nil {
		// NOTE: The Win32 system error message can actually be nicer than what the OS package gives us here.
		hInstance := cast(win.HINSTANCE)win.GetModuleHandleW(nil)
		error_message := os.error_string(error)
		error_caption := load_string_resource(hInstance, IDS_ERROR_CAPTION, context.temp_allocator)
		win.MessageBoxW(hdlg, win.utf8_to_wstring(error_message, context.temp_allocator), win.utf8_to_wstring(error_caption, context.temp_allocator), win.MB_OK)
		return false
	}

	fen := transmute(string)data
	set_dialog_item_text(hdlg, IDC_TEXTBOX_FEN, fen)
	delete(ctx.active_project_file_path)
	ctx.active_project_file_path = file_path
	set_project_dirty(hdlg, ctx, false)
	return true
}

file_save :: proc(hdlg: win.HWND, ctx: ^Main_Ctx) -> bool {

	if ctx.active_project_file_path == "" {
		return file_save_as(hdlg, ctx)
	}
	
	fen := get_dialog_item_text(hdlg, IDC_TEXTBOX_FEN, 512)
	error := os.write_entire_file(ctx.active_project_file_path, fen)
	if error != nil {
		// NOTE: The Win32 system error message can actually be nicer than what the OS package gives us here.
		error_message := os.error_string(error)
		hInstance := cast(win.HINSTANCE)win.GetModuleHandleW(nil)
		error_caption := load_string_resource(hInstance, IDS_ERROR_CAPTION, context.temp_allocator)
		win.MessageBoxW(hdlg, win.utf8_to_wstring(error_message, context.temp_allocator), win.utf8_to_wstring(error_caption, context.temp_allocator), win.MB_OK)
		return false
	}
	set_project_dirty(hdlg, ctx, false)
	return true
}

file_save_as :: proc(hdlg: win.HWND, ctx: ^Main_Ctx) -> bool {

	filters := get_file_dialog_filters()
	dialog_confirmed, file_path := file_dialog(
		owner = hdlg,
		mode = .save,
		filters = filters[:],
		allocator = context.allocator,
	)

	if !dialog_confirmed {
		return false
	}

	fen := get_dialog_item_text(hdlg, IDC_TEXTBOX_FEN, 512)
	error := os.write_entire_file(file_path, fen)
	if error != nil {
		// NOTE: The Win32 system error message can actually be nicer than what the OS package gives us here.
		error_message := os.error_string(error)
		hInstance := cast(win.HINSTANCE)win.GetModuleHandleW(nil)
		error_caption := load_string_resource(hInstance, IDS_ERROR_CAPTION, context.temp_allocator)
		win.MessageBoxW(hdlg, win.utf8_to_wstring(error_message, context.temp_allocator), win.utf8_to_wstring(error_caption, context.temp_allocator), win.MB_OK)
		return false
	}

	delete(ctx.active_project_file_path)
	ctx.active_project_file_path = file_path
	set_project_dirty(hdlg, ctx, false)
	return true
}

get_file_dialog_filters :: proc() -> [2]File_Dialog_Filter {
	hInstance := cast(win.HINSTANCE)win.GetModuleHandleW(nil)
	return [2]File_Dialog_Filter {
		{ display_text = load_string_resource(hInstance, IDS_FEN_FILES_FILTER), filter = "*.fen" },
		{ display_text = load_string_resource(hInstance, IDS_ALL_FILES_FILTER), filter = "*.*" },
	}
}

prompt_if_project_dirty :: proc(hdlg: win.HWND, ctx: ^Main_Ctx) -> bool {
	if ctx.project_dirty {
		hInstance := cast(win.HINSTANCE)win.GetModuleHandleW(nil)
		text := load_string_resource(hInstance, IDS_UNSAVED_CHANGES_MESSAGE)
		caption := load_string_resource(hInstance, IDS_UNSAVED_CHANGES_CAPTION)
		choice := win.MessageBoxW(hdlg, win.utf8_to_wstring(text), win.utf8_to_wstring(caption), win.MB_YESNOCANCEL)
		switch choice {
		case win.IDYES:
			if !file_save(hdlg, ctx) {
				// Saving failed or got canceled by user.
				return false
			}
		case win.IDNO:
			// OK, discard.
		case:
			return false
		}
	}
	return true
}

set_project_dirty :: proc(hdlg: win.HWND, ctx: ^Main_Ctx, dirty := true) {
	if ctx.project_dirty != dirty {
		ctx.project_dirty = dirty
		if dirty {
			// Append "*" to the main window caption.
			hInstance := cast(win.HINSTANCE)win.GetModuleHandleW(nil)
			caption := load_string_resource(hInstance, IDS_TITLE, context.temp_allocator)
			caption_dirty := strings.concatenate({ caption, "*" }, context.temp_allocator)
			win.SetWindowTextW(hdlg, win.utf8_to_wstring(caption_dirty, context.temp_allocator))
		} else {
			hInstance := cast(win.HINSTANCE)win.GetModuleHandleW(nil)
			caption := load_string_resource(hInstance, IDS_TITLE, context.temp_allocator)
			win.SetWindowTextW(hdlg, win.utf8_to_wstring(caption, context.temp_allocator))
		}
	}
}

play_piece_placing_sound_if_enabled :: proc(hdlg: win.HWND) {
	// Query the "Play Sound" option directly from the menu.
	hmenu := win.GetMenu(hdlg)
	mii: win.MENUITEMINFOW
	mii.cbSize = size_of(win.MENUITEMINFOW)
	mii.fMask = win.MIIM_STATE
	win.GetMenuItemInfoW(hmenu, IDM_PLAY_SOUND, false, &mii)
	checked := (mii.fState & win.MFS_CHECKED) != 0
	if checked {
		// PlaySoundW can play the sound directly from the resource.
		win.PlaySoundW("IDW_CLACK", win.GetModuleHandleW(nil), win.SND_ASYNC | win.SND_RESOURCE)
	}
}

show_en_passant_validation_tip :: proc(hdlg: win.HWND) {

	text := get_dialog_item_text(hdlg, IDC_TEXTBOX_EN_PASSANT_TARGET_SQUARE, 512, context.temp_allocator)
	trimmed := strings.trim_space(text)
	if len(trimmed) < 2 {
		return
	}

	_, ok := parse_en_passant_target_square(trimmed)
	if ok {
		return
	}

	hInstance := cast(win.HINSTANCE)win.GetModuleHandleW(nil)

	tip := win.EDITBALLOONTIP {
		cbStruct = size_of(win.EDITBALLOONTIP),
		pszTitle = win.utf8_to_wstring_alloc(load_string_resource(hInstance, IDS_INVALID_EN_PASSANT_TARGET_SQUARE, context.temp_allocator), context.temp_allocator),
		pszText = win.utf8_to_wstring_alloc(load_string_resource(hInstance, IDS_INVALID_EN_PASSANT_TARGET_SQUARE_HINT, context.temp_allocator), context.temp_allocator),
		ttiIcon = win.TTI_ERROR,
	}

	// NOTE: We send the message to display the balloon tip, but we do not prevent user input here, because that would be irritating.
	win.SendDlgItemMessageW(hdlg, IDC_TEXTBOX_EN_PASSANT_TARGET_SQUARE, win.EM_SHOWBALLOONTIP, 0, cast(win.LPARAM)cast(uintptr)&tip)
}

format_piece_display_text :: proc(piece: Board_Piece, allocator := context.temp_allocator) -> string {

	type_str: string

	hInstance := cast(win.HINSTANCE)win.GetModuleHandleW(nil)

	switch piece.type {
	case .none:    return ""
	case .rook:    type_str = load_string_resource(hInstance, IDS_ROOK,   context.temp_allocator)
	case .knight:  type_str = load_string_resource(hInstance, IDS_KNIGHT, context.temp_allocator)
	case .bishop:  type_str = load_string_resource(hInstance, IDS_BISHOP, context.temp_allocator)
	case .queen:   type_str = load_string_resource(hInstance, IDS_QUEEN,  context.temp_allocator)
	case .king:    type_str = load_string_resource(hInstance, IDS_KING,   context.temp_allocator)
	case .pawn:    type_str = load_string_resource(hInstance, IDS_PAWN,   context.temp_allocator)
	case:          type_str = "?"
	}

	color_str: string

	switch piece.color {
	case .white:   color_str = load_string_resource(hInstance, IDS_WHITE, context.temp_allocator)
	case .black:   color_str = load_string_resource(hInstance, IDS_BLACK, context.temp_allocator)
	case:          color_str = "?"
	}

	return fmt.aprintf("%v (%v)", type_str, color_str, allocator = allocator)
}

STARTING_POSITION_FEN :: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

reset_to_starting_position :: proc(hdlg: win.HWND, ctx: ^Main_Ctx, set_dirty := true, prompt_for_confirmation := false) {

	if prompt_for_confirmation {
		hInstance := cast(win.HINSTANCE)win.GetModuleHandleW(nil)
		message := win.utf8_to_wstring(load_string_resource(hInstance, IDS_CONFIRM_RESET_MESSAGE, context.temp_allocator))
		caption := win.utf8_to_wstring(load_string_resource(hInstance, IDS_CONFIRM_RESET_CAPTION, context.temp_allocator))
		choice := win.MessageBoxW(hdlg, message, caption, win.MB_YESNO)
		if choice != win.IDYES {
			return
		}
	}

	{
		ctx.updating += 1
		defer ctx.updating -= 1
		set_dialog_item_text_cstring16(hdlg, IDC_TEXTBOX_FEN, STARTING_POSITION_FEN)
		if set_dirty {
			set_project_dirty(hdlg, ctx)
		}
	}

	reparse_fen(hdlg, ctx, interactive = false)
}

// Parses the contents of the FEN string text box, and updates all
// controls accordingly to the board state it denotes.
//
//  - `interactive`: Displays a balloon tip if the text box contains an invalid FEN string.
//                   Should only be used if this was called after direct user interaction.
reparse_fen :: proc(hdlg: win.HWND, ctx: ^Main_Ctx, interactive: bool) {

	fen_string := get_dialog_item_text(hdlg, IDC_TEXTBOX_FEN, 512, context.temp_allocator)
	if fen_string == "" {
		return
	}

	board, error := parse_fen(fen_string)
	if error.is_error {
		log.debugf("FEN string is invalid.")
		if interactive {
			// Display balloon tip with the error message.
			hInstance := cast(win.HINSTANCE)win.GetModuleHandleW(nil)
			tip := win.EDITBALLOONTIP {
				cbStruct = size_of(win.EDITBALLOONTIP),
				pszTitle = win.utf8_to_wstring_alloc(load_string_resource(hInstance, IDS_INVALID_FEN_STRING, context.temp_allocator), context.temp_allocator),
				pszText = win.utf8_to_wstring_alloc(error.display_message, context.temp_allocator),
				ttiIcon = win.TTI_ERROR,
			}
			win.SendDlgItemMessageW(hdlg, IDC_TEXTBOX_FEN, win.EM_SHOWBALLOONTIP, 0, cast(win.LPARAM)cast(uintptr)&tip)
		}
		return
	}

	log.debugf("Board:\r\n%v", board_format_full(board))

	ctx.updating += 1
	defer ctx.updating -= 1

	ctx.current_pieces = board.pieces

	board_control := win.GetDlgItem(hdlg, IDC_BOARD_CONTROL)
	board_control_set_board(board_control, board)

	check_button: win.c_int
	switch board.turn_player {
	case .white:
		check_button = IDC_RADIOBUTTON_WHITE_TO_MOVE
	case .black:
		check_button = IDC_RADIOBUTTON_BLACK_TO_MOVE
	}
	win.CheckRadioButton(hdlg, IDC_RADIOBUTTON_WHITE_TO_MOVE, IDC_RADIOBUTTON_BLACK_TO_MOVE, check_button)

	win.CheckDlgButton(hdlg, IDC_CHECKBOX_WHITE_CASTLE_KINGSIDE,  board.white_can_castle_kingside  ? win.BST_CHECKED : win.BST_UNCHECKED)
	win.CheckDlgButton(hdlg, IDC_CHECKBOX_WHITE_CASTLE_QUEENSIDE, board.white_can_castle_queenside ? win.BST_CHECKED : win.BST_UNCHECKED)
	win.CheckDlgButton(hdlg, IDC_CHECKBOX_BLACK_CASTLE_KINGSIDE,  board.black_can_castle_kingside  ? win.BST_CHECKED : win.BST_UNCHECKED)
	win.CheckDlgButton(hdlg, IDC_CHECKBOX_BLACK_CASTLE_QUEENSIDE, board.black_can_castle_queenside ? win.BST_CHECKED : win.BST_UNCHECKED)

	set_en_passant_target_square(hdlg, board.en_passant_target_square)

	win.SetDlgItemInt(hdlg, IDC_TEXTBOX_HALFMOVE_CLOCK,  cast(win.UINT)board.halfmove_clock,  true)
	win.SetDlgItemInt(hdlg, IDC_TEXTBOX_FULLMOVE_NUMBER, cast(win.UINT)board.fullmove_number, true)
}

set_en_passant_target_square :: proc(hdlg: win.HWND, square: Square_Specifier) {
	square_text := board_format_en_passant_target_square(square)
	set_dialog_item_text(hdlg, IDC_TEXTBOX_EN_PASSANT_TARGET_SQUARE, square_text)
}

// Queries the state of all controls, and then displays the
// corresponding FEN string in the FEN string text box, and the
// board state in the board control.
update_from_control_states :: proc(hdlg: win.HWND, ctx: ^Main_Ctx) {

	// Construct board from control states.
	board, board_ok := get_board_from_control_states(hdlg, ctx)
	if !board_ok {
		log.warn("Could not construct board from control states.")
		return
	}

	// Display the board state in the board control.
	board_control := win.GetDlgItem(hdlg, IDC_BOARD_CONTROL)
	board_control_set_board(board_control, board)

	// Convert board info to FEN string.
	fen_string, fen_string_ok := construct_fen_string_from_board(board)
	if !fen_string_ok {
		log.warn("Could not construct FEN string from board.")
		return
	}

	// Put the constructed FEN string the FEN string text box.
	old_fen_string := get_dialog_item_text(hdlg, IDC_TEXTBOX_FEN, 512, context.temp_allocator)
	if fen_string != old_fen_string {
		ctx.updating += 1
		defer ctx.updating -= 1
		log.debugf("FEN string changing from %q to %q", old_fen_string, fen_string)
		fen_wstr := win.utf8_to_wstring_alloc(fen_string, context.temp_allocator)
		win.SetDlgItemTextW(hdlg, IDC_TEXTBOX_FEN, fen_wstr)
		set_project_dirty(hdlg, ctx)
	}
}

get_board_from_control_states :: proc(hdlg: win.HWND, ctx: ^Main_Ctx) -> (result: Board, ok: bool) {

	log.debugf("Constructing board from control states...")

	// Collect all information in this board instance.
	board: Board

	board.pieces = ctx.current_pieces

	if win.IsDlgButtonChecked(hdlg, IDC_RADIOBUTTON_WHITE_TO_MOVE) == win.BST_CHECKED {
		board.turn_player = .white
	} else if win.IsDlgButtonChecked(hdlg, IDC_RADIOBUTTON_BLACK_TO_MOVE) == win.BST_CHECKED {
		board.turn_player = .black
	} else {
		ok = false
		return
	}

	board.white_can_castle_kingside  = win.IsDlgButtonChecked(hdlg, IDC_CHECKBOX_WHITE_CASTLE_KINGSIDE)  == win.BST_CHECKED
	board.white_can_castle_queenside = win.IsDlgButtonChecked(hdlg, IDC_CHECKBOX_WHITE_CASTLE_QUEENSIDE) == win.BST_CHECKED
	board.black_can_castle_kingside  = win.IsDlgButtonChecked(hdlg, IDC_CHECKBOX_BLACK_CASTLE_KINGSIDE)  == win.BST_CHECKED
	board.black_can_castle_queenside = win.IsDlgButtonChecked(hdlg, IDC_CHECKBOX_BLACK_CASTLE_QUEENSIDE) == win.BST_CHECKED

	en_passant_target_square_text := get_dialog_item_text(hdlg, IDC_TEXTBOX_EN_PASSANT_TARGET_SQUARE, 10, context.temp_allocator)
	en_passant_target_square, en_passant_target_square_ok := parse_en_passant_target_square(en_passant_target_square_text)
	if !en_passant_target_square_ok {
		ok = false
		return
	}
	board.en_passant_target_square = en_passant_target_square

	{
		success: win.BOOL
		board.halfmove_clock = cast(i32)win.GetDlgItemInt(hdlg, IDC_TEXTBOX_HALFMOVE_CLOCK, &success, bSigned = false)
		if !success {
			ok = false
			return
		}
	}

	{
		success: win.BOOL
		board.fullmove_number = cast(i32)win.GetDlgItemInt(hdlg, IDC_TEXTBOX_FULLMOVE_NUMBER, &success, bSigned = false)
		if !success {
			ok = false
			return
		}
	}

	return board, true
}

construct_fen_string_from_board :: proc(board: Board) -> (result: string, ok: bool) {
	fen_string := format_fen(board)
	return fen_string, true
}

parse_en_passant_target_square :: proc(s0: string) -> (result: Square_Specifier, ok: bool) {

	s := strings.trim_space(s0)
	if s == "" || s == "-" {
		// We interpret an empty string as "no en passant".
		return {}, true
	}
	if len(s) != 2 {
		log.warnf("Invalid en passant target square (string length must be 2): %v", s)
		return {}, false
	}

	// NOTE: While FEN only allows lowercase letters here, the text box accepts both.
	file: int
	if s[0] >= 'A' && s[0] <= 'H' {
		file = cast(int)s[0] - 'A'
	} else if s[0] >= 'a' && s[0] <= 'h' {
		file = cast(int)s[0] - 'a'
	} else {
		log.warnf("Invalid file in en passant target square: %v", s)
		return {}, false
	}

	rank := cast(int)s[1] - '1'
	if rank < 0 || rank >= 8 {
		log.warnf("Invalid rank in en passant target square: %v", s)
		return {}, false
	}

	return { file = cast(i8)file, rank = cast(i8)rank }, true
}
