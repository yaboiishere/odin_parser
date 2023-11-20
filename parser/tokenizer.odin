package parser

import "core:log"
import "core:os"
import "core:strings"

SymbolType :: union {
	String,
	IntConst,
	Text,
	Semicolon,
	Period,
	Quotes,
	Other,
}

String :: struct {}
IntConst :: struct {}
Text :: struct {}
Semicolon :: struct {}
Period :: struct {}
Quotes :: struct {}
Other :: struct {}

TokenizerError :: union {
	InvalidToken,
}

InvalidToken :: struct {
	actual_token:   SymbolType,
	expected_token: SymbolType,
}

ReadError :: union {
	ReadMoreThanOneByte,
	os.Errno,
}

ReadMoreThanOneByte :: struct {
	total_read: int,
}


accept :: proc(current_symbol: SymbolType, accepted_symbol: SymbolType) -> bool {
	if (current_symbol == accepted_symbol) {
		return true
	}
	return false
}

expect :: proc(current_symbol: SymbolType, expected_symbol: SymbolType) -> (bool, TokenizerError) {
	if (accept(current_symbol, expected_symbol)) {
		return true, nil
	}
	return false, InvalidToken{actual_token = current_symbol, expected_token = expected_symbol}
}


getNextChar :: proc(
	file: ^os.Handle,
	current_char: []byte,
	read_offset: ^int,
) -> (
	int,
	ReadError,
) {
	total_read, error := os.read_at(file^, current_char, i64(read_offset^))
	if (error != os.ERROR_NONE) {
		return 0, error
	}

	if (total_read > 1) {
		return 0, ReadMoreThanOneByte{total_read = total_read}
	}

	read_offset^ = read_offset^ + total_read

	return total_read, nil
}

getNextSymbol :: proc(
	file: ^os.Handle,
	current_char: []byte,
	offset: ^int,
) -> (
	symbol: SymbolType,
) {
	digit := 0
	k := 0
	spelling: [10]byte
	bonus_offset := 0

	char := strings.string_from_ptr(raw_data(current_char), 1)

	switch current_char[0] {
	case 'a' ..= 'z', 'A' ..= 'Z':
		log.debug("Found a letter")
		for {
			if k < 10 {
				spelling[k] = current_char[0]
				k = k + 1
			} else {
				break
			}
		}
		symbol = String{}

	case:
		symbol = Other{}
		getNextSymbol(file, current_char, offset)
	}

	log.debug("Found a symbol %v, which was", symbol, char)
	return symbol
}
