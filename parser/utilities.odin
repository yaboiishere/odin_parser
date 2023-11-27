package parser

import "core:strings"

read_until :: proc(s: string, characters: string) -> string {
	character_index := strings.index_any(s, characters)
	if character_index == -1 {
		return s
	}

	v := s[:character_index]

	return v
}
