tool
extends EditorPlugin

func _enter_tree():
	add_custom_type("Console", "Control", preload("console_node.gd"), preload("icon_console.svg"));

func _exit_tree():
	remove_custom_type("Console");