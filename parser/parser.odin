package parser

import "core:fmt"
import "core:log"
import "core:mem/virtual"
import "core:os"

import "../dependencies/cli"

Command :: union {
	ParseFile,
	ParseUrl,
	DNSLookup,
	HttpGet,
	ParseHtml,
	Exercise,
}

ParseFile :: struct {
	filename: string `cli:"f,filename/required"`,
}

ParseUrl :: struct {
	url: string `cli:"u,url/required"`,
}

DNSLookup :: struct {
	hostname: string `cli:"h,hostname/required"`,
}

HttpGet :: struct {
	url:  string `cli:"u,url/required"`,
	file: string `cli:"f,file/optional"`,
}

ParseHtml :: struct {
	file: string `cli:"f,file/required"`,
}

Exercise :: struct {
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
		url, url_error := parse_url_cli(c)
		if url_error != nil {
			fmt.println("Failed to parse url: ", url_error)
			os.exit(1)
		}

		fmt.println("url: ", url)

	case DNSLookup:
		ipv4, ipv4Error := dnsLookup(c)

		if ipv4Error != nil {
			fmt.println("Failed to lookup dns: ", ipv4Error)
			os.exit(1)
		}

		fmt.println("ipv4: ", ipv4)

	case HttpGet:
		resp, err := http_get(c.url, c.file)
		if err != nil {
			fmt.println("Failed to get url: ", err)
			os.exit(1)
		}

		fmt.println("resp: ", resp)

	case ParseHtml:
		resp, html_error := parse_html_file(c.file)

		if html_error != nil {
			fmt.println("Failed to parse html: ", html_error)
			os.exit(1)
		}

		fmt.println("resp: ", resp)

	case Exercise:
		exercise(c.url)
	}
}

exercise :: proc(url: string) {

	filename := "html.tmp"
	_, err := http_get(url, filename)
	if err != nil {
		fmt.println("Failed to get url: ", err)
		os.exit(1)
	}

	parsed, parse_error := parse_html_file(filename)
	if parse_error != nil {
		fmt.println("Failed to parse html: ", parse_error)
		os.exit(1)
	}

	for child in parsed.body.children {
		_, is_a := child.(A)
		if is_a {
			fmt.println("href: ", child.(A).href)
		}
	}

	texts := get_all_texts_from_html(parsed)
	fmt.println("texts: ", texts)

	terms := get_terms(texts)

	fmt.println("terms: ", terms)

	cleaned_terms := clean_terms(terms)

	fmt.println("cleaned_terms: ", cleaned_terms)

	flipped := flip_terms(cleaned_terms)

	fmt.println("flipped: ", flipped)
	os.remove(filename)
}
