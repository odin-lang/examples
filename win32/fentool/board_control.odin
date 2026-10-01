package fen_tool

import runtime "base:runtime"
import log "core:log"
import strings "core:strings"
import win "core:sys/windows"

BOARD_CONTROL_CLASS_NAME :: "board_control"

// Called on application startup to register the board control window class
// for use in the main dialog template.
board_control_register_class :: proc(instance: win.HINSTANCE) {
	wndclass := win.WNDCLASSEXW {
		cbSize = size_of(win.WNDCLASSEXW),
		style = win.CS_HREDRAW | win.CS_VREDRAW,
		lpfnWndProc = board_control_wndproc,
		cbWndExtra = size_of(rawptr),
		hInstance = instance,
		hCursor = win.LoadCursorA(nil, win.IDC_ARROW),
		hbrBackground = cast(win.HBRUSH)cast(uintptr)(win.COLOR_WINDOW + 1),
		lpszClassName = BOARD_CONTROL_CLASS_NAME,
	}
	win.RegisterClassExW(&wndclass)
}

// Called by the application whenever the board state changes.
board_control_set_board :: proc(hwnd: win.HWND, board: Board) {
	ctx := board_control_get_ctx(hwnd)
	if ctx.board != board {
		ctx.board = board
		win.InvalidateRect(hwnd, nil, true)
		log.debugf("Board changed.")
	} else {
		log.debugf("No board change detected.")
	}
}

// Called by the application when the user selects a different spritemap.
board_control_set_spritemap :: proc(hwnd: win.HWND, spritemap: Board_Control_Spritemap) {
	ctx := board_control_get_ctx(hwnd)
	if ctx.spritemap != spritemap {
		ctx.spritemap = spritemap
		// Invalidate the cached spritemap bitmap.
		win.DeleteObject(auto_cast ctx.spritemap_cache)
		ctx.spritemap_cache = nil
		win.InvalidateRect(hwnd, nil, true)
	}
}

Board_Control_Spritemap :: enum {
	normal,
	ginger,
}

board_control_get_spritemap_resource_name :: proc(spritemap: Board_Control_Spritemap) -> string {
	switch spritemap {
	case .normal:  return "IDR_PIECES_NORMAL"
	case .ginger:  return "IDR_PIECES_GINGER"
	case:          return "IDR_PIECES_NORMAL"
	}
}

@(private="file")
Board_Control_Ctx :: struct {
	runtime_context: ^runtime.Context,
	font: win.HFONT,
	// Copy of the board state visualized by the board control.
	board: Board,

	spritemap: Board_Control_Spritemap,
	spritemap_cache: win.HBITMAP,

	// Last known mouse client coordinates; needed for piece drag and drop.
	mouse_client: [2]i32,

	hover_mode: Board_Control_Hover_Mode,
	hovered_square: Square_Specifier,

	menu_open: bool,
	menu_square: Square_Specifier,

	pending_castling_right: Castling_Right,
	pending_castling_right_state: Castling_Right_State,

	dragging: bool,
	drag_from: Square_Specifier,
}

@(private="file")
Board_Control_Hover_Mode :: enum {
	none,
	// User is currently using the mouse to highlight squares.
	mouse,
	// User is currently using the keyboard (arrow keys) to highlight squares.
	keyboard,
}

Castling_Right :: enum {
	white_kingside,
	white_queenside,
	black_kingside,
	black_queenside,
}

Castling_Right_State :: enum {
	allow,
	disallow,
}

//
// Notifications
//
// When the user interacts with the board control (e.g. place a piece), this control
// will notify the parent. The authority to execute the requested action lies with
// the parent.
//

// Notification code for `NMHDR.code`
Board_Control_Notification_Code :: enum win.UINT {
	none,
	hover,
	place_piece,
	set_en_passant_target_square,
	set_castling_right,
	exchange_pieces,
}

NM_BOARD_CONTROL_NOTIFICATION :: struct {
	// Adhere to standard Win32 notification structure:
	// This struct must start with an `NMHDR`.
	hdr:                   win.NMHDR,
	hovering:              bool,
	square:                Square_Specifier,
	piece:                 Board_Piece,
	castling_right:        Castling_Right,
	castling_right_state:  Castling_Right_State,
	square2:               Square_Specifier,
}

// Called by the board control when the hovered square has changed,
// either through mouse or keyboard interaction.
//
// Will update state and notify the parent if appropriate.
board_control_set_hovered_square :: proc(hwnd: win.HWND, ctx: ^Board_Control_Ctx, mode: Board_Control_Hover_Mode, square: Square_Specifier) {
	if ctx.hover_mode == mode && ctx.hovered_square == square {
		// No change.
		return
	}
	ctx.hover_mode = mode
	ctx.hovered_square = square
	is_hovering := mode != .none
	board_control_notify_cell_hover(hwnd, is_hovering, square)
	win.InvalidateRect(hwnd, nil, true)
}

