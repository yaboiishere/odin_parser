package parser

import "core:log"
import "core:os"

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
	EOF,
}

ReadMoreThanOneByte :: struct {
	total_read: int,
}

EOF :: struct {}


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


getNextChar :: proc(file: ^os.Handle, current_char: ^[]byte) -> (int, ReadError) {
	total_read, error := os.read(file^, current_char^)
	if (error != os.ERROR_NONE) {
		return 0, error
	}

	if (total_read > 1) {
		return 0, ReadMoreThanOneByte{total_read = total_read}
	}

	return total_read, nil
}

getNextSymbol :: proc(
	file: ^os.Handle,
	current_char: ^[]byte,
) -> (
	symbol: SymbolType,
	err: ReadError,
) {
	digit := 0
	k := 0
	spelling: [10]byte

	for current_char[0] == ' ' ||
	    current_char[0] == '\n' ||
	    current_char[0] == '\t' ||
	    current_char[0] == 0 {
		bytes_read := getNextChar(file, current_char) or_return
		log.debugf("Read %v bytes", bytes_read)
		if (bytes_read == 0) {
			return nil, EOF{}
		}
	}

	// char := strings.string_from_ptr(current_char[:], 1)
	char := transmute(string)current_char[:]

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

	}

	log.debugf("Found a symbol %v, which was %v", symbol, char)
	return symbol, err
}

readFromFileWhile :: proc(
	file: os.Handle,
	buffer: []byte,
	aceptable_symbols: ..SymbolType,
) -> false {
	for {
		symbol, err := getNextSymbol(file, buffer)
		if (err != nil) {
			log.errorf("Error reading from file: %v", err)
			return
		}

		if (symbol == nil) {
			log.debug("Reached EOF")
			return
		}

		if (symbol in aceptable_symbols) {
			log.debugf("Found a symbol %v", symbol)
			continue
		}

		log.debugf("Found an unacceptable symbol %v", symbol)
		return
	}
}
