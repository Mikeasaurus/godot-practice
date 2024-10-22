extends Label

# https://www.reddit.com/r/godot/comments/x6l82x/how_to_change_color_of_label_text_via_code/
func set_value (x):
	set("theme_override_colors/font_color",Color(x,x,x,1.0))

func disable ():
	set("theme_override_colors/font_color",Color(0.0,0.0,0.0,0.0))

func get_value ():
	return get("theme_override_colors/font_color").r

func dec_value (dx):
	var x = get_value()
	x -= dx
	set_value(x)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