board_control_notify_cell_hover :: proc(hwnd: win.HWND, hovering: bool, square: Square_Specifier) {
	parent := win.GetParent(hwnd)
	if parent == nil {
		return
	}
	nm := NM_BOARD_CONTROL_NOTIFICATION {
		hdr = {
			hwndFrom = hwnd,
			idFrom = cast(uintptr)win.GetDlgCtrlID(hwnd),
			code = cast(win.UINT)Board_Control_Notification_Code.hover,
		},
		hovering = hovering,
		square = square,
	}
	win.SendMessageW(parent, win.WM_NOTIFY, nm.hdr.idFrom, cast(win.LPARAM)cast(uintptr)&nm)
}

board_control_notify_piece :: proc(hwnd: win.HWND, square: Square_Specifier, piece: Board_Piece) {
	parent := win.GetParent(hwnd)
	if parent == nil {
		return
	}
	nm := NM_BOARD_CONTROL_NOTIFICATION {
		hdr = {
			hwndFrom = hwnd,
			idFrom = cast(uintptr)win.GetDlgCtrlID(hwnd),
			code = cast(win.UINT)Board_Control_Notification_Code.place_piece,
		},
		square = square,
		piece = piece,
	}
	win.SendMessageW(parent, win.WM_NOTIFY, nm.hdr.idFrom, cast(win.LPARAM)cast(uintptr)&nm)
}

board_control_notify_exchange_pieces :: proc(hwnd: win.HWND, square1, square2: Square_Specifier) {
	parent := win.GetParent(hwnd)
	if parent == nil {
		return
	}
	nm := NM_BOARD_CONTROL_NOTIFICATION {
		hdr = {
			hwndFrom = hwnd,
			idFrom = cast(uintptr)win.GetDlgCtrlID(hwnd),
			code = cast(win.UINT)Board_Control_Notification_Code.exchange_pieces,
		},
		square  = square1,
		square2 = square2,
	}
	win.SendMessageW(parent, win.WM_NOTIFY, nm.hdr.idFrom, cast(win.LPARAM)cast(uintptr)&nm)
}

board_control_notify_set_en_passant_target_square :: proc(hwnd: win.HWND, square: Square_Specifier) {
	parent := win.GetParent(hwnd)
	if parent == nil {
		return
	}
	nm := NM_BOARD_CONTROL_NOTIFICATION {
		hdr = {
			hwndFrom = hwnd,
			idFrom = cast(uintptr)win.GetDlgCtrlID(hwnd),
			code = cast(win.UINT)Board_Control_Notification_Code.set_en_passant_target_square,
		},
		square = square,
	}
	win.SendMessageW(parent, win.WM_NOTIFY, nm.hdr.idFrom, cast(win.LPARAM)cast(uintptr)&nm)
}

board_control_notify_set_castling_right :: proc(hwnd: win.HWND, castling_right: Castling_Right, state: Castling_Right_State) {
	parent := win.GetParent(hwnd)
	if parent == nil {
		return
	}
	nm := NM_BOARD_CONTROL_NOTIFICATION {
		hdr = {
			hwndFrom = hwnd,
			idFrom = cast(uintptr)win.GetDlgCtrlID(hwnd),
			code = cast(win.UINT)Board_Control_Notification_Code.set_castling_right,
		},
		castling_right = castling_right,
		castling_right_state = state,
	}
	win.SendMessageW(parent, win.WM_NOTIFY, nm.hdr.idFrom, cast(win.LPARAM)cast(uintptr)&nm)
}

@(private="file")
board_control_get_ctx :: proc "contextless" (hwnd: win.HWND) -> ^Board_Control_Ctx {
	return cast(^Board_Control_Ctx)cast(uintptr)win.GetWindowLongPtrW(hwnd, 0)
}

