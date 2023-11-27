package parser

import "core:fmt"
import "core:log"
import "core:os"

parse_file :: proc(parse_file_arguments: ParseFile) {
	filename := parse_file_arguments.filename
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
			{IntConst{}, QuotedString{value = ""}, EOF{}},
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
