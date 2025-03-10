extends PanelContainer

const styleboxes : Array[StyleBoxFlat] = [preload("res://Assets/Styleboxes/CLI_Stylebox_Default.tres"), preload("res://Assets/Styleboxes/CLI_Stylebox_Solid.tres")]
const output_scene : PackedScene = preload("res://Scenes/CliOutputLabel.tscn")
@onready var main_screen : Control = get_node("/root/MainScreen")
@onready var playing_screen : Control = get_node("/root/MainScreen/Camera/AspectRatioContainer/PlayerContainer/PlayingScreen")
@onready var command_line_interface : PanelContainer = self
@onready var master_directory_manager : Node = MasterDirectoryManager
@onready var general_manager : Node = GeneralManager
@export var active : bool = false:
	set(value):
		active = value
		self.visible = value
		if value == false:
			%InputField.release_focus()
		else:
			%InputField.grab_focus()
	get:
		return active
@export var auto_clear : bool = false:
	set(value):
		auto_clear = value
		if value == true:
			%OutputContainer.get_children().map(func(node : Node) -> Node: node.queue_free(); return node)
	get:
		return auto_clear
@export var clear_input : bool = false:
	set(value):
		clear_input = value
		if value == true:
			%InputField.text = ""
	get:
		return clear_input
@export var print_debug_info : bool = true
@export var style : int = 0:
	set(value):
		style = value
		self.set("theme_override_styles/panel", styleboxes[style])
	get:
		return style
var check_call_arg_type : Callable = (func(arg : String) -> String: var msg : String = arg.right(arg.find("/") * -1); return arg.replace(msg, ""))
var set_arg_type_callable : Callable = (
	func(arg : String) -> Variant: 
		match check_call_arg_type.call(arg):
			"int":
				return int(arg.right(-4))
			"float":
				return float(arg.right(-6))
			"bool":
				return bool(arg.right(-5).to_lower() in GeneralManager.boolean_strings)
			"vec2":
				return Vector2(int(arg.right(-5).split(",", false)[0]), int(arg.right(-5).split(",", false)[1]))
			"arr":
				return Array(arg.right(-4).split(",", false)).map(set_arg_type_callable)
			_:
				return arg
		)
var command_history : PackedStringArray = (func() -> PackedStringArray: var arr : PackedStringArray = []; return arr).call()
var command_history_placement : int = 0
const commands : PackedStringArray = ["echo", "call", "set", "get", "add", "del"]
const command_minimum_args : PackedInt32Array = [1, 1, 3, 1, 3, 3]
const set_and_get_types : PackedStringArray = ["user_settings", "player_settings", "general_settings", "cli_settings"]
const caches : PackedStringArray = ["image", "image_average", "library", "song"]
const special_commands : PackedStringArray = [
	"help", "clear", "info", "error_codes", 
	"read", "close", "exit", "hard_reload", 
	"get_callables", "get_commands", "cache"
	]
const debug_commands : PackedStringArray = ["print_id_dict", "push"]
const callables : Dictionary[String, Array] = {
	"MasterDirectoryManager": ["_save_data", "set_user_settings", "get_user_settings"], 
	"GeneralManager": ["set_general_settings", "get_general_settings"], 
	"CommandLineInterface": ["print_to_output", "run_command", "get_cli_settings", "set_cli_settings"], 
	"MainScreen": [
		"play", "set_favourite", "toggle_cli", "open_tutorial", 
		"_create_home_screen", "_search_library"], 
	"PlayingScreen": [
		"reset_playing_screen", "set_player_settings", "get_player_settings", 
		]
	}
#https://raw.githubusercontent.com/godotengine/godot-docs/master/img/color_constants.png
const keyword_to_text : Dictionary[String, String] = {
		"DEBUG_ERROR:": "[color=medium_violet_red]DEBUG ERROR |>[/color]", 
		"SYS_ERROR:": "[color=orange_red]SYSTEM ERROR |>[/color]", 
		"ERROR:": "[color=red]ERROR |>[/color]", 
		"DEBUG:": "[color=rebecca_purple]DEBUG |>[/color]", 
		"SYS:": "[color=silver]SYSTEM |>[/color]", 
		"ALERT:": "[color=yellow]ALERT |>[/color]", 
		"NOTIF:": "[color=gold]NOTIFICATION |>[/color]"
		}
const settable_settings : PackedStringArray = ["auto_clear", "clear_input", "print_debug_info"]
var callables_commands : Array[String] = [] # read only after ready