@(private="file")
board_control_wndproc :: proc "system" (hwnd: win.HWND, msg: win.UINT, wparam: win.WPARAM, lparam: win.LPARAM) -> win.LRESULT {

	switch msg {

	case win.WM_CREATE:
		// Setup window context.
		context = window_context_tls
		ctx := new(Board_Control_Ctx)
		ctx.runtime_context = &window_context_tls
		win.SetWindowLongPtrW(hwnd, 0, cast(win.LONG_PTR)cast(uintptr)ctx)

	case win.WM_NCDESTROY:
		ctx := board_control_get_ctx(hwnd)
		context = ctx.runtime_context^
		win.DeleteObject(auto_cast ctx.spritemap_cache)
		ctx.spritemap_cache = nil
		free(ctx)

	case win.WM_SETFONT:
		// Standard Win32 infrastructure for controls that draw text.
		// Called by the parent (either explicitly or through DS_SETFONT).
		ctx := board_control_get_ctx(hwnd)
		ctx.font = cast(win.HFONT)wparam

	case win.WM_GETFONT:
		// Standard Win32 infrastructure for controls that draw text.
		ctx := board_control_get_ctx(hwnd)
		return cast(win.LRESULT)cast(uintptr)ctx.font

	case win.WM_SIZE:
		// Make sure that the control stays a square.
		rc: win.RECT
		win.GetWindowRect(hwnd, &rc)
		w := rc.right - rc.left
		h := rc.bottom - rc.top
		if w != h {
			// Use the width here for both.
			// NOTE: min(w,h) could cause the control to shrink unexpectedly on DPI changes.
			win.SetWindowPos(hwnd, nil, 0, 0, w, w, win.SWP_NOZORDER | win.SWP_NOMOVE)
			return 0
		}

	case win.WM_MOUSEMOVE:
		ctx := board_control_get_ctx(hwnd)
		context = ctx.runtime_context^
		x_client := win.GET_X_LPARAM(lparam)
		y_client := win.GET_Y_LPARAM(lparam)
		// Update drag and drop target coordinates for painting the dragged piece.
		board_control_set_drag_target_coords(hwnd, ctx, x_client, y_client)
		square, ok := board_control_get_square_from_client_coords(hwnd, x_client, y_client)
		board_control_set_hovered_square(hwnd, ctx, ok ? .mouse : .none, square)
		// Setup mouse event tracking so that we get WM_MOUSELEAVE.
		tme := win.TRACKMOUSEEVENT {
			cbSize = size_of(win.TRACKMOUSEEVENT),
			hwndTrack = hwnd,
			dwFlags = win.TME_LEAVE,
		}
		win.TrackMouseEvent(&tme)

	case win.WM_MOUSELEAVE:
		ctx := board_control_get_ctx(hwnd)
		context = ctx.runtime_context^
		board_control_set_hovered_square(hwnd, ctx, .none, {})

	case win.WM_LBUTTONDOWN:
		ctx := board_control_get_ctx(hwnd)
		context = ctx.runtime_context^

		win.SetCapture(hwnd)

		// Setup piece drag operation
		x_client := win.GET_X_LPARAM(lparam)
		y_client := win.GET_Y_LPARAM(lparam)
		square, ok := board_control_get_square_from_client_coords(hwnd, x_client, y_client)
		if ok {
			win.SetFocus(hwnd)
			// You can only drag if there is a piece on that square.
			if ctx.board.pieces[square.rank * 8 + square.file].type != .none {
				ctx.dragging = true
				ctx.mouse_client = { x_client, y_client }
				ctx.drag_from = square
				win.InvalidateRect(hwnd, nil, true)
			}
		}

	case win.WM_LBUTTONUP:
		ctx := board_control_get_ctx(hwnd)
		context = ctx.runtime_context^

		// Release mouse capture.
		if win.GetCapture() == hwnd {
			win.SetCapture(nil)
		}

		if ctx.dragging {
			// Complete piece dragging operation.
			x_client := win.GET_X_LPARAM(lparam)
			y_client := win.GET_Y_LPARAM(lparam)
			ctx.dragging = false
			square_to, ok := board_control_get_square_from_client_coords(hwnd, x_client, y_client)
			square_from := ctx.drag_from
			if ok {
				if square_to == square_from {
					// Released over the same square. Do nothing.
				} else {
					// Exchange these 2 pieces. This also handles the case where the target square is empty.
					board_control_notify_exchange_pieces(hwnd, square_from, square_to)
				}
			} else {
				// Was released somewhere not over the board.
				// Delete the piece from the "from" square, but don't put it anywhere.
				board_control_notify_piece(hwnd, square_from, {})
			}
			win.InvalidateRect(hwnd, nil, true)
		}

	case win.WM_CONTEXTMENU:

		ctx := board_control_get_ctx(hwnd)
		context = ctx.runtime_context^
		x_screen := win.GET_X_LPARAM(lparam)
		y_screen := win.GET_Y_LPARAM(lparam)
		x_client: i32
		y_client: i32

		if x_screen == -1 && y_screen == -1 {
			// This was triggered by a non-mouse event (e.g. the "VK_APPS" key on the keyboard).
			// NOTE: This is ambiguous. (-1, -1) could technically be valid screen coordinates
			//       in a multi-monitor scenario. This is an API flaw.
			// In this case, we open the context menu at the center of the currently hovered square.
			target_square := ctx.hovered_square
			target_file := cast(i32)target_square.file
			target_rank := cast(i32)target_square.rank
			client: win.RECT
			win.GetClientRect(hwnd, &client)
			x, y, w, h := board_control_get_board_bounds(hwnd, client)
			square_rect := win.RECT {
				left   = auto_cast (x + (w * (target_file  )) / 8),
				top    = auto_cast (y + (h * (7-target_rank)) / 8),
				right  = auto_cast (x + (w * (target_file+1)) / 8),
				bottom = auto_cast (y + (h * (8-target_rank)) / 8),
			}
			x_client = square_rect.left + (square_rect.right - square_rect.left) / 2
			y_client = square_rect.top  + (square_rect.bottom - square_rect.top) / 2
			pt := win.POINT { x_client, y_client }
			win.ClientToScreen(hwnd, &pt)
			x_screen = pt.x
			y_screen = pt.y
		} else {
			pt := win.POINT { x_screen, y_screen }
			win.ScreenToClient(hwnd, &pt)
			x_client = pt.x
			y_client = pt.y
		}

		log.debugf("lparam: 0x%8x - screen x, y: %v, %v - client x, y: %v %v", lparam, x_screen, y_screen, x_client, y_client)
		square, ok := board_control_get_square_from_client_coords(hwnd, x_client, y_client)
		if ok {
			// Load and open the context menu.
			hInstance := cast(win.HINSTANCE)cast(uintptr)win.GetWindowLongPtrW(hwnd, win.GWLP_HINSTANCE)
			menu := win.LoadMenuW(hInstance, "IDM_BOARD_CONTEXT_MENU")
			if menu == nil {
				error := win.GetLastError()
				msg := get_system_error_message(error)
				log.errorf("Could not load menu: %v", msg)
				break
			}
			defer win.DestroyMenu(menu)
			// NOTE: A context menu must be a popup menu specifically. If defined in a resource as a menu template,
			//       the containing menu is just a dummy "main menu".
			popup := win.GetSubMenu(menu, 0)
			if popup == nil {
				error := win.GetLastError()
				msg := get_system_error_message(error)
				log.errorf("Could not popup menu: %v", msg)
				break
			}

			// Display a string like "E4" in the square info text.
			square_info_text := board_format_position(square, context.temp_allocator)
			set_menu_item_text(popup, IDM_SQUARE_INFO, square_info_text)

			// Allow setting the en passant target square if rank is eligible for it (on the "3" or "6" rank).
			allow_set_en_passant_target_square := square.rank == 2 || square.rank == 5
			win.EnableMenuItem(popup, IDM_SET_EN_PASSANT_TARGET_SQUARE, allow_set_en_passant_target_square ? win.MF_ENABLED : win.MF_GRAYED)

			// Allow toggling castling rights if the clicked square is a rook square.
			// This menu item has dynamic functionality, depending on the clicked square and the previous castling rights.
			castling_right_toggle, castling_right_toggle_state, castling_right_toggle_enable := board_control_get_castling_right_toggle_action(ctx, square)
			win.EnableMenuItem(popup, IDM_TOGGLE_CASTLING_RIGHT, castling_right_toggle_enable ? win.MF_ENABLED : win.MF_GRAYED)
			if castling_right_toggle_enable {
				ctx.pending_castling_right = castling_right_toggle
				ctx.pending_castling_right_state = castling_right_toggle_state
				string_resource_id: win.UINT
				switch castling_right_toggle {
				case .white_kingside:
					string_resource_id = castling_right_toggle_state == .allow ? IDS_ALLOW_CASTLING_WHITE_KINGSIDE : IDS_DISALLOW_CASTLING_WHITE_KINGSIDE
				case .white_queenside:
					string_resource_id = castling_right_toggle_state == .allow ? IDS_ALLOW_CASTLING_WHITE_QUEENSIDE : IDS_DISALLOW_CASTLING_WHITE_QUEENSIDE
				case .black_kingside:
					string_resource_id = castling_right_toggle_state == .allow ? IDS_ALLOW_CASTLING_BLACK_KINGSIDE : IDS_DISALLOW_CASTLING_BLACK_KINGSIDE
				case .black_queenside:
					string_resource_id = castling_right_toggle_state == .allow ? IDS_ALLOW_CASTLING_BLACK_QUEENSIDE : IDS_DISALLOW_CASTLING_BLACK_QUEENSIDE
			}
			label := load_string_resource(hInstance, string_resource_id, context.temp_allocator)
			set_menu_item_text(popup, IDM_TOGGLE_CASTLING_RIGHT, label)
			}

			ctx.menu_open = true
			ctx.menu_square = square
			defer {
				ctx.menu_open = false
				win.InvalidateRect(hwnd, nil, true)
			}

			// Actually shows the menu, and returns when the menu is closed.
			// The action chosen by the user (if any) is sent as a WM_COMMAND message.
			win.TrackPopupMenu(popup, 0, x_screen, y_screen, 0, hwnd, nil)
		}

	case win.WM_MENUSELECT:
		// Conventional Win32 infrastructure:
		// Notify the parent of the selected (i.e. hovered) menu item so that it can
		// update the status bar text with a hint text, if applicable.
		parent := win.GetParent(hwnd)
		if parent != nil {
			return win.SendMessageW(parent, msg, wparam, lparam)
		}

	case win.WM_GETDLGCODE:
		// Instructs `IsDialogMessageW` in the main message loop that this control
		// wants to handle arrow keys. Otherwise, arrow keys would be swallowed by
		// keyboard navigation logic in `IsDialogMessageW`.
		// We need the arrow keys to navigate through the squares on the board.
		return win.DLGC_WANTARROWS

	case win.WM_SETFOCUS:
		ctx := board_control_get_ctx(hwnd)
		context = ctx.runtime_context^
		if ctx.hover_mode != .keyboard {
			ctx.hover_mode = .keyboard
			win.InvalidateRect(hwnd, nil, true)
		}

	case win.WM_KILLFOCUS:
		ctx := board_control_get_ctx(hwnd)
		context = ctx.runtime_context^
		board_control_set_hovered_square(hwnd, ctx, .none, {})
		win.InvalidateRect(hwnd, nil, true)

	case win.WM_KEYDOWN:
		// Change selected square with the arrow keys.
		vk := wparam
		switch vk {
		case win.VK_LEFT:   keyboard_navigate_square(hwnd, -1,  0); return 0
		case win.VK_UP:     keyboard_navigate_square(hwnd,  0,  1); return 0
		case win.VK_RIGHT:  keyboard_navigate_square(hwnd,  1,  0); return 0
		case win.VK_DOWN:   keyboard_navigate_square(hwnd,  0, -1); return 0
		}

		keyboard_navigate_square :: proc "contextless" (hwnd: win.HWND, delta_file, delta_rank: i8) {
			ctx := board_control_get_ctx(hwnd)
			context = ctx.runtime_context^
			// NOTE: We could use independent state variables for the "keyboard-hovered" square.
			rank := clamp(ctx.hovered_square.rank + delta_rank, 0, 7)
			file := clamp(ctx.hovered_square.file + delta_file, 0, 7)
			square := Square_Specifier { rank = rank, file = file }
			board_control_set_hovered_square(hwnd, ctx, .keyboard, square)
		}

	case win.WM_COMMAND:
		ctx := board_control_get_ctx(hwnd)
		context = ctx.runtime_context^
		id := win.LOWORD(wparam)
		nc := win.HIWORD(wparam)
		log.debugf("Board control command: id: %v - nc: %v", id, nc)

		switch id {
		case IDM_CLEAR_SQUARE:  board_control_notify_piece(hwnd, ctx.menu_square, { .none, nil })

		case IDM_ROOK_WHITE:    board_control_notify_piece(hwnd, ctx.menu_square, { .rook,   .white })
		case IDM_KNIGHT_WHITE:  board_control_notify_piece(hwnd, ctx.menu_square, { .knight, .white })
		case IDM_BISHOP_WHITE:  board_control_notify_piece(hwnd, ctx.menu_square, { .bishop, .white })
		case IDM_QUEEN_WHITE:   board_control_notify_piece(hwnd, ctx.menu_square, { .queen,  .white })
		case IDM_KING_WHITE:    board_control_notify_piece(hwnd, ctx.menu_square, { .king,   .white })
		case IDM_PAWN_WHITE:    board_control_notify_piece(hwnd, ctx.menu_square, { .pawn,   .white })
		case IDM_ROOK_BLACK:    board_control_notify_piece(hwnd, ctx.menu_square, { .rook,   .black })
		case IDM_KNIGHT_BLACK:  board_control_notify_piece(hwnd, ctx.menu_square, { .knight, .black })
		case IDM_BISHOP_BLACK:  board_control_notify_piece(hwnd, ctx.menu_square, { .bishop, .black })
		case IDM_QUEEN_BLACK:   board_control_notify_piece(hwnd, ctx.menu_square, { .queen,  .black })
		case IDM_KING_BLACK:    board_control_notify_piece(hwnd, ctx.menu_square, { .king,   .black })
		case IDM_PAWN_BLACK:    board_control_notify_piece(hwnd, ctx.menu_square, { .pawn,   .black })

		case IDM_SET_EN_PASSANT_TARGET_SQUARE:
			board_control_notify_set_en_passant_target_square(hwnd, ctx.menu_square)
		case IDM_TOGGLE_CASTLING_RIGHT:
			board_control_notify_set_castling_right(hwnd, ctx.pending_castling_right, ctx.pending_castling_right_state)
		}

	case win.WM_ERASEBKGND:
		// Suppress this: All painting is done in WM_PAINT through buffered painting to prevent flicker.
		return 1

	case win.WM_PAINT:
		ctx := board_control_get_ctx(hwnd)
		context = ctx.runtime_context^

		// Setup WM_PAINT infrastructure.
		ps: win.PAINTSTRUCT
		hdc0 := win.BeginPaint(hwnd, &ps)
		defer win.EndPaint(hwnd, &ps)

		// Setup buffered painting (to prevent flicker).
		hdc: win.HDC
		paintbuffer := win.BeginBufferedPaint(hdc0, &ps.rcPaint, .BPBF_TOPDOWNDIB, nil, &hdc)
		defer win.EndBufferedPaint(paintbuffer, true)

		// Fill background
		{
			brush := win.CreateSolidBrush(win.RGB(255, 255, 255))
			defer win.DeleteObject(auto_cast brush)
			win.FillRect(hdc, &ps.rcPaint, brush)
		}

		// Prepare board squares

		client: win.RECT
		win.GetClientRect(hwnd, &client)
		bx, by, bw, bh := board_control_get_board_bounds(hwnd, client)

		dark_square_brush := win.CreateSolidBrush(win.RGB(175, 185, 170))
		defer win.DeleteObject(auto_cast dark_square_brush)
		light_square_brush := win.CreateSolidBrush(win.RGB(205, 215, 200))
		defer win.DeleteObject(auto_cast light_square_brush)
		highlight_square_brush: win.HBRUSH
		if ctx.hover_mode != .none || ctx.menu_open {
			// NOTE: This brush does not need to be freed.
			highlight_square_brush = win.GetSysColorBrush(win.COLOR_HIGHLIGHT)
		}
		en_passant_highlight_color := win.RGB(255, 127, 0)
		castling_right_highlight_color := win.RGB(0, 255, 255)

		highlight_thickness := adjust_for_dpi(hwnd, 3)

		should_highlight_square :: proc(ctx: ^Board_Control_Ctx, square: Square_Specifier) -> bool {
			if ctx.menu_open {
				return square == ctx.menu_square
			} else if ctx.hover_mode != .none {
				return square == ctx.hovered_square
			} else {
				return false
			}
		}

		// Paint board squares

		// rank index 0 is rank "1"
		// file index 0 is file "A"
		for rank in 0 ..< i32(8) {
			for file in 0 ..< i32(8) {
				square_rect := win.RECT {
					left   = auto_cast (bx + (bw * (file  )) / 8),
					top    = auto_cast (by + (bh * (7-rank)) / 8),
					right  = auto_cast (bx + (bw * (file+1)) / 8),
					bottom = auto_cast (by + (bh * (8-rank)) / 8),
				}
				square := Square_Specifier { rank = cast(i8)rank, file = cast(i8)file }
				brush: win.HBRUSH
				if should_highlight_square(ctx, square) {
					brush = highlight_square_brush
				} else {
					is_dark_square := (rank + file) % 2 != 0
					brush = is_dark_square ? dark_square_brush : light_square_brush
				}
				win.FillRect(hdc, &square_rect, brush)

				// Highlight square if en passant
				if ctx.board.en_passant_target_square != {} && ctx.board.en_passant_target_square == square {
					stroke_rectangle_precise(hdc, square_rect, en_passant_highlight_color, thickness = highlight_thickness)
				}

				// Highlight square if castling right
				highlight_for_castling := (ctx.board.white_can_castle_queenside && file == 0 && rank == 0) ||
				                          (ctx.board.white_can_castle_kingside  && file == 7 && rank == 0) ||
				                          (ctx.board.black_can_castle_queenside && file == 0 && rank == 7) ||
				                          (ctx.board.black_can_castle_kingside  && file == 7 && rank == 7)
				if highlight_for_castling {
					stroke_rectangle_precise(hdc, square_rect, castling_right_highlight_color, thickness = highlight_thickness)
				}
			}
		}

		// Paint border (board frame)

		stroke_rectangle_precise(hdc, client, win.RGB(0, 0, 0))
		board_rc := win.RECT { bx, by, bx + bw, by + bh }
		stroke_rectangle_precise(hdc, board_rc, win.RGB(0, 0, 0), -1)

		// Paint file and rank names

		previous_font := cast(win.HFONT)win.SelectObject(hdc, auto_cast ctx.font)
		defer win.SelectObject(hdc, auto_cast previous_font)

		for file in 0 ..< i32(8) {
			label_rect := win.RECT {
				left   = auto_cast (bx + (bw * (file  )) / 8),
				top    = board_rc.bottom,
				right  = auto_cast (bx + (bw * (file+1)) / 8),
				bottom = client.bottom,
			}
			file_string := cast(rune)('A' + file)
			sb := strings.builder_make_len_cap(0, 4, context.temp_allocator)
			strings.write_rune(&sb, file_string)
			win.DrawTextExW(hdc, win.utf8_to_wstring(strings.to_string(sb), context.temp_allocator), -1, &label_rect, .DT_SINGLELINE | .DT_CENTER | .DT_VCENTER | .DT_NOPREFIX, nil)
		}

		for rank in 0 ..< i32(8) {
			label_rect := win.RECT {
				left   = client.left,
				top    = auto_cast (by + (bh * (7-rank)) / 8),
				right  = board_rc.left,
				bottom = auto_cast (by + (bh * (8-rank)) / 8),
			}
			rank_string := cast(rune)('1' + rank)
			sb := strings.builder_make_len_cap(0, 4, context.temp_allocator)
			strings.write_rune(&sb, rank_string)
			win.DrawTextExW(hdc, win.utf8_to_wstring(strings.to_string(sb), context.temp_allocator), -1, &label_rect, .DT_SINGLELINE | .DT_CENTER | .DT_VCENTER | .DT_NOPREFIX, nil)
		}

		// Prepare pieces

		if ctx.spritemap_cache == nil {
			// We cache the image so we don't have to load it every time.
			ctx.spritemap_cache = load_pieces_png(ctx.spritemap)
			log.debugf("Spritemap '%v' loaded: %v", ctx.spritemap, ctx.spritemap_cache)
		}
		piece_sprites := ctx.spritemap_cache
		if piece_sprites == nil {
			err := win.GetLastError()
			msg := get_system_error_message(err, allocator = context.temp_allocator)
			log.errorf("Error loading piece sprite bitmap: %v", msg)
		}

		load_pieces_png :: proc(spritemap: Board_Control_Spritemap) -> win.HBITMAP {
			resource_name := board_control_get_spritemap_resource_name(spritemap)
			hModule := win.GetModuleHandleW(nil)
			return load_hbitmap_from_png_rcdata(hModule, win.utf8_to_wstring(resource_name, context.temp_allocator))
		}

		// Paint pieces

		if piece_sprites != nil {
			hdc_src := win.CreateCompatibleDC(hdc)
			defer win.DeleteDC(hdc_src)
			previous_bitmap := win.SelectObject(hdc_src, auto_cast piece_sprites)
			defer win.SelectObject(hdc_src, previous_bitmap)
			for rank in 0 ..< i32(8) {
				for file in 0 ..< i32(8) {
					if ctx.dragging && ctx.drag_from.file == auto_cast file && ctx.drag_from.rank == auto_cast rank {
						// Skip this; it's the piece currently being dragged.
						continue
					}
					piece := ctx.board.pieces[rank * 8 + file]
					if piece.type != .none {
						square_rect := win.RECT {
							left   = auto_cast (bx + (bw * (file  )) / 8),
							top    = auto_cast (by + (bh * (7-rank)) / 8),
							right  = auto_cast (bx + (bw * (file+1)) / 8),
							bottom = auto_cast (by + (bh * (8-rank)) / 8),
						}
						xd := square_rect.left
						yd := square_rect.top
						wd := square_rect.right - square_rect.left
						hd := square_rect.bottom - square_rect.top
						sx, sy, sw, sh := board_control_get_sprite_src(piece)
						bf := win.BLENDFUNCTION {
							BlendOp = win.AC_SRC_OVER,
							AlphaFormat = win.AC_SRC_ALPHA,
							SourceConstantAlpha = 255,
						}
						win.GdiAlphaBlend(
							hdc, xd, yd, wd, hd,
							hdc_src, sx, sy, sw, sh,
							bf,
						)
					}
				}
			}

			// Paint the dragged piece, if any.
			if ctx.dragging {
				from_rank := cast(i32)ctx.drag_from.rank
				from_file := cast(i32)ctx.drag_from.file
				piece := ctx.board.pieces[from_rank * 8 + from_file]
				square_rect := win.RECT {
					left   = auto_cast (bx + (bw * (from_file  )) / 8),
					top    = auto_cast (by + (bh * (7-from_rank)) / 8),
					right  = auto_cast (bx + (bw * (from_file+1)) / 8),
					bottom = auto_cast (by + (bh * (8-from_rank)) / 8),
				}
				wd := square_rect.right - square_rect.left
				hd := square_rect.bottom - square_rect.top
				sx, sy, sw, sh := board_control_get_sprite_src(piece)
				xd := ctx.mouse_client[0] - wd / 2
				yd := ctx.mouse_client[1] - hd / 2
				bf := win.BLENDFUNCTION {
					BlendOp = win.AC_SRC_OVER,
					AlphaFormat = win.AC_SRC_ALPHA,
					SourceConstantAlpha = 255,
				}
				win.GdiAlphaBlend(
					hdc, xd, yd, wd, hd,
					hdc_src, sx, sy, sw, sh,
					bf,
				)
			}
		}
	}

	return win.DefWindowProcW(hwnd, msg, wparam, lparam)
}

