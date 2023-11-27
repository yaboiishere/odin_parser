package parser

import "core:fmt"
import "core:log"
import "core:mem/virtual"
import "core:os"

main :: proc() {
	arena: virtual.Arena
	arena_init_error := virtual.arena_init_growing(&arena, 1024 * 1024 * 10)
	if arena_init_error != nil {
		fmt.println("Failed to initialize arena: ", arena_init_error)
		os.exit(1)
	}
	context.allocator = virtual.arena_allocator(&arena)
	context.logger = log.create_console_logger()

	filename := "file1.txt"
	source, file_read_ok := os.read_entire_file_from_filename(filename, context.allocator)
	if !file_read_ok {
		fmt.printf("Failed to read file %v", filename)
		os.exit(1)
	}
	source_str := transmute(string)source


	tokenizer := tokenizer_create(source_str, filename)
	tokens: [dynamic]Token

	for {
		token, expected_error := tokenizer_expect_one_of(
			&tokenizer,
			{IntConst{}, Text{value = ""}, EOF{}},
		)
		if expected_error != nil {
			log.error(expected_error)
			return
		}
		_, is_eof := token.token.(EOF)

		if is_eof {
			break
		}

		append(&tokens, token.token)
		next_token, next_expected_error := tokenizer_expect_one_of(
			&tokenizer,
			{Period{}, Semicolon{}},
		)

		if next_expected_error != nil {
			log.error(next_expected_error)
			return
		}

		_, next_is_eof := next_token.token.(EOF)

		if next_is_eof {
			break
		}

		append(&tokens, next_token.token)
	}

	fmt.printf("tokens: %v", tokens)
}
