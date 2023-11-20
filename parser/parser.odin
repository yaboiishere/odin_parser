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

	current_char: [1]byte
	file_read_error: ReadError = os.ERROR_NONE
	read_offset: int = 0

	// for file_read_error == os.ERROR_NONE && current_char[0] != 10 {
	// 	amount_read, read_error := getNextChar(input_file, current_char[:], read_offset)
	// 	if read_error != nil {
	// 		log.errorf("Error reading input file: %v\n", read_error)
	// 		file_read_error = read_error
	// 	}
	// 	if amount_read == 0 {
	// 		break
	// 	}
	// 	read_offset = read_offset + amount_read
	// 	// as_string := strings.string_from_ptr(raw_data(current_char[:]), amount_read)
	// 	fmt.printf("char: %v, total_read: %v\n", current_char, amount_read)
	// }
	for file_read_error == os.ERROR_NONE {
		amount_read, read_error := getNextSymbol()(&input_file, current_char[:], &read_offset)
		if read_error != nil {
			log.errorf("Error reading input file: %v\n", read_error)
			file_read_error = read_error
		}

		if amount_read == 0 {
			break
		}

		if current_char[0] == '\n' || current_char[0] == '\r' || current_char[0] == ' ' {
			continue
		}
		read_offset = read_offset + amount_read

	}
}