adjust_for_dpi :: proc(hwnd: win.HWND, i: i32) -> i32 {
	lpy := win.GetDpiForWindow(hwnd)
	return cast(i32)(cast(f64)lpy / 96.0 * cast(f64)i)
}

// Returns the castling right toggle action that is appropriate for clicking on the specified square.
// E.g. if the user clicks on A1, they can toggle the castling right for white queenside.
// The `toggle_state` will be the opposite state (allow/disallow) of the current board state.
board_control_get_castling_right_toggle_action :: proc(
	ctx: ^Board_Control_Ctx,
	square: Square_Specifier,
) -> (
	castling_right: Castling_Right,
	toggle_state: Castling_Right_State,
	enable: bool,
) {
	currently_allowed: bool
	switch {
	case square.rank == 0 && square.file == 0:
		castling_right = .white_queenside
		currently_allowed = ctx.board.white_can_castle_queenside
	case square.rank == 0 && square.file == 7:
		castling_right = .white_kingside
		currently_allowed = ctx.board.white_can_castle_kingside
	case square.rank == 7 && square.file == 0:
		castling_right = .black_queenside
		currently_allowed = ctx.board.black_can_castle_queenside
	case square.rank == 7 && square.file == 7:
		castling_right = .black_kingside
		currently_allowed = ctx.board.black_can_castle_kingside
	case:
		enable = false
		return
	}
	enable = true
	if currently_allowed {
		toggle_state = .disallow
	} else {
		toggle_state = .allow
	}
	return
}

