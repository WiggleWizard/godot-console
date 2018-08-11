extends MarginContainer

onready var _list = $MarginContainer/VBoxContainer;


func show_tips(command_substr, command_list, font):
	# If the command is blank then hide the tips list
	if(command_substr.length() == 0):
		hide();
		return;

	# Clear the tips list
	for child in _list.get_children():
		child.hide();
		child.queue_free();

	# Hack to get root parent to size correctly
	margin_top = 0;

	var command_matches = 0;
	for command in command_list:
		if(command.begins_with(command_substr)):
			var new_label = Label.new();
			new_label.set_text(command);
			_list.add_child(new_label);
			
			if(font):
				new_label.add_font_override("font", font);

			command_matches += 1;
	if(command_matches == 0):
		hide();
	else:
		show();
		update();	