package parser

import "core:fmt"
import "core:log"
import "core:mem/virtual"
import "core:os"
// import "core:strings"

main :: proc() {
	arena: virtual.Arena
	arena_buffer: [3 * 1024]byte

	arena_init_error := virtual.arena_init_buffer(&arena, arena_buffer[:])
	if arena_init_error != nil {
		fmt.printf("Error initializing arena %v\n", arena_init_error)
	}

	arena_allocator := virtual.arena_allocator(&arena)
	defer virtual.arena_destroy(&arena)

	context.allocator = arena_allocator
	context.logger = log.create_multi_logger(log.create_console_logger())

	input_file, input_file_open_error := os.open("test.parser", os.O_RDONLY)
	if input_file_open_error != os.ERROR_NONE {
		log.errorf("Error opening input file: %v\n", input_file_open_error)
	}
	defer os.close(input_file)

	current_char: []byte = {0}
	file_read_error: ReadError = os.ERROR_NONE

	symbols: [256]SymbolType
	symbols_count: int = 0

	for file_read_error == os.ERROR_NONE {
		symbol, read_error := getNextSymbol(&input_file, &current_char)
		_, is_eof_error := read_error.(EOF)
		if is_eof_error {
			break
		}
		if read_error != nil {
			log.errorf("Error reading input file: %v\n", read_error)
			file_read_error = read_error
		}

		symbols[symbols_count] = symbol
		symbols_count = symbols_count + 1
		getNextChar(&input_file, &current_char)

	}

	log.debugf("Symbols: %v\n", symbols[:symbols_count])
}