func _ready() -> void:
	callables.values().map(func(item : Array) -> Array: callables_commands.append_array(item); return item)
	callables_commands.make_read_only()
	#
	%InputField.text_submitted.connect(func(text : String) -> void: run_command(text); return)
	#
	if MasterDirectoryManager.finished_loading_data == false:
		await MasterDirectoryManager.finished_loading_data_signal
	await get_tree().process_frame
	auto_clear = MasterDirectoryManager.user_data_dict["auto_clear"]
	clear_input = MasterDirectoryManager.user_data_dict["clear_input"]
	style = int(MasterDirectoryManager.user_data_dict["solid_cli"])
	if MasterDirectoryManager.user_data_dict["command_on_startup"] != "":
		run_command(MasterDirectoryManager.user_data_dict["command_on_startup"], true)
	return

func _input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("CommandHistoryUp", true) or Input.is_action_just_pressed("CommandHistoryDown", true):
		if command_history_placement == 0 and GeneralManager.arr_get(command_history, 0, "") != %InputField.text:
			command_history.insert(0, %InputField.text)
			if len(command_history) > 11:
				command_history.resize(11)
		if Input.is_action_just_pressed("CommandHistoryUp", true):
			command_history_placement = wrapi(command_history_placement + 1, 0, len(command_history))
		else:
			command_history_placement = wrapi(command_history_placement - 1, 0, len(command_history))
		%InputField.text = command_history[command_history_placement]
	return

