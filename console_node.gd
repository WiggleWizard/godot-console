extends Control

export(Font) var font_override;
export var console_switch_key     = "`";
export var use_key_over_action    = true;
export var clear_input_on_close   = true;
export var echo_commands          = true;
export var max_lines              = 100;
export var command_history_size   = 20;
export var enable_command_hinting = true;
export var enable_help            = true;
#export var enable_autocomplete    = true;


enum HistoryDirection {
	Up,
	Down
};
var _registered_commands = {
	# "command": {
	# 	"func_ref":  func_ref,
	# 	"tip":       tip,
	# 	"help":      help
	#};
};
var _command_history = [];
var _command_history_pos = 0;

onready var _input_text_box = $InputContainer/Input;
onready var _output_box     = $OutputContainer/Output;
onready var _command_tips   = $CommandTips;


########################################################
# PUBLIC
########################################################

# Toggles the console on / off
func toggle_console():
	set_visible(!is_visible());
	if is_visible():
		_input_text_box.grab_focus();
		
	# Clear inputs if appropriate
	if clear_input_on_close:
		_input_text_box.set_text("");
	
func register_command(command, func_ref, tip=null, help=null):
	_registered_commands[command] = {
		"func_ref":  func_ref,
		"tip":       tip,
		"help":      help
	};
	
func log_raw(string, print_as_bbcode=true):
	var output = _output_box;
	
	_filter_line_count();
	if print_as_bbcode:
		output.append_bbcode(string);
	else:
		output.add_text(string);
	output.newline();


########################################################
# EVENTS / OVERRIDES
########################################################

func _ready():
	if enable_help:
		register_command("help", funcref(self, "_internal_command_help"));

	$OutputContainer/Output.add_font_override("mono_font", font_override);
	$OutputContainer/Output.add_font_override("bold_font", font_override);
	$OutputContainer/Output.add_font_override("bold_italics_font", font_override);
	$OutputContainer/Output.add_font_override("italics_font", font_override);
	$OutputContainer/Output.add_font_override("normal_font", font_override);

	$InputContainer/Input.add_font_override("font", font_override);
	$InputContainer/Label.add_font_override("font", font_override);

func _input(event):
	if event is InputEventKey:
		var input_handled = false;
		var toggle_console = false;
		
		# Use console switch key variable above the action set in the project
		if use_key_over_action && console_switch_key.length() > 0:
			if char(event.unicode) == console_switch_key && !event.is_echo():
				toggle_console = true;
		else:
			if !event.is_echo() && event.is_action_pressed("ui_console"):
				toggle_console = true;
				
		if toggle_console:
			toggle_console();
			input_handled = true;
			
		# Deal with history cursor position changes
		if event.is_pressed() && !event.is_echo() && event.scancode == KEY_UP:
			_recall_history(HistoryDirection.Up);
			input_handled = true;
		elif event.is_pressed() && !event.is_echo() && event.scancode == KEY_DOWN:
			_recall_history(HistoryDirection.Down);
			input_handled = true;
			
		if input_handled:
			get_tree().set_input_as_handled();

# Bound to the input text box
func _on_console_input(event):
	if event is InputEventKey:
		# User pressed Enter
		if event.pressed && !event.is_echo() && event.scancode == KEY_ENTER:
			var stdin = "";
			stdin = _input_text_box.get_text();
			
			_exec(stdin);
			
			_input_text_box.set_text("");
		# Autocomplete tabbing
		elif event.pressed && !event.is_echo() && event.scancode == KEY_TAB:
			pass;
		# All other input will show tips if enabled
		elif enable_command_hinting:
			_command_tips.show_tips(_input_text_box.get_text(), _registered_commands, font_override);


########################################################
# INTERNAL
########################################################

func _internal_command_help(argv):
	# Figure out the longest command
	var longest_command_size = 0;
	for command in _registered_commands:
		if command.length() > longest_command_size:
			longest_command_size = command.length();

	log_raw("Available commands:", false);
	for command in _registered_commands:
		var s = "\t" + command;
		var tip = _registered_commands[command].tip;
		if tip:
			# Generate padding
			var padding = "";
			for i in range(longest_command_size - command.length()):
				padding += " ";

			s += padding + "    " + tip;

		log_raw(s, false);

func _filter_line_count():
	if _output_box.get_line_count() > max_lines:
		_output_box.remove_line(0);
		_output_box.update();

func _exec(stdin):
	_add_command_to_history(stdin);
	
	var stdin_split = _split_args(stdin);
	if stdin_split.size() == 0:
		return;
		
	# Find and execute the function reference associated with the command,
	# pass through the rest of the command as an array of arguments.
	var command = stdin_split[0];
	if command in _registered_commands:
		if echo_commands:
			log_raw("> " + stdin, false);
		
		stdin_split.remove(0);
		var func_ref = _registered_commands[command].func_ref;
		if func_ref:
			func_ref.call_func(stdin_split);

# Splits args by space and respects quotes.
# Will also strip out empties.
func _split_args(arg_string):
	var argv = PoolStringArray();

	var index = 0;
	var in_quotes = false;
	for c in arg_string:
		if c == ' ' && !in_quotes:
			index += 1;
			continue;
		elif c == '"':
			in_quotes = !in_quotes;
			continue;

		if argv.size() - index - 1 < 0:
			argv.push_back("");
			index = argv.size() - 1;

		argv[index] += c;
	
	return argv;

# Appends command to cache, manages overflow as well
func _add_command_to_history(stdin):
	_command_history.append(stdin);
	if _command_history.size() > command_history_size:
		_command_history.pop_front();
		
	# Reset the cursor
	_command_history_pos = _command_history.size();
	
# Moves cursor through history and also destructively modifies
# the input text box.
func _recall_history(direction):
	if _command_history.size() == 0:
		return;
		
	# Move cursor and clamp if needed
	if direction == HistoryDirection.Up:
		_command_history_pos -= 1;
		if _command_history_pos < 0:
			_command_history_pos = 0;
	else:
		_command_history_pos += 1;
		if _command_history_pos >= _command_history.size():
			_command_history_pos = _command_history.size();
			_input_text_box.set_text("");
			return;
			
	# Destructively set the text of the input box to the history
	# at the new cursor position.
	var command = _command_history[_command_history_pos];
	_input_text_box.set_text(command);
	_input_text_box.set_cursor_position(command.length());