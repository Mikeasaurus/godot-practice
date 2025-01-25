extends Control

signal back

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Connect volume slider to global volume control signal.
	$MarginContainer/CenterContainer/VBoxContainer/GridContainer/VolumeHSlider.value = Globals.volume
	$MarginContainer/CenterContainer/VBoxContainer/GridContainer/VolumeHSlider.value_changed.connect(Globals.set_volume)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _on_back_button_pressed() -> void:
	back.emit()
