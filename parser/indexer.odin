package parser

import "core:strings"


TermPosition :: struct {
	term:     string,
	position: int,
}

DocumentToTerms :: map[string][]TermPosition

DocumentPosition :: struct {
	document: string,
	position: int,
}

TermsToDocuments :: map[string][dynamic]DocumentPosition

get_all_texts_from_html :: proc(html: Html) -> []string {
	raw_texts := get_all_texts_from_child(html.body)
	texts := [dynamic]string{}

	for text in raw_texts {
		trimmed_text := strings.trim_space(text)
		append(&texts, trimmed_text)
	}
	return texts[:]
}

get_all_texts_from_child :: proc(tag: HtmlTag) -> []string {
	texts := [dynamic]string{}
	switch t in tag {
	case string:
		append(&texts, t)
	case A:
		for child in t.children {
			new_texts := get_all_texts_from_child(child)
			append(&texts, ..new_texts[:])
		}
	case Body:
		for child in t.children {
			new_texts := get_all_texts_from_child(child)
			append(&texts, ..new_texts[:])
		}
	}

	return texts[:]
}

get_terms :: proc(documents: []string) -> (document_terms: DocumentToTerms) {
	for document in documents {
		terms := [dynamic]TermPosition{}
		words := strings.split(document, " ")
		for word, j in words {
			append(&terms, TermPosition{term = word, position = j})
		}
		document_terms[document] = terms[:]
	}
	return document_terms
}

clean_terms :: proc(doc_to_terms: DocumentToTerms) -> (cleaned_doc_to_terms: DocumentToTerms) {
	for doc, terms in doc_to_terms {
		cleaned_terms := [dynamic]TermPosition{}
		for term in terms {
			cleaned_term := clean_term(term.term)
			if is_meaningfull_word(cleaned_term) {
				append(&cleaned_terms, TermPosition{term = cleaned_term, position = term.position})
			}
		}
		cleaned_doc_to_terms[doc] = cleaned_terms[:]
	}
	return cleaned_doc_to_terms
}

is_meaningfull_word :: proc(word: string) -> bool {
	return(
		len(word) > 2 &&
		word != "the" &&
		word != "and" &&
		word != "then" &&
		word != "this" &&
		word != "that" &&
		word != "have" &&
		word != "has" \
	)
}

clean_term :: proc(raw_term: string) -> string {
	term := raw_term

	bad_chars := []string {
		".",
		",",
		":",
		";",
		"!",
		"?",
		"(",
		")",
		"[",
		"]",
		"{",
		"}",
		"'",
		"\"",
		"\\",
		"/",
	}

	for char in bad_chars {
		if strings.contains(term, char) {
			term, _ = strings.replace(term, char, "", -1)
		}
	}

	return strings.to_lower(term)
}

flip_terms :: proc(docs_to_terms: DocumentToTerms) -> (terms_to_docs: TermsToDocuments) {
	for document, terms in docs_to_terms {
		for term in terms {
			if terms_to_docs[term.term] == nil {
				terms_to_docs[term.term] = [dynamic]DocumentPosition{}
			}

			append(
				&terms_to_docs[term.term],
				DocumentPosition{document = document, position = term.position},
			)
		}
	}

	return terms_to_docs
}
