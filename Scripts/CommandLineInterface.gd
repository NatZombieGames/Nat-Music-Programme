extends PanelContainer

@onready var output_scene : PackedScene = load(^"res://Scenes/CliOutputLabel.tscn")
@onready var main_screen : Control = get_node(^"/root/MainScreen")
@onready var playing_screen : Control = get_node(^"/root/MainScreen/Camera/AspectRatioContainer/PlayerContainer/PlayingScreen")
@onready var command_line_interface : PanelContainer = self
@onready var master_directory_manager : Node = MasterDirectoryManager
@export var active : bool = false
@export var auto_clear : bool = false
var check_call_arg_type : Callable = (func(arg : String) -> String: var msg : String = arg.right(arg.find("/") * -1); return arg.replace(msg, ""))
var set_arg_type_callable : Callable = (
	func(arg : String) -> Variant: 
		if check_call_arg_type.call(arg) in ["int", "bool"," vec2", "arr"]:
			match check_call_arg_type.call(arg):
				"int":
					return int(arg.right(-4))
				"bool":
					return arg.right(-5) in boolean_strings
				"vec2":
					return Vector2(int(arg.right(-5).split(",", false)[0]), int(arg.right(-5).split(",", false)[1]))
				"arr":
					return Array(arg.right(-4).split(",", false)).map(set_arg_type_callable)
		return arg)
const commands : PackedStringArray = ["echo", "call", "set", "get"]
const command_minimum_args : PackedInt32Array = [1, 1, 2, 1]
const set_and_get_types : PackedStringArray = ["user_settings", "player_settings"]
const special_commands : PackedStringArray = ["help", "clear", "auto_clear", "info", "error_codes", "read", "close", "exit", "hard_reload"]
const debug_commands : PackedStringArray = ["print_id_dict"]
const callables : Dictionary = {"MasterDirectoryManager": ["save_data", "set_user_settings"], "CommandLineInterface": ["print_to_output", "run_command"], "MainScreen": ["play", "set_favourite"], "PlayingScreen": ["reset_playing_screen", "set_player_settings"]}
const boolean_strings : PackedStringArray = ["1", "true", "enabled", "yes", "on"]
var callables_commands : Array[String] = []
#   const after ready

func _ready() -> void:
	callables.values().map(func(item : Array) -> Array: callables_commands.append_array(item); return item)
	callables_commands.make_read_only()
	#
	%InputField.text_submitted.connect(func(text : String) -> void: run_command(text); return)
	#
	if MasterDirectoryManager.finished_loading_data == false:
		await MasterDirectoryManager.finished_loading_data_signal
	if MasterDirectoryManager.user_data_dict["command_on_startup"] != "":
		run_command(MasterDirectoryManager.user_data_dict["command_on_startup"], true)
	auto_clear = MasterDirectoryManager.user_data_dict["auto_clear"]
	#var test : String = "arr/int/15,bool/true,hello"
	#print(set_arg_type_callable.call(test))
	#print(type_string(typeof(set_arg_type_callable.call(test))))
	return

