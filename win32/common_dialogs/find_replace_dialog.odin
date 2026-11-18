package comdlg32_example

import fmt "core:fmt"
import win "core:sys/windows"

// Registered window message ID for the find/replace messages.
g_find_replace_msg: win.UINT

// The current find/replace window handle needs to be stored
// so we can handle dialog messages (IsDialogMessageW) correctly.
// This simple approach (using a global variable) implies that
// only one find/replace window can be open at any time.
g_current_find_replace_window: win.HWND

Find_Replace_Ctx :: struct {
	fr:           win.FINDREPLACEW,
	find_buf:     []win.WCHAR,
	replace_buf:  []win.WCHAR,
}

find_text :: proc(
	owner: win.HWND,
	initial_search_string: string = "",
	max_find_string_length: int = 200,
) {
	if g_current_find_replace_window != nil {
		// Search/replace window is already open.
		win.SetActiveWindow(g_current_find_replace_window)
		return
	}

	if g_find_replace_msg == 0 {
		// Need to register the find/replace window message first.
		g_find_replace_msg = win.RegisterWindowMessageW(win.FINDMSGSTRINGW)
	}

	// This is a modeless dialog, which means the contextual memory required
	// by the dialog must survive this procedure call, until the dialog
	// reports that it is terminating (FR_DIALOGTERM).
	ctx := new(Find_Replace_Ctx)
	ctx.find_buf = make([]win.WCHAR, max_find_string_length + 1)

	if initial_search_string != "" {
		conversion_result := win.utf8_to_utf16(ctx.find_buf[:], initial_search_string)
		if conversion_result == nil {
			// Conversion failure (noncritical).
			ctx.find_buf[0] = 0
		}
	}

	ctx.fr = win.FINDREPLACEW {
		lStructSize = size_of(win.FINDREPLACEW),
		hwndOwner = owner,
		Flags = win.FR_SHOWWRAPAROUND,
		lpstrFindWhat = raw_data(ctx.find_buf[:]),
		wFindWhatLen = cast(win.WORD)len(ctx.find_buf),
		lCustData = cast(win.LPARAM)cast(uintptr)ctx,
	}

	g_current_find_replace_window = win.FindTextW(&ctx.fr)
}

replace_text :: proc(
	owner: win.HWND,
	initial_search_string: string = "",
	initial_replace_string: string = "",
	max_find_string_length: int = 200,
	max_replace_string_length: int = 200,
) {
	if g_current_find_replace_window != nil {
		win.SetActiveWindow(g_current_find_replace_window)
		return
	}

	if g_find_replace_msg == 0 {
		// Need to register the find/replace window message first.
		g_find_replace_msg = win.RegisterWindowMessageW(win.FINDMSGSTRINGW)
	}

	// This is a modeless dialog, which means the contextual memory required
	// by the dialog must survive this procedure call, until the dialog
	// reports that it is terminating (FR_DIALOGTERM).
	ctx := new(Find_Replace_Ctx)
	ctx.find_buf = make([]win.WCHAR, max_find_string_length + 1)
	ctx.replace_buf = make([]win.WCHAR, max_replace_string_length + 1)

	if initial_search_string != "" {
		conversion_result := win.utf8_to_utf16(ctx.find_buf[:], initial_search_string)
		if conversion_result == nil {
			// Conversion failure (noncritical).
			ctx.find_buf[0] = 0
		}
	}

	if initial_replace_string != "" {
		conversion_result := win.utf8_to_utf16(ctx.replace_buf[:], initial_replace_string)
		if conversion_result == nil {
			// Conversion failure (noncritical).
			ctx.replace_buf[0] = 0
		}
	}

	ctx.fr = win.FINDREPLACEW {
		lStructSize = size_of(win.FINDREPLACEW),
		hwndOwner = owner,
		Flags = win.FR_SHOWWRAPAROUND,
		lpstrFindWhat = raw_data(ctx.find_buf[:]),
		lpstrReplaceWith = raw_data(ctx.replace_buf[:]),
		wFindWhatLen = cast(win.WORD)len(ctx.find_buf),
		wReplaceWithLen = cast(win.WORD)len(ctx.replace_buf),
		lCustData = cast(win.LPARAM)cast(uintptr)ctx,
	}

	g_current_find_replace_window = win.ReplaceTextW(&ctx.fr)
	if g_current_find_replace_window == nil {
		// Dialog creation failed.
		delete_find_replace_context(ctx)
	}
}

delete_find_replace_context :: proc(ctx: ^Find_Replace_Ctx) {
	if ctx == nil {
		return
	}
	if ctx.find_buf != nil {
		delete(ctx.find_buf)
		ctx.find_buf = nil
	}
	if ctx.replace_buf != nil {
		delete(ctx.replace_buf)
		ctx.replace_buf = nil
	}
	free(ctx)
}

handle_find_replace_message :: proc(hwnd: win.HWND, wparam: win.WPARAM, lparam: win.LPARAM) {
	fr := cast(^win.FINDREPLACEW)cast(uintptr)lparam
	fr_ctx := cast(^Find_Replace_Ctx)cast(uintptr)fr.lCustData
	if fr.Flags & win.FR_DIALOGTERM != 0 {
		// Terminate dialog. We can free any memory allocated
		// here for the find/replace dialog, and invalidate any handles.
		fmt.printfln("Find/Replace dialog closed.")
		delete_find_replace_context(fr_ctx)
		g_current_find_replace_window = nil
		return
	}
	search_direction_down := fr.Flags & win.FR_DOWN != 0
	whole_word := fr.Flags & win.FR_WHOLEWORD != 0
	match_case := fr.Flags & win.FR_MATCHCASE != 0
	wrap_around := fr.Flags & win.FR_WRAPAROUND != 0
	if fr.Flags & win.FR_FINDNEXT != 0 {
		needle := cast(win.wstring)fr.lpstrFindWhat
		fmt.printfln("Find/Replace: Find next: %v - down: %v - whole word: %v - match case: %v - wrap around: %v",
			needle, search_direction_down, whole_word, match_case, wrap_around,
		)
	}
	if fr.Flags & win.FR_REPLACE != 0 {
		find := cast(win.wstring)fr.lpstrFindWhat
		replace := cast(win.wstring)fr.lpstrReplaceWith
		fmt.printfln("Find/Replace: Replace next: %v -> %v - down: %v - whole word: %v - match case: %v - wrap around: %v",
			find, replace, search_direction_down, whole_word, match_case, wrap_around,
		)
	}
	if fr.Flags & win.FR_REPLACEALL != 0 {
		find := cast(win.wstring)fr.lpstrFindWhat
		replace := cast(win.wstring)fr.lpstrReplaceWith
		fmt.printfln("Find/Replace: Replace all: %v -> %v - down: %v - whole word: %v - match case: %v - wrap around: %v",
			find, replace, search_direction_down, whole_word, match_case, wrap_around,
		)
	}
}
