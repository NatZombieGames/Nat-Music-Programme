extends PanelContainer

@export var image : Image
@export var title : String = "Title"
@export var subtitle : String = "Subtitle"

func _ready() -> void:
	%Button1.update(
		{"texture_icon_name": "Play", "pressed_signal_sender": get_node("/root/MainScreen"), 
		"pressed_signal_name": "play", "argument": subtitle})
	return

func update(data : Dictionary = {"image": image, "title": title, "subtitle": subtitle}) -> void:
	for key : String in data.keys():
		self.set(key, data[key])
	%Image.texture = ImageTexture.create_from_image(image)
	%Title.text = title
	%Subtitle.text = subtitle
	%Button1.update({"argument": subtitle})
	return