board_control_get_board_bounds :: proc(hwnd: win.HWND, client: win.RECT) -> (x, y, w, h: i32) {
	BORDER_WIDTH_PX :: 18
	border_thickness := adjust_for_dpi(hwnd, BORDER_WIDTH_PX)
	x = client.left + border_thickness
	y = client.top + border_thickness
	w = client.right - x - border_thickness
	h = client.bottom - y - border_thickness
	min_wh := min(w, h)
	w = min_wh
	h = min_wh
	return
}

board_control_get_square_from_client_coords :: proc(hwnd: win.HWND, client_x, client_y: i32) -> (square: Square_Specifier, ok: bool) {
	client: win.RECT
	win.GetClientRect(hwnd, &client)
	x, y, w, h := board_control_get_board_bounds(hwnd, client)
	X := client_x - x
	Y := client_y - y
	if X < 0 || Y < 0 || X >= w || Y >= h {
		ok = false
		return
	}
	file :=     cast(i8)(cast(f64)X / cast(f64)w * 8.0)
	rank := 7 - cast(i8)(cast(f64)Y / cast(f64)h * 8.0)
	if file < 0 || file >= 8 || rank < 0 || rank >= 8 {
		ok = false
		return
	}
	return { file = file, rank = rank }, true
}

// Get the source rectangle for the sprite for `piece` in the sprite map.
board_control_get_sprite_src :: proc(piece: Board_Piece) -> (x, y, w, h: i32) {
	if piece.type == .none {
		return
	}
	if piece.type < .FIRST || piece.type > .LAST {
		return
	}
	if piece.color < .FIRST || piece.color > .LAST {
		return
	}
	SQUARE_SIZE_PX :: 128
	w = SQUARE_SIZE_PX
	h = SQUARE_SIZE_PX
	col := cast(i32)piece.type - 1
	row := cast(i32)piece.color
	x = col * SQUARE_SIZE_PX
	y = row * SQUARE_SIZE_PX
	return
}

// Stores the specified mouse client coordinates for the visual position of the currently dragged piece.
//
// Coordinates values (-1, -1) mean that the mouse is not over the board.
board_control_set_drag_target_coords :: proc(hwnd: win.HWND, ctx: ^Board_Control_Ctx, x_client, y_client: i32) {
	if ctx.dragging && ctx.mouse_client != { x_client, y_client } {
		ctx.mouse_client = { x_client, y_client }
		win.InvalidateRect(hwnd, nil, true)
	}
}
