package parser

import "core:log"
import "core:reflect"
import "core:strconv"
import "core:strings"

SourceToken :: struct {
	token:    Token,
	location: Location,
}

Token :: union {
	EOF,
	Text,
	IntConst,
	QuotedString,
	Semicolon,
	Period,
	Quote,
	Slash,
	Colon,
	Whitespace,
}

Text :: struct {
	value: string,
}

QuotedString :: struct {
	value: string,
}

IntConst :: struct {
	value: int,
}

Semicolon :: struct {}

Period :: struct {}

Quote :: struct {}

EOF :: struct {}

Slash :: struct {}

Colon :: struct {}

Whitespace :: struct {}


/*
A mutable structure that keeps track of and allows operations for looking at,
consuming and expecting tokens. Created with `tokenizer_create`.
*/
Tokenizer :: struct {
	filename: string,
	source:   string,
	index:    int,
	position: int,
	line:     int,
	column:   int,
}

ExpectationError :: union {
	ExpectedToken,
	ExpectedString,
	ExpectedEndMarker,
	ExpectedOneOf,
}

ExpectedTokenError :: union {
	ExpectedToken,
}

ExpectedToken :: struct {
	expected: Token,
	actual:   Token,
	location: Location,
}

ExpectedString :: struct {
	expected: string,
	actual:   string,
	location: Location,
}

ExpectedEndMarker :: struct {
	expected: []string,
	location: Location,
}

ExpectedOneOfError :: union {
	ExpectedOneOf,
}

ExpectedOneOf :: struct {
	expected: []Token,
	actual:   Token,
	location: Location,
}

Location :: struct {
	line:        int,
	column:      int,
	position:    int, // byte offset in source
	source_file: string,
}

// Creates a `Tokenizer` from a given source string. Use `tokenizer_peek`, `tokenizer_next_token`
// and `tokenizer_expect` variants to read tokens from a `Tokenizer`.
tokenizer_create :: proc(source: string, filename := "") -> Tokenizer {
	return Tokenizer{source = source, line = 1, filename = filename}
}

tokenizer_expect_exact :: proc(
	tokenizer: ^Tokenizer,
	expectation: Token,
) -> (
	token: SourceToken,
	error: Maybe(ExpectedToken),
) {
	start_location := Location {
		position = tokenizer.position,
		line     = tokenizer.line,
		column   = tokenizer.column,
	}
	read_token, _, _ := tokenizer_next_token(tokenizer)

	if read_token.token != expectation {
		return SourceToken{},
			ExpectedToken {
				expected = expectation,
				actual = read_token.token,
				location = start_location,
			}
	}

	return read_token, nil
}

tokenizer_expect_exact_one_of :: proc(
	tokenizer: ^Tokenizer,
	expectations: []Token,
) -> (
	token: SourceToken,
	error: Maybe(ExpectedOneOf),
) {
	start_location := Location {
		position = tokenizer.position,
		line     = tokenizer.line,
		column   = tokenizer.column,
	}
	read_token, _, _ := tokenizer_next_token(tokenizer)

	for expectation in expectations {
		if read_token.token == expectation {
			return read_token, nil
		}
	}

	return SourceToken{},
		ExpectedOneOf {
			expected = expectations,
			actual = read_token.token,
			location = start_location,
		}
}

tokenizer_expect :: proc(
	tokenizer: ^Tokenizer,
	expectation: Token,
) -> (
	token: SourceToken,
	error: Maybe(ExpectedToken),
) {
	start_location := Location {
		position = tokenizer.position,
		line     = tokenizer.line,
		column   = tokenizer.column,
	}
	read_token, _, _ := tokenizer_next_token(tokenizer)

	expectation_typeid := reflect.union_variant_typeid(expectation)
	token_typeid := reflect.union_variant_typeid(read_token.token)

	if expectation_typeid != token_typeid {
		return SourceToken{},
			ExpectedToken {
				expected = expectation,
				actual = read_token.token,
				location = start_location,
			}
	}

	return read_token, nil
}

