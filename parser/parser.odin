package parser

import "core:fmt"
import "core:log"
import "core:mem/virtual"
import "core:os"

import "../dependencies/cli"

Command :: union {
	ParseFile,
	ParseUrl,
}

ParseFile :: struct {
	filename: string `cli:"f,filename/required"`,
}

ParseUrl :: struct {
	url: string `cli:"u,url/required"`,
}


main :: proc() {
	arena: virtual.Arena
	arena_init_error := virtual.arena_init_growing(&arena, 1024 * 1024 * 10)
	if arena_init_error != nil {
		fmt.println("Failed to initialize arena: ", arena_init_error)
		os.exit(1)
	}
	context.allocator = virtual.arena_allocator(&arena)
	context.logger = log.create_console_logger()
	arguments := os.args
	if len(arguments) < 2 {
		fmt.printf("Commands:\n\n")
		cli.print_help_for_union_type_and_exit(Command)
		os.exit(1)
	}

	command, _, cli_error := cli.parse_arguments_as_type(arguments[1:], Command)
	if cli_error != nil {
		fmt.println("Failed to parse arguments: ", cli_error)
		os.exit(1)
	}
	switch c in command {
	case ParseFile:
		parse_file(c)
	case ParseUrl:
		url, url_error := parse_url(c)
		if url_error != nil {
			fmt.println("Failed to parse url: ", url_error)
			os.exit(1)
		}

		fmt.println("url: ", url)
	}
}