func run_command(command : String, bypass_active : bool = false) -> int:
	if (not active) and (bypass_active == false):
		return ERR_CANT_RESOLVE
	if auto_clear:
		%OutputContainer.get_children().map(func(node : Node) -> Node: node.queue_free(); return node)
	var command_chunks : PackedStringArray = command.split("-", false)
	print("command chunks during run command from the command '" + command + "':\n" + str(command_chunks))
	if command_chunks[0].to_lower() in special_commands:
		print("command is a special command")
		match command_chunks[0].to_lower():
			"help":
				print_to_output(
					("[b]NMP CLI Help Page:[/b]
					 Welcome to the NMP (Nat Music Programme) CLI (Command Line Interface) Help Page! Please look below for information on how to effectively use the CLI.
					
					[i]Command Structure:[/i]
					 When writing a command, you must seperate each argument with a hiphon (-), unless it does not have any arguments, in which case only the name is neaded.
					 For example, writing a command to print 'Hello World!' to the output could look like; [u]echo-Hello World![/u]
					 For available commands and their possible arguments, please see the 'Commands' section below.
					
					[i]Special Commands.[/i]
					- [color=green]help[/color]
					  - Opens the 'NMP CLI Help Page'.
					- [color=green]clear[/color]
					  - Clears the output.
					- [color=green]auto_clear[/color] (0+)
					  - If used with no arguments, tells you the state of auto_clear, otherwise sets autoclear to the argument given, must be a Boolean.
					- [color=green]info[/color]
					  - Prints info about the programme.
					- [color=green]error_codes[/color] (1)
					  - Prints the name for the given error code (argument 1).
					- [color=green]read[/color] (1)
					  - Prints the data for the given ID (argument 1).
					- [color=green]close[/color]
					  - Closes the CLI.
					- [color=green]exit[/color]
					  - Closes the programme, if you have 'save_on_quit' enabled then it will save before exiting.
					- [color=green]hard_reload[/color]
					  - Reloades the programme, same as 'HardReloadApp' shortcut.
					    !WARNING! This will not save beforehand, this is equivilent to exiting without saving and re-opening.
					
					[i]Commands.[/i]
					- [color=green]echo[/color] (1+)
					  - Prints the first argument. If the first argument is the 'call' command, can be used to print the output/returned values of the command, 
					    can be used to see the return values of certain functions.
					- [color=green]call[/color] (2+)
					  - Calls the given function (argument 1), with all other arguments being given to the called function. The available functions to call are:
					    - [color=orange]play[/color] (1)
					      - Starts playing the songs from an Artist, Album, Playlist or an individual Song with the given ID (argument 1).
					    - [color=orange]reset_playing_screen[/color]
					      - Resets the playing screen and stops all audio.
					    - [color=orange]set_favourite[/color] (1)
					      - Toggles the 'favourite' setting on a Artist, Album, Song or Playlist between On and Off, depending on the ID given (argument 1). Returns an error code.
					    - [color=orange]print_to_output[/color] (1)
					      - Prints the given argument to the output, the same as [u]echo-{argument}[/u] except 'print_to_output' does not call commands if the first argument is 'call'.
					    - [color=orange]set_player_setting[/color] (2)
					      - Sets a setting on the music player, the setting it sets is the first argument and the value to set it to is the second argument. Returns an error code.
					    - [color=orange]get_player_settings[/color]
					      - Returns all the settings that 'set_player_setting' can set, and their possible values if there is a finite number of possible values,
					        the first value in the list will be the settings default value.
					    - [color=orange]set_user_setting[/color] (2)
					      - Sets a setting inside your user data, the setting it sets is the first argument and the value to set it to is the second argument. Returns an error code.
					    - [color=orange]get_user_settings[/color]
					      - Returns all the settings that 'set_user_setting' can set, and their possible values if there is a finite number of possible values,
					        the first value in the list will be the settings default value. Note these are not all the values stored inside user data.
					    - [color=orange]run_command[/color] (1)
					      - Runs the rest of the command as a command, intended to be used with 'echo' to check for errors when writing commands.
					
					[i]Argument Types.[/i]
					 When giving argument to a function/command, by default they will all be a String, which is just the characters you put in. But some functions will want other numbers,
					 for example trying to enabled the 'shuffle' setting on the player using 'set_player_setting' will want a Boolean value of what to set the value to, you can see the types
					 and how to cast them below.
					
					 - {argument}
					   - The default, returns a String as whatever the argument was, Strings are used in cases such as wanting an ID.
					 - bool/{argument}
					   - This will return a Boolean (true or false) depending on the argument, it will return True if the argument is either 1, true, enabled, on or yes, and will return false otherwise.
					 - int/{argument}
					   - This will return an Integer (whole number) depending on the argument, for example a value of 'int/15' would return the number 15.}}").replace("\t", ""))
			"clear":
				%OutputContainer.get_children().map(func(node : Node) -> Node: node.queue_free(); return node)
			"auto_clear":
				if len(command_chunks) > 1:
					if check_call_arg_type.call(command_chunks[1]) != "bool":
						print_to_output("[i]ERROR: Invalid argument, please use a Boolean value.[/i]")
						return ERR_INVALID_PARAMETER
					auto_clear = command_chunks[1].right(-5) in boolean_strings
					print_to_output("[i]Auto-Clear is now [u]" + ["Disabled", "Enabled"][int(auto_clear)] + "[/u].[/i]")
				else:
					print_to_output("[i]Auto-Clear is currently set to; [u]" + str(auto_clear).capitalize() + "[/u].[/i]")
			"info":
				print_to_output(
					("[b]NMP Info:[/b]
					-Version: [i]" + GeneralManager.version + "[/i]
					-Build: [i]" + GeneralManager.build + "[/i]
					-Location: [i]" + OS.get_executable_path() + "[/i]
					- [color=orange]-[/color]Data Location: [i]" + MasterDirectoryManager.data_location + "[/i]
					-License: [i]" + FileAccess.open("res://LICENSE.txt", FileAccess.READ).get_as_text().get_slice("\n", 2) + "[/i]
					-Source Location: [url=www.google.com]Github[/url]").replace("\t", "").replace("\n-", "\n[color=green]-[/color]"))
			"error_codes":
				if len(command_chunks) < 2:
					print_to_output("[i][u]ERROR: No error code given to see context about.[/u][/i]")
					return ERR_INVALID_PARAMETER
				if not typeof(command_chunks[1]) in [TYPE_STRING, TYPE_INT] or error_string(int(command_chunks[1])) == "(invalid error code)":
					print_to_output("[i][u]ERROR: Not a valid error code.[/u][/i]")
					return ERR_INVALID_PARAMETER
				print_to_output("-Error Code " + str(int(command_chunks[1])) + ": " + error_string(int(command_chunks[1])))
			"read":
				if len(command_chunks) < 2:
					print_to_output("[i][u]ERROR: No ID given to read, please provide an ID.")
					return ERR_INVALID_PARAMETER
				if GeneralManager.get_id_type(command_chunks[1]) == MasterDirectoryManager.use_type.UNKNOWN:
					print_to_output("[i][u]ERROR: Unable to read data for the ID of: " + command_chunks[1] + ", as it is not a valid ID.[/u][/i]")
					return ERR_INVALID_PARAMETER
				if command_chunks[1] in MasterDirectoryManager.get(MasterDirectoryManager.get_data_types.call()[int(command_chunks[1][0])] + &"_id_dict").keys():
					print_to_output("[i][u]ERROR: Unable to read for the ID of: " + command_chunks[1] + ", as it is not an existing ID, please check it and try again.[/u][/i]")
					return ERR_INVALID_PARAMETER
				var data : Dictionary = MasterDirectoryManager.get_object_data.call(command_chunks[1])
				var to_print : String = "[b]ID [u]" + command_chunks[1] + "[/u] Data:[/b]"
				for item : String in (func() -> PackedStringArray: var keys : Array = data.keys(); keys.sort_custom(func(x : String, y : String) -> bool: return x < y); return keys).call():
					to_print += "\n-" + item + ": [i]" + str(data[item]) + "[/i]"
				print_to_output(to_print)
			"close":
				active = false
				self.visible = false
				%InputField.release_focus()
			"exit":
				if MasterDirectoryManager.user_data_dict["save_on_quit"]:
					MasterDirectoryManager.save_data()
					if MasterDirectoryManager.finished_saving_data == false:
						await MasterDirectoryManager.finished_saving_data_signal
				get_tree().quit()
			"hard_reload":
				get_tree().reload_current_scene()
	elif ((command_chunks[0].to_lower() == "debug") and (len(command_chunks) > 1) and (command_chunks[1] in debug_commands) and (GeneralManager.is_in_debug.call() == true)):
		print("command is a debug command")
		match command_chunks[1]:
			"print_id_dict":
				if len(command_chunks) < 3:
					print_to_output("[i][u]ERROR: No argument given, please give an argument.[/u][/i]")
					return ERR_INVALID_PARAMETER
				if not (command_chunks[2] in MasterDirectoryManager.get_data_types.call() or command_chunks[2] == "user"):
					print_to_output("[i][u]ERROR: Not a valid argument, please give a valid argument.[/u][/i]")
					return ERR_INVALID_PARAMETER
				if len(command_chunks) < 4:
					print_to_output("[b]" + command_chunks[2].capitalize() + " ID Dict:[/b]\n" + str(MasterDirectoryManager.get(command_chunks[2] + ["_id_dict", "_data_dict"][int(command_chunks[2] == "user")])))
				else:
					match command_chunks[3]:
						"keys":
							print_to_output("[b]" + command_chunks[2].capitalize() + " ID Dict Keys:[/b]\n" + str(MasterDirectoryManager.get(command_chunks[2] + ["_id_dict", "_data_dict"][int(command_chunks[2] == "user")]).keys()))
						"values":
							print_to_output("[b]" + command_chunks[2].capitalize() + " ID Dict Values:[/b]\n" + str(MasterDirectoryManager.get(command_chunks[2] + ["_id_dict", "_data_dict"][int(command_chunks[2] == "user")]).values()))
						_:
							print_to_output("[i][u]ERROR: Not a valid argument, please give a valid argument.[/u][/i]")
							return ERR_INVALID_PARAMETER
	elif command_chunks[0].to_lower() in commands:
		print("command '" + command_chunks[0].to_lower() + "' is a normal command")
		if not len(command_chunks) > command_minimum_args[commands.find(command_chunks[0].to_lower())]:
			print_to_output("[i]ERROR: Tried to run '[u]" + command_chunks[0] + "[/u]' with too little arguments. You gave " + str(len(command_chunks)) + " arguments and " + str(command_minimum_args[commands.find(command_chunks[0].to_lower())]) + " were needed, please try again.[/i]")
			return ERR_INVALID_PARAMETER
		match command_chunks[0].to_lower():
			"echo":
				match command_chunks[1].to_lower():
					"call":
						if not len(command_chunks) > 2:
							print_to_output("[i]ERROR: Tried to run 'call' inside 'echo' with too little arguments, please try again.[/i]")
							return ERR_INVALID_PARAMETER
						print("trying to echo the call of '" + command_chunks[2] + "' with the args: " + str([command.right((11 + len(command_chunks[2])) * -1)]))
						print_to_output(str(_run(command_chunks[2], (func(arr : PackedStringArray) -> PackedStringArray: arr.remove_at(0); arr.remove_at(0); arr.remove_at(0); return arr).call(command_chunks))))
					_:
						print_to_output(command.right(-5))
			"call":
				_run(command_chunks[1], (func(arr : PackedStringArray) -> PackedStringArray: arr.remove_at(0); arr.remove_at(0); return arr).call(command_chunks))
			"set":
				if command_chunks[1] in set_and_get_types and len(command_chunks) > 3:
					_run(&"set_" + command_chunks[1], [command_chunks[2], set_arg_type_callable.call(command.right((3 + len(command_chunks[0]) + len(command_chunks[1]) + len(command_chunks[2])) * -1))])
				elif GeneralManager.get_id_type(command_chunks[1]) != MasterDirectoryManager.use_type.UNKNOWN:
					var data : Variant = MasterDirectoryManager.get(MasterDirectoryManager.get_data_types.call()[int(command_chunks[1][1])] + &"_id_dict")[command_chunks[1]]
					if typeof(data[command_chunks[2]]) != typeof(set_arg_type_callable.call(command_chunks[3])):
						print_to_output("[i]ERROR: Invalid type for 'set', tried to set '[u]" + command_chunks[2] + "[/u]' of type '[u]" + type_string(typeof(data[command_chunks[2]])) + "[/u]' to '[u]" + str(set_arg_type_callable.call(command_chunks[3])) + "[/u]', which is of type '[u]" + type_string(typeof(set_arg_type_callable.call(command_chunks[3]))) + "[/u]', please check the command and try again.[/i]")
						return ERR_INVALID_PARAMETER
					data[command_chunks[2]] = set_arg_type_callable.call(command_chunks[3])
					print_to_output("[i]Set data of name '[u]" + command_chunks[2] + "[/u]' on object with the ID of '[u]" + command_chunks[1] + "[/u]' to a value of '[u]" + command_chunks[3] + "[/u]'.")
				else:
					print_to_output("[i]ERROR: First argument given for 'set' is invalid, please try again with an ID or setting type.[/i]")
					return ERR_INVALID_PARAMETER
			"get":
				if not command_chunks[1] in set_and_get_types:
					print_to_output("[i]ERROR: First argument given for 'get' is invalid, please try again with a setting type.[/i]")
					return ERR_INVALID_PARAMETER
				var data : Dictionary
				match command_chunks[1]:
					"user_settings":
						data = MasterDirectoryManager.get_user_settings()
					"player_settings":
						data = get_node(^"/root/MainScreen").playing_screen.call("get_player_settings")
				if len(command_chunks) > 2 and command_chunks[2] in ["keys", "values"]:
					print_to_output("[i][b]" + command_chunks[1].capitalize() + " " + command_chunks[2].capitalize() + ":[/b]\n " + str({"keys": data.keys(), "values": data.values()}[command_chunks[2]]) + "[/i]")
				else:
					print_to_output("[i][b]" + command_chunks[1].capitalize() + ":[/b]\n " + str(data) + "[/i]")
	else:
		print_to_output("[i][u]ERROR: Command '" + command + "' is not understandable; please check your command and try again.[/u][/i]")
		return ERR_INVALID_PARAMETER
	return OK

func print_to_output(text : String) -> int:
	%OutputContainer.add_child(output_scene.instantiate())
	%OutputContainer.get_child(-1).text = text
	return OK

func _run(command : String, args : Array) -> Variant:
	print("running _run with a command of '" + command + "' with args of " + str(args))
	if not command in callables_commands:
		print_to_output("[i]ERROR: Command '[u]" + command + "[/u]' Is not a valid command, please check it and try again.[/i]")
		print("command not in callables values, callables values are: " + str(callables_commands))
		return ERR_INVALID_PARAMETER
	args.map(func(item : String) -> Variant: return set_arg_type_callable.call(item))
	print_to_output("[i]Attempting to run the command '[u]" + command + "[/u]' with the arguments of: '[u]" + str(args) + "[/u]'[/i]")
	print("trying to call '" + command + "' with the new args of " + str(args) + " on node: " + _find_callable_key(command).to_snake_case())
	if len(args.filter(func(item : Variant) -> bool: return str(item) != "")) > 0:
		return self.get(_find_callable_key(command).to_snake_case()).callv(command, args)
	return self.get(_find_callable_key(command).to_snake_case()).call(command)

func _find_callable_key(command : String) -> String:
	if command in callables_commands:
		for list : Array in callables.values():
			if list.has(command):
				return callables.find_key(list)
	return ""
