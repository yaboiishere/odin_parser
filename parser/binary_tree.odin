package parser

Node :: struct {
	value:       string,
	left_child:  ^Node,
	right_child: ^Node,
}

binary_tree_init :: proc(initial_value: string) -> Node {
	return Node{value = initial_value}
}

binary_tree_insert :: proc(node: ^Node, value: string) {
	if value < node.value {
		binary_tree_insert(node.left_child, value)
	} else {
		binary_tree_insert(node.right_child, value)
	}
}

binary_tree_search :: proc(node: ^Node, value: string) -> bool {
	if node == nil {
		return false
	}

	if node.value == value {
		return true
	}

	if value < node.value {
		return binary_tree_search(node.left_child, value)
	} else {
		return binary_tree_search(node.right_child, value)
	}
}