tokenizer_expect_one_of :: proc(
	tokenizer: ^Tokenizer,
	expectations: []Token,
) -> (
	token: SourceToken,
	error: Maybe(ExpectedOneOf),
) {
	start_location := Location {
		position = tokenizer.position,
		line     = tokenizer.line,
		column   = tokenizer.column,
	}
	read_token, _, _ := tokenizer_next_token(tokenizer)

	for expectation in expectations {
		expectation_typeid := reflect.union_variant_typeid(expectation)
		token_typeid := reflect.union_variant_typeid(read_token.token)

		if expectation_typeid == token_typeid {
			return read_token, nil
		}
	}

	return SourceToken{},
		ExpectedOneOf {
			expected = expectations,
			actual = read_token.token,
			location = start_location,
		}
}

tokenizer_read_string_until :: proc(
	tokenizer: ^Tokenizer,
	end_markers: []string,
) -> (
	string: string,
	error: Maybe(ExpectedEndMarker),
) {
	start_location := Location {
		position = tokenizer.position,
		line     = tokenizer.line,
		column   = tokenizer.column,
	}
	source := tokenizer.source[tokenizer.position:]
	end_marker_index, _ := strings.index_multi(source, end_markers)
	if end_marker_index == -1 {
		return "", ExpectedEndMarker{expected = end_markers, location = start_location}
	}

	string = source[:end_marker_index]
	tokenizer.position += len(string)
	newline_count := strings.count(string, "\n")
	tokenizer.line += newline_count
	if newline_count > 0 {
		tokenizer.column = 1
	} else {
		tokenizer.column += end_marker_index
	}

	return string, nil
}

tokenizer_skip_string :: proc(
	tokenizer: ^Tokenizer,
	expected_string: string,
) -> (
	error: Maybe(ExpectedString),
) {
	start_location := Location {
		position = tokenizer.position,
		line     = tokenizer.line,
		column   = tokenizer.column,
	}

	source := tokenizer.source[tokenizer.position:]
	if !strings.has_prefix(source, expected_string) {
		rest_length := min(len(expected_string), len(source))

		return(
			ExpectedString {
				expected = expected_string,
				actual = source[:rest_length],
				location = start_location,
			} \
		)
	}

	tokenizer.position += len(expected_string)
	newline_count := strings.count(expected_string, "\n")
	tokenizer.line += newline_count
	if newline_count > 0 {
		tokenizer.column = len(expected_string) - strings.last_index(expected_string, "\n")
	} else {
		tokenizer.column += len(expected_string)
	}

	return nil
}

tokenizer_skip_any_of :: proc(tokenizer: ^Tokenizer, tokens: []Token) {
	match: for {
		token := tokenizer_peek(tokenizer)
		token_tag := reflect.union_variant_typeid(token)
		for t in tokens {
			t_tag := reflect.union_variant_typeid(t)
			if token_tag == t_tag {
				tokenizer_next_token(tokenizer)
				continue match
			}
		}
		break match
	}
}

tokenizer_next_token :: proc(
	tokenizer: ^Tokenizer,
) -> (
	source_token: SourceToken,
	index: int,
	ok: bool,
) {
	source_token = SourceToken {
		location = Location {
			position = tokenizer.position,
			line = tokenizer.line,
			column = tokenizer.column,
		},
	}
	if tokenizer.position >= len(tokenizer.source) {
		source_token.token = EOF{}

		return source_token, tokenizer.index, false
	}

	token := current(tokenizer, true)
	current_index := tokenizer.index
	tokenizer.index += 1

	source_token.token = token

	return source_token, current_index, token != nil
}

@(private = "package")
tokenizer_peek :: proc(tokenizer: ^Tokenizer) -> (token: Token) {
	if tokenizer.index >= len(tokenizer.source) {
		return nil
	}

	return current(tokenizer, false)
}