func run_command(command : String, bypass_active : bool = false) -> int:
	if (not active) and (not bypass_active):
		return ERR_CANT_RESOLVE
	if auto_clear:
		%OutputContainer.get_children().map(func(node : Node) -> Node: node.queue_free(); return node)
	if clear_input:
		%InputField.text = ""
	if not bypass_active and GeneralManager.arr_get(command_history, 0, "") != command:
		command_history.insert(0, command)
		if len(command_history) > 11:
			command_history.resize(11)
	var command_chunks : PackedStringArray = command.split("-", false)
	if command_chunks[0].to_lower() in special_commands:
		match command_chunks[0].to_lower():
			"help":
				print_to_output(
					("[b]NMP CLI Help Page:[/b]
					 Welcome to the Nat Music Programme CLI (Command Line Interface) Help Page! Please look below for information on how it works.
					
					[u]Command Structure:[/u]
					 When writing a command, you must seperate each argument with a hyphon (-), unless it does not have any arguments, in which case only the name is neaded.
					 For example, writing a command to print 'Hello World!' to the output could look like; '[u]echo-Hello World![/u]'
					 For available commands and their possible arguments, please see the 'Commands' section below.
					
					[i]Special Commands.[/i]
					- [color=green]help[/color]
					  - Opens this help page.
					- [color=green]clear[/color] (0+)
					  - Clears the output.
					    If a type-casted number is given as an argument clears that many items from the output up to the amount of items.
					- [color=green]cache[/color] (2)
					  - Either clears or reads (argument 1) the given cache (argument 2), for example '[u]cache-read-song[/u]',
					    the available caches are those inside the Cache section of the Settings page on the Profile screen.
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
					  - Reloades the programme, functions the same as 'HardReloadApp' shortcut.
					    !WARNING! This will not save beforehand, this is equivilent to exiting without saving and re-opening.
					- [color=green]get_callables[/color]
					  - Returns all of the functions that can be called using the 'call' command.
					- [color=green]get_commands[/color]
					  - Returns all of the commands you can call, which may include ones not listed inside this 'help' page.
					
					[u]Commands.[/u]
					- [color=green]echo[/color] (1+)
					  - Prints the first argument. If the first argument is the 'call' command, can be used to print the output / returned values of the command.
					    If the first argument is 'type' it will print the type of the rest of the command, for example '[u]echo-type-vec2/1,5[/u]' prints '[u][b]Vector2[/b]: (1.0, 5.0)[/u]'
					- [color=green]call[/color] (2+)
					  - Calls the given function (argument 1), with all other arguments being given to the called function.
					    The available functions to call can be checked using the 'get_callables' special command.
					- [color=green]set[/color] (3)
					  - Set has two functions: It can either set a property (argument 2) on an item with a certain ID (argument 1) to a new value (argument 3) which can be type-cast,
					    or it can be used to change certain settings using a similar structure, for example enabling your 'save_on_quit' setting could look like; [u]set-user_settings-save_on_quit-bool/true[/u].
					- [color=green]get[/color] (1+)
					  - Sets sister command, Get returns the names of properties for the item with the ID of (argument 1) or a certain group of settings (argument 1) alongside their current values,
					    and additional argument (argument 2) can be provided to get just the keys / names / types of the values (by passing 'keys', 'values' and 'types' respectively).
					- [color=green]add[/color] (3)
					  - Adds the given item (argument 3) on to the property (argument 2) from the item with the ID of (argument 1), the property must be a container (An Array) for you to add items.
					- [color=green]del[/color] (3)
					  - Adds sister command, removes the item at the given index (argument 3) from the property (argument 2) on the item with the ID of (argument 1),
					    the property must be a container (An Array) for you to delete items. Items are zero-index (An Array of [Apple, Orange, Banana] would be indexed [0: Apple, 1: Orange, 2: Banana]).
					
					[u]Argument Types / Type-Casting.[/u]
					 When giving argument(s) to a function / command, by default they will all be a String, which is just the characters you put in. But some functions will want other types,
					 for example trying to enabled the 'shuffle' setting on the Player using 'set_player_setting' will want a Boolean value, you can see the types and how to cast them below.
					
					 - [color=green]{argument}[/color]
					   - The default, returns a String as whatever the argument was, Strings are used in cases such as wanting an ID.
					 - [color=web_green]bool[/color]/[color=green]{argument}[/color]
					   - This will return a Boolean (true or false) depending on the argument, it will return True if the argument is either '1', 'true', 'enabled', 'on' or 'yes', and will return false otherwise.
					     (case insensetive)
					 - [color=web_green]int[/color]/[color=green]{argument}[/color]
					   - This will return an Integer (Whole number) depending on the argument, for example a value of 'int/15' would return the number 15.
					 - [color=web_green]float[/color]/[color=green]{argument}[/color]
					   - This will return a Floating-Point Number (Decimalized number) depending on the argument, for example a value of 'float/1.5' would return the number 1.5. 
					 - [color=web_green]arr[/color]/[color=green]{argument}[/color]
					   - This will return an Array (List) of the contents of the argument as seperated by commas (,), the contents can also be type-cast.
					     For example 'arr/int/5,hello,bool/1' would return an array containing [5, \"hello\", True].
					 - [color=web_green]vec2[/color]/[color=green]{argument}[/color]
					   - This will return a Vector 2 (Two Floating-Point Numbers) of the contents of the argument as seperated by commas (,)
					     The contents can't and should not be type-cast as they will always be turned into Floats.
					     For example 'vec2/2,91' would return 'Vector2(2.0, 91.0)', but 'vec2/hello,5' would return 'Vector2(0.0, 5.0)' as any non-numerical String when turned into a number is 0.
					     Vectors are used rarely for settings such as positions and sizes for the app's Window.").replace("\t", "").replace("(argument 1)", "[color=lawn_green][u]argument 1[/u][/color]").replace("(argument 2)", "[color=lime_green][u]argument 2[/u][/color]").replace("(argument 3)", "[color=forest_green][u]argument 3[/u][/color]"))
			"clear":
				if len(command_chunks) > 1 and typeof(set_arg_type_callable.call(command_chunks[1])) == TYPE_INT:
					for i : int in range(0, mini(set_arg_type_callable.call(command_chunks[1]), len(%OutputContainer.get_children()))):
						%OutputContainer.get_child(len(%OutputContainer.get_children()) - 1 - i ).queue_free()
				else:
					%OutputContainer.get_children().map(func(node : Node) -> Node: node.queue_free(); return node)
			"cache":
				if len(command_chunks) > 2 and command_chunks[1] in ["clear", "read"] and command_chunks[2] in caches:
					match command_chunks[1]:
						"clear":
							print_to_output("ALERT: About to clear the '[u]" + command_chunks[2].capitalize() + "[/u]' cache.")
							match command_chunks[2]:
								"image":
									GeneralManager.image_cache.assign({})
								"image_average":
									GeneralManager.image_average_cache.assign({})
								"library":
									get_node("/root/MainScreen/Camera/AspectRatioContainer/GreaterContainer/MainContainer/Library/Container/ScrollContainer/ItemList").get_children().map(func(node : Node) -> Node: node.queue_free(); return node)
								"song":
									get_node("/root/MainScreen").playing_screen.song_cache.assign({})
							print_to_output("NOTIF: Succesfully cleared the '[u]" + command_chunks[2].capitalize() + "[/u]' cache.")
						"read":
							var to_print : String = "[b]" + command_chunks[2].capitalize() + " Cache:[/b]\n"
							var temp : int = 0
							var temp_arr : Array[Variant]
							match command_chunks[2]:
								"image":
									to_print += "- Length: " + str(len(GeneralManager.image_cache.values())) + "/" + str(MasterDirectoryManager.user_data_dict["image_cache_size"])
									for img : Image in GeneralManager.image_cache.values():
										temp += img.get_data_size()
									to_print += "\n- Memory Size Estimate (Bytes): " + GeneralManager.int_to_readable_int(temp) + "\n- Contents [File Only]:\n    "
									temp_arr = GeneralManager.image_cache.keys()
									for key : String in temp_arr:
										to_print += key.get_file() + ", "
										if temp_arr.find(key) != 0 and temp_arr.find(key) % 5 == 0:
											to_print = to_print.left(-2) + "\n    "
									to_print = to_print.left(-2)
								"image_average":
									to_print += "- Length: " + str(len(GeneralManager.image_average_cache.values())) + "/" + str(MasterDirectoryManager.user_data_dict["image_cache_size"]) + "\n- Memory Size Estimate (Bytes): " + GeneralManager.int_to_readable_int(len(GeneralManager.image_average_cache.values()) * 16) + "\nContents [Image Name: Colour]:\n    "
									temp_arr = GeneralManager.image_average_cache.keys()
									for key : String in temp_arr:
										to_print += key + ": [color=#" + GeneralManager.int_to_hex(GeneralManager.image_average_cache[key].to_rgba32()) + "]█[/color], "
										if temp_arr.find(key) != 0 and temp_arr.find(key) % 5 == 0:
											to_print = to_print.left(-2) + "\n    "
									to_print = to_print.left(-2)
								"library":
									to_print += "- Length: " + str(len(get_node("/root/MainScreen/Camera/AspectRatioContainer/GreaterContainer/MainContainer/Library/Container/ScrollContainer/ItemList").get_children()))
								"song":
									temp_arr = get_node("/root/MainScreen").playing_screen.song_cache.keys()
									to_print += "- Length: " + str(len(temp_arr)) + "/" + str(MasterDirectoryManager.user_data_dict["song_cache_size"]) + "\n- Contents [File Only]:\n    "
									for key : String in temp_arr:
										to_print += key.get_file() + ", "
										if temp_arr.find(key) != 0 and temp_arr.find(key) % 5 == 0:
											to_print = to_print.left(-2) + "\n    "
									to_print = to_print.left(-2)
							print_to_output(to_print)
				elif len(command_chunks) < 3:
					print_to_output("ERROR: Invalid amount of arguments for 'cache' special-command, an action followed by a cache type in needed.")
				elif not command_chunks[1] in ["clear", "read"]:
					print_to_output("ERROR: You gave the argument '[u]" + command_chunks[1] + "[/u]', but either '[u]clear[/u]' or '[u]read[/u]' is needed.")
				elif not command_chunks[2] in caches:
					print_to_output("ERROR: Invalid cache type to " + command_chunks[1] + ", wanted one of the following:\n" + str(caches))
				else:
					print_to_output("ERROR: Generic / Unhandled error during 'cache' special-command, please report this with the command you used that caused this erorr.")
			"info":
				print_to_output(
					("[b]NMP Info:[/b]
					-Version: " + GeneralManager.version + "
					-[color=orange]-[/color] Build: " + GeneralManager.build + "
					-[color=orange]-[/color] Build Date: " + GeneralManager.export_data[0] + "
					-[color=orange]-[/color] License: " + GeneralManager.export_data[2] + "
					-[color=orange]-[/color] Architecture: " + GeneralManager.export_data[3] + "
					-[color=orange]-[/color] App Repository: [url=" + GeneralManager.repo_url + "][i]Github[/i][/url]
					-[color=orange]-[/color] Engine: This software is powered by and created using the [url=https://godotengine.org][i]Godot Engine[/i][/url] [i]" + GeneralManager.export_data[1] + "[/i].
					-Location: " + OS.get_executable_path() + "
					-[color=orange]-[/color] Data Location: " + MasterDirectoryManager.data_location + "
					-RNG Seed: " + str(GeneralManager.rng_seed) + "
					-Icons: All Icons except that of the NMP logo are sourced from [url=https://fonts.google.com/icons][i]Google Icons[/i][/url].").replace("\t", "").replace(": ", "[/color] ").replace("\n-", "\n[color=lime_green]-[/color] [color=light_steel_blue]"))
			"error_codes":
				if len(command_chunks) < 2:
					print_to_output("ERROR: No error code given to see information about.")
					return ERR_INVALID_PARAMETER
				if not typeof(command_chunks[1]) in [TYPE_STRING, TYPE_INT] or error_string(int(command_chunks[1])) == "(invalid error code)":
					print_to_output("ERROR: Not a valid error code.")
					return ERR_INVALID_PARAMETER
				print_to_output("-Error Code " + str(int(command_chunks[1])) + ": " + error_string(int(command_chunks[1])))
			"read":
				if len(command_chunks) < 2:
					print_to_output("ERROR: No ID given to read, please provide an ID.")
					return ERR_INVALID_PARAMETER
				if GeneralManager.get_id_type(command_chunks[1]) == MasterDirectoryManager.use_type.UNKNOWN:
					print_to_output("ERROR: Unable to read data for the ID of: " + command_chunks[1] + ", as it is not a valid ID.")
					return ERR_INVALID_PARAMETER
				if not command_chunks[1] in MasterDirectoryManager.get(MasterDirectoryManager.data_types[int(command_chunks[1][0])] + "_id_dict").keys():
					print_to_output("ERROR: Unable to read data for the ID of: " + command_chunks[1] + ", as it is not an existing ID, please check it and try again.")
					return ERR_INVALID_PARAMETER
				var data : Dictionary = MasterDirectoryManager.get_object_data.call(command_chunks[1])
				var to_print : String = "[b]ID [u]" + command_chunks[1] + "[/u] Data:[/b] (Displayed data names are capitalized, real name are lowercase and use _ instead of spaces.)"
				for item : String in (func() -> PackedStringArray: var keys : Array = data.keys(); return GeneralManager.sort_alphabetically(keys)).call():
					var to_add : String = str(data[item])
					if typeof(data[item]) in [TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY]:
						to_add = ""
						for item2 : Variant in data[item]:
							to_add += "\n-- " + str(data[item].find(item2) + 1) + ": " + str(item2)
					to_print += "\n- " + item.capitalize() + ": " + to_add
				print_to_output(to_print)
			"close":
				active = false
			"exit":
				if MasterDirectoryManager.user_data_dict["save_on_quit"]:
					MasterDirectoryManager.save_data()
					if MasterDirectoryManager.finished_saving_data == false:
						await MasterDirectoryManager.finished_saving_data_signal
					await get_tree().process_frame
				get_tree().quit(0)
			"hard_reload":
				OS.set_restart_on_exit(true)
				get_tree().quit(0)
			"get_callables":
				var to_print : String = "[b]Callables:[/b]"
				for callable : String in callables_commands:
					to_print += "\n[color=lime_green]-[/color] " + str(callables_commands.find(callable) + 1) + " [color=orange]-[/color] " + callable
				print_to_output(to_print)
			"get_commands":
				var to_print : String = "[b]Commands:[/b]\n[color=lime_green]-[/color] [color=light_steel_blue]Special Commands:[/color]"
				for cmd : String in special_commands:
					to_print += "\n[color=lime_green]-[/color] [color=orange]-[/color] " + str(special_commands.find(cmd) + 1) + " [color=yellow]-[/color] " + cmd
				to_print += "\n[color=lime_green]-[/color] [color=light_steel_blue]Commands:[/color]"
				for cmd : String in commands:
					to_print += "\n[color=lime_green]-[/color] [color=orange]-[/color] " + str(commands.find(cmd) + 1) + " [color=yellow]-[/color] " + cmd
				if GeneralManager.is_in_debug:
					to_print += "\n[color=lime_green]-[/color] [color=light_steel_blue]Debug Commands:[/color]"
					for cmd : String in debug_commands:
						to_print += "\n[color=lime_green]-[/color] [color=orange]-[/color] " + str(debug_commands.find(cmd) + 1) + " [color=yellow]-[/color] " + cmd
				print_to_output(to_print)
	elif ((command_chunks[0].to_lower() == "debug") and (len(command_chunks) > 1) and (command_chunks[1] in debug_commands) and (GeneralManager.is_in_debug)):
		match command_chunks[1]:
			"print_id_dict":
				if len(command_chunks) < 3:
					print_to_output("DEBUG_ERROR: No argument given, please give an argument.")
					return ERR_INVALID_PARAMETER
				if not (command_chunks[2] in MasterDirectoryManager.data_types or command_chunks[2] == "user"):
					print_to_output("DEBUG_ERROR: Not a valid argument, please give a valid argument.")
					return ERR_INVALID_PARAMETER
				if len(command_chunks) < 4:
					print_to_output("[b]" + command_chunks[2].capitalize() + " ID Dict:[/b]\n" + str(MasterDirectoryManager.get(command_chunks[2] + ["_id_dict", "_data_dict"][int(command_chunks[2] == "user")])))
				else:
					match command_chunks[3]:
						"keys":
							print_to_output("[b]" + command_chunks[2].capitalize() + " ID Dict Keys:[/b]\n" + str(MasterDirectoryManager.get(command_chunks[2] + ["_id_dict", "_data_dict"][int(command_chunks[2] == "user")]).keys()))
						"values":
							print_to_output("[b]" + command_chunks[2].capitalize() + " ID Dict Values:[/b]\n" + str(MasterDirectoryManager.get(command_chunks[2] + ["_id_dict", "_data_dict"][int(command_chunks[2] == "user")]).values()))
						"types":
							print_to_output("[b]" + command_chunks[2].capitalize() + " ID Dict Types:[/b]\n" + str(MasterDirectoryManager.get(command_chunks[2] + ["_id_dict", "_data_dict"][int(command_chunks[2] == "user")]).values().map(func(item : Variant) -> String: return type_string(typeof(item)))))
						_:
							print_to_output("DEBUG_ERROR: Not a valid argument, please give a valid argument.")
							return ERR_INVALID_PARAMETER
			"push":
				if len(command_chunks) < 4:
					print_to_output("DEBUG_ERROR: Invalid amount of arguments for 'push', needs 3 arguments.")
					return ERR_INVALID_DATA
				if not (command_chunks[2].to_upper() + ":") in keyword_to_text.keys():
					print_to_output("DEBUG_ERROR: Invalid push type, please use one of the following: " + str(keyword_to_text.keys()).replace(":", "").to_lower() + ".")
					return ERR_INVALID_PARAMETER
				print_to_output(command_chunks[2].to_upper() + ": " + command.right((12 + len(command_chunks[2])) * -1))
	elif command_chunks[0].to_lower() in commands:
		if not len(command_chunks) > command_minimum_args[commands.find(command_chunks[0].to_lower())]:
			print_to_output("ERROR: Tried to run '[u]" + command_chunks[0] + "[/u]' with too little arguments. You gave " + str(len(command_chunks)-1) + " arguments and " + str(command_minimum_args[commands.find(command_chunks[0].to_lower())]) + " were needed, please try again.")
			return ERR_INVALID_PARAMETER
		match command_chunks[0].to_lower():
			"echo":
				match command_chunks[1].to_lower():
					"call":
						if not len(command_chunks) > 2:
							print_to_output("ERROR: Tried to run 'call' inside 'echo' with too little arguments, please try again.")
							return ERR_INVALID_PARAMETER
						print_to_output(str(_run(command_chunks[2], (func(arr : PackedStringArray) -> PackedStringArray: arr.remove_at(0); arr.remove_at(0); arr.remove_at(0); return arr).call(command_chunks))))
					"type":
						print_to_output("[b]" + type_string(typeof(set_arg_type_callable.call(command.right(-10)))).capitalize().replace(" ", "") + "[/b]: " + str(set_arg_type_callable.call(command.right(-10))), false)
					_:
						print_to_output(command.right(-5), false)
			"call":
				_run(command_chunks[1], (func(arr : PackedStringArray) -> PackedStringArray: arr.remove_at(0); arr.remove_at(0); return arr).call(command_chunks))
			"set":
				if command_chunks[1] in set_and_get_types and len(command_chunks) > 3:
					_run("set_" + command_chunks[1], [command_chunks[2], set_arg_type_callable.call(command.right((3 + len(command_chunks[0]) + len(command_chunks[1]) + len(command_chunks[2])) * -1))])
				elif GeneralManager.get_id_type(command_chunks[1]) != MasterDirectoryManager.use_type.UNKNOWN:
					var data : Variant = MasterDirectoryManager.get(MasterDirectoryManager.data_types[int(command_chunks[1][1])] + "_id_dict")[command_chunks[1]]
					if typeof(data[command_chunks[2]]) != typeof(set_arg_type_callable.call(command_chunks[3])):
						print_to_output("ERROR: Invalid type for 'set', tried to set '[u]" + command_chunks[2] + "[/u]' of type '[u]" + type_string(typeof(data[command_chunks[2]])) + "[/u]' to '[u]" + str(set_arg_type_callable.call(command_chunks[3])) + "[/u]', which is of type '[u]" + type_string(typeof(set_arg_type_callable.call(command_chunks[3]))) + "[/u]', please check the command and try again.")
						return ERR_INVALID_PARAMETER
					data[command_chunks[2]] = set_arg_type_callable.call(command_chunks[3])
					print_to_output("Set data of name '[u]" + command_chunks[2] + "[/u]' on object with the ID of '[u]" + command_chunks[1] + "[/u]' to a value of '[u]" + command_chunks[3] + "[/u]'.")
				else:
					print_to_output("ERROR: First argument given for 'set' is invalid, please try again with an ID or setting type. Did you mean '[u]" + GeneralManager.spellcheck(command_chunks[1], set_and_get_types) + "[/u]'?.")
					return ERR_INVALID_PARAMETER
			"get":
				if not command_chunks[1] in set_and_get_types:
					print_to_output("ERROR: First argument given for 'get' is invalid, please try again with a setting type. Did you mean '[u]" + GeneralManager.spellcheck(command_chunks[1], set_and_get_types) + "[/u]'?.")
					return ERR_INVALID_PARAMETER
				var data : Dictionary
				match command_chunks[1]:
					"user_settings":
						data = MasterDirectoryManager.get_user_settings()
					"player_settings":
						data = get_node("/root/MainScreen").playing_screen.call("get_player_settings")
					"general_settings":
						data = GeneralManager.get_general_settings()
					"cli_settings":
						data = get_cli_settings()
						command_chunks[1] = "command_line_interface_settings"
				if len(command_chunks) > 2 and command_chunks[2] in ["keys", "values", "types"]:
					print_to_output("[b]" + command_chunks[1].capitalize() + " " + command_chunks[2].capitalize() + ":[/b]\n " + str({"keys": data.keys(), "values": data.values(), "types": data.values().map(func(item : Variant) -> String: return type_string(typeof(item)))}[command_chunks[2]]))
				else:
					print_to_output("[b]" + command_chunks[1].capitalize() + ":[/b]\n " + str(data))
			"add":
				if not (GeneralManager.get_id_type(command_chunks[1]) != MasterDirectoryManager.use_type.UNKNOWN and MasterDirectoryManager.get(MasterDirectoryManager.data_types[int(command_chunks[1][1])] + "_id_dict").has(command_chunks[1])):
					print_to_output("ERROR: ID [u]" + command_chunks[1] + "[/u] during 'add' is not valid or is nonexistant, please check it and try again.")
					return ERR_INVALID_PARAMETER
				var data : Dictionary =  MasterDirectoryManager.get(MasterDirectoryManager.data_types[int(command_chunks[1][1])] + "_id_dict")[command_chunks[1]]
				if not data.has(command_chunks[2]):
					print_to_output("ERROR: Tried to add to [u]" + command_chunks[2] + "[/u] in object with ID [u]" + command_chunks[1] + "[/u] which does not have a matching field, please check it and try again.")
					return ERR_INVALID_PARAMETER
				if not typeof(data[command_chunks[2]]) in [TYPE_ARRAY]:
					print_to_output("ERROR: Trying to add an item to [u]" + command_chunks[2] + "[/u], which is not a type with contents that can be added too using this command.")
					return ERR_INVALID_PARAMETER
				data[command_chunks[2]].append(set_arg_type_callable.call(command_chunks[3]))
				print_to_output("Added [u]" + str(set_arg_type_callable.call(command_chunks[3])) + "[/u] to [u]" + command_chunks[2] + "[/u] in object with ID [u]" + command_chunks[1] + "[/u].")
			"del":
				if not (GeneralManager.get_id_type(command_chunks[1]) != MasterDirectoryManager.use_type.UNKNOWN and MasterDirectoryManager.get(MasterDirectoryManager.data_types[int(command_chunks[1][1])] + "_id_dict").has(command_chunks[1])):
					print_to_output("ERROR: ID [u]" + command_chunks[1] + "[/u] during 'del' is not valid or is nonexistant, please check it and try again.")
					return ERR_INVALID_PARAMETER
				var data : Dictionary =  MasterDirectoryManager.get(MasterDirectoryManager.data_types[int(command_chunks[1][1])] + "_id_dict")[command_chunks[1]]
				if not data.has(command_chunks[2]):
					print_to_output("ERROR: Tried to delete in [u]" + command_chunks[2] + "[/u] in object with ID [u]" + command_chunks[1] + "[/u] which does not have a matching field, please check it and try again.")
					return ERR_INVALID_PARAMETER
				if not typeof(data[command_chunks[2]]) in [TYPE_ARRAY]:
					print_to_output("ERROR: Trying to delete an item to [u]" + command_chunks[2] + "[/u], which is not a type with contents that can be deleted from using this command.")
					return ERR_INVALID_PARAMETER
				if not typeof(set_arg_type_callable.call(command_chunks[3])) == TYPE_INT:
					print_to_output("ERROR: Need an index to delete with, provided index was not a number. Please provide a number by type-casting the argument with 'int/'.")
					return ERR_INVALID_PARAMETER
				if not set_arg_type_callable.call(command_chunks[3]) in range(0, len(data[command_chunks[2]])):
					print_to_output("ERROR: Index during 'del' was not a valid index as it is outside the range of the data size.")
					return ERR_INVALID_PARAMETER
				print_to_output("Removed item [u]" + data[command_chunks[2]][set_arg_type_callable.call(command_chunks[3])] + "[/u] at index [u]" + str(set_arg_type_callable.call(command_chunks[3])) + "[/u] from [u]" + str(data[command_chunks[2]]) + "[/u] on object with ID [u]" + command_chunks[1] + "[/u].")
				data[command_chunks[2]].remove_at(set_arg_type_callable.call(command_chunks[3]))
	else:
		print_to_output("ERROR: Command '" + command + "' is not understandable; please check it and try again. Did you mean '[u]" + GeneralManager.spellcheck(command_chunks[0], (func() -> PackedStringArray: var to_ret : PackedStringArray = []; to_ret.append_array(commands); to_ret.append_array(special_commands); return to_ret).call()) + "[/u]'?.")
		return ERR_INVALID_PARAMETER
	return OK

func print_to_output(text : String, use_keywords : bool = true) -> int:
	if use_keywords:
		for key : String in keyword_to_text.keys():
			if key in text:
				text = text.replace(key, keyword_to_text[key])
				break
	%OutputContainer.add_child(output_scene.instantiate())
	%OutputContainer.get_child(-1).text = ["", "\n"][int(MasterDirectoryManager.user_data_dict["separate_cli_outputs"])] + text
	create_tween().tween_callback(func() -> void: await get_tree().process_frame; $Container/ScrollContainer/_v_scroll.set_deferred("value", $Container/ScrollContainer/_v_scroll.max_value))
	return OK

func _run(command : String, args : Array[Variant]) -> Variant:
	if not command in callables_commands:
		print_to_output("ERROR: Callable '[u]" + command + "[/u]' Is not valid, please check it and try again. Did you mean '[u]" + GeneralManager.spellcheck(command, callables_commands) + "[/u]'?.")
		return ERR_INVALID_PARAMETER
	for i : int in range(0, len(args)):
		if typeof(args[i]) == TYPE_STRING:
			args[i] = set_arg_type_callable.call(args[i])
	if GeneralManager.is_in_debug and print_debug_info:
		print_to_output("DEBUG: Attempting to run the command '[u]" + command + "[/u]' with the argument" + ["", "s"][int(len(args) > 1)] + ": '[u]" + str(args) + "[/u]'")
	if len(args.filter(func(item : Variant) -> bool: return str(item) != "")) > 0:
		return self.get(_find_callable_key(command).to_snake_case()).callv(command, args)
	return self.get(_find_callable_key(command).to_snake_case()).call(command)

func _find_callable_key(command : String) -> String:
	if command in callables_commands:
		for list : PackedStringArray in callables.values():
			if list.has(command):
				return callables.find_key(Array(list))
	return ""

func get_cli_settings() -> Dictionary:
	var data : Dictionary
	for setting : String in settable_settings:
		data[setting] = self.get(setting)
	if not GeneralManager.is_in_debug:
		data.erase("print_debug_info")
	return data

func set_cli_settings(setting : String, value : Variant) -> int:
	if setting in settable_settings and typeof(value) == typeof(self.get(setting)):
		print_to_output("NOTIF: Command Line Interface Settings: Set [u]" + setting + "[/u] from [u]" + str(self.get(setting)) + "[/u] > [u]" + str(value) + "[/u].")
		self.set(setting, value)
		return OK
	if not setting in settable_settings:
		GeneralManager.cli_print_callable.call("ERROR: Setting [u]" + setting + "[/u] does not exist in Command Line Interface Settings or is unable to be set. Did you mean '[u]" + GeneralManager.spellcheck(setting, settable_settings) + "[/u]'?.")
	else:
		GeneralManager.cli_print_callable.call("ERROR: Tried to set [u]" + setting + "[/u] whos value is of type [u]" + type_string(typeof(self.get(setting))) + "[/u] to [u]" + str(value) + "[/u] which is of type [u]" + type_string(typeof(value)) + "[/u].")
	return ERR_INVALID_PARAMETER
