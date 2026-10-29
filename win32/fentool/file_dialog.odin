package fen_tool

import runtime "base:runtime"
import strings "core:strings"
import log "core:log"
import win "core:sys/windows"

File_Dialog_Mode :: enum {
	open,
	save,
}

File_Dialog_Filter :: struct {
	// The full line of text displayed to the user in the selection box.
	//
	// Examples:
	//  - `"Text files (*.txt)"`
	//  - `"All files (*.*)"`
	display_text:  string,

	// The internal search pattern used to filter the files.
	//
	// Examples:
	//  - `"*.txt"`
	//  - `"*.*"` // NOTE: This includes files without an extension.
	filter:        string,
}

file_dialog :: proc(
	owner:                           win.HWND,
	mode:                            File_Dialog_Mode,
	initial_file:                    Maybe(string) = nil,
	filters:                         []File_Dialog_Filter = nil,
	#any_int selected_filter_index:  u32 = 0,
	dialog_caption:                  Maybe(string) = nil,
	initial_directory:               Maybe(string) = nil,
	allocator:                       runtime.Allocator = context.allocator,
) -> (
	dialog_confirmed:                bool,
	selected_file:                   string,
) {
	file_buf := make([]u16, win.MAX_PATH_WIDE, context.temp_allocator)
	file_buf[0] = 0

	if initial_file != nil {
		converted := win.utf8_to_wstring(file_buf, initial_file.?)
		if converted == nil {
			// Conversion error.
			log.warnf("Unable to convert initial file name string.")
			file_buf[0] = 0
		}
	}

	ofn := win.OPENFILENAMEW {
		lStructSize = size_of(win.OPENFILENAMEW),
		hwndOwner = owner,
		lpstrFilter = file_dialog_build_filter_string(filters),
		nFilterIndex = selected_filter_index + 1,
		lpstrFile = cast(win.LPWSTR)raw_data(file_buf[:]),
		nMaxFile = win.MAX_PATH_WIDE,
	}

	if dialog_caption != nil {
		ofn.lpstrTitle = win.utf8_to_wstring(dialog_caption.?, context.temp_allocator)
	}
	if initial_directory != nil {
		ofn.lpstrInitialDir = win.utf8_to_wstring(initial_directory.?, context.temp_allocator)
	}

	confirmed: win.BOOL

	switch mode {
	case .open:
		ofn.Flags = win.OFN_PATHMUSTEXIST | win.OFN_FILEMUSTEXIST | win.OFN_EXPLORER
		confirmed = win.GetOpenFileNameW(&ofn)
	case .save:
		ofn.Flags = win.OFN_OVERWRITEPROMPT | win.OFN_EXPLORER
		confirmed = win.GetSaveFileNameW(&ofn)
	case:
		unreachable()
	}

	if confirmed {
		// Convert result to string.
		path := cast(win.wstring)ofn.lpstrFile
		path_str, err1 := win.wstring_to_utf8(path, N = -1, allocator = allocator)
		if err1 != nil {
			log.warnf("File dialog confirmed - string conversion error: %v", err1)
			return false, ""
		}
		return true, path_str
	} else {
		return false, ""
	}
}

// Converts the `filters` slice to the string format required by `OPENFILENAMEW.lpstrFilter`.
//
// Returns `nil` if `filters` is an empty slice.
file_dialog_build_filter_string :: proc(filters: []File_Dialog_Filter, allocator: runtime.Allocator = context.temp_allocator) -> win.LPCWSTR {

	if len(filters) == 0 {
		return nil
	}

	needed_capacity := 0
	for f in filters {
		needed_capacity += len(f.display_text)
		needed_capacity += 1
		needed_capacity += len(f.filter)
		needed_capacity += 1
	}
	needed_capacity += 1

	sb: strings.Builder
	strings.builder_init_len_cap(&sb, 0, needed_capacity, context.temp_allocator)
	
	for f in filters {
		strings.write_string(&sb, f.display_text)
		strings.write_string(&sb, "\x00")
		strings.write_string(&sb, f.filter)
		strings.write_string(&sb, "\x00")
	}
	strings.write_string(&sb, "\x00")

	return win.utf8_to_wstring(strings.to_string(sb), allocator)
}
