extends VBoxContainer

const bar_item : PackedScene = preload("res://Scenes/GridItem.tscn")
@export var list_ids : PackedStringArray
@export var title : String = "Title"
var update_data : Dictionary
var id_data : Dictionary
var id_type : MasterDirectoryManager.use_type = MasterDirectoryManager.use_type.UNKNOWN

func update(ids : PackedStringArray = list_ids, new_title : String = title) -> void:
	list_ids = ids
	title = new_title
	%Title.text = title
	%List.get_children().map(func(node : Node) -> Node: node.queue_free(); return node)
	await get_tree().process_frame
	for id : String in list_ids:
		%List.add_child(bar_item.instantiate())
		update_data = {"image": Image.new(), "title": "", "subtitle": ""}
		id_type = GeneralManager.get_id_type(id)
		id_data = MasterDirectoryManager.get(str(MasterDirectoryManager.use_type.keys()[id_type]).to_lower() + "_id_dict")[id]
		if id_type in [MasterDirectoryManager.use_type.ARTIST, MasterDirectoryManager.use_type.ALBUM, MasterDirectoryManager.use_type.PLAYLIST]:
			update_data["image"] = GeneralManager.get_image(id_data.get("image_file_path", ""))
		else:
			update_data["image"] = GeneralManager.get_image(MasterDirectoryManager.album_id_dict.get(id_data.get("album", ""), "")["image_file_path"])
		update_data["title"] = id_data["name"]
		update_data["subtitle"] = id
		%List.get_child(-1).update(update_data)
	return