@(private = "file")
current :: proc(tokenizer: ^Tokenizer, modify: bool) -> (token: Token) {
	tokenizer_copy := tokenizer^
	defer if modify {
		tokenizer^ = tokenizer_copy
	}
	if tokenizer_copy.position >= len(tokenizer_copy.source) {
		return EOF{}
	}

	switch tokenizer_copy.source[tokenizer_copy.position] {
	case '\n':
		tokenizer_copy.position += 1
		tokenizer_copy.line += 1
		tokenizer_copy.column = 0

		return EOF{}

	case '.':
		tokenizer_copy.position += 1
		tokenizer_copy.column += 1

		return Period{}
	case ';':
		tokenizer_copy.position += 1
		tokenizer_copy.column += 1

		return Semicolon{}
	case '/':
		tokenizer_copy.position += 1
		tokenizer_copy.column += 1

		return Slash{}
	case ':':
		tokenizer_copy.position += 1
		tokenizer_copy.column += 1

		return Colon{}
	case ' ':
		tokenizer_copy.position += 1
		tokenizer_copy.column += 1

		return Whitespace{}
	case '\r':
		if tokenizer_copy.source[tokenizer_copy.position + 1] == '\n' {
			tokenizer_copy.position += 2
			tokenizer_copy.line += 1
			tokenizer_copy.column = 0

			return EOF{}
		} else {
			log.panicf(
				"Unexpected carriage return without newline at %v:%v",
				tokenizer_copy.line,
				tokenizer_copy.column,
			)
		}
	case '0' ..= '9':
		return read_integer(&tokenizer_copy)
	case '"':
		return read_string(&tokenizer_copy, `"`)
	case 'a' ..= 'z':
		return read_identifier(&tokenizer_copy)
	case 'A' ..= 'Z':
		return read_identifier(&tokenizer_copy)
	case:
		log.panicf(
			"Unexpected character '%c' @ %s:%d:%d (snippet: '%s')",
			tokenizer_copy.source[tokenizer_copy.position],
			tokenizer_copy.filename,
			tokenizer_copy.line,
			tokenizer_copy.column,
			tokenizer_copy.source[tokenizer_copy.position:tokenizer_copy.position],
		)
	}

	return nil
}

@(private = "file")
read_identifier :: proc(tokenizer: ^Tokenizer) -> (token: Token) {
	start := tokenizer.position
	source := tokenizer.source[start:]

	assert((source[0] >= 'a' && source[0] <= 'z') || (source[0] >= 'A' && source[0] <= 'Z'))

	symbol_value := read_until(source, " \t\n()[]{}<>:'\"/\\")
	symbol_length := len(symbol_value)
	tokenizer.position += symbol_length
	tokenizer.column += symbol_length

	return Text{value = symbol_value}
}

@(private = "file")
read_integer :: proc(tokenizer: ^Tokenizer) -> (token: Token) {
	start := tokenizer.position
	character := tokenizer.source[tokenizer.position]
	is_number := character >= '0' && character <= '9'
	if !is_number {
		return nil
	}

	for is_number {
		if tokenizer.position >= len(tokenizer.source) {
			break
		}
		character = tokenizer.source[tokenizer.position]
		switch character {
		case '0' ..= '9':
			tokenizer.position += 1
		case:
			is_number = false
		}
	}

	slice := tokenizer.source[start:tokenizer.position]
	int_value, parse_ok := strconv.parse_int(slice)
	if !parse_ok {
		log.panicf("Failed to parse integer ('%s') with state: %v", slice, tokenizer)
	}

	tokenizer.column += len(slice)

	return IntConst{value = int_value}
}

@(private = "file")
read_string :: proc(tokenizer: ^Tokenizer, quote_characters: string) -> (token: Token) {
	start := tokenizer.position
	character := string(tokenizer.source[tokenizer.position:tokenizer.position + 1])
	if character != quote_characters {
		return nil
	}

	rest_of_string := tokenizer.source[start + 1:]
	end_quote_index := strings.index(rest_of_string, quote_characters)
	if end_quote_index == -1 {
		log.panicf("Failed to find end quote for string: %s", rest_of_string)
	}
	string_contents := rest_of_string[:end_quote_index]
	// NOTE: 2 because we want to skip over the quote in terms of position; we've already read it
	tokenizer.position += end_quote_index + 2
	last_newline_index := strings.last_index(string_contents, "\n")
	if last_newline_index == -1 {
		tokenizer.column += len(string_contents) + 2
	} else {
		tokenizer.line += strings.count(string_contents, "\n")
		tokenizer.column = end_quote_index - last_newline_index
	}

	return QuotedString{value = string_contents}
}
