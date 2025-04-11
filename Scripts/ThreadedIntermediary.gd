extends ProgressBar

var anim : bool = false:
	set(val):
		anim = val
		if val:
			_start_anim()

func _start_anim() -> void:
	value = 0
	while anim:
		value += 5
		if value == max_value:
			value = 0
		await get_tree().process_frame
	return
