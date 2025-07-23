extends Control

var selection: CarSelectionPanel = null

# Signal that gets sent when the player is ready to start the race.
signal race (car: Car)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for panel in $MarginContainer/CenterContainer/VBoxContainer/GridContainer.get_children() as Array[CarSelectionPanel]:
		panel.selected.connect(func(): _panel_selected(panel))

func _panel_selected (panel: CarSelectionPanel) -> void:
	if selection != null and selection != panel:
		selection.unselect()
	selection = panel
	if $MarginContainer/CenterContainer/VBoxContainer/HBoxContainer/RaceButton.disabled:
		$MarginContainer/CenterContainer/VBoxContainer/HBoxContainer/RaceButton.disabled = false

var _tweening: bool = false

func _on_back_button_pressed() -> void:
	if _tweening: return
	MenuHandler.deactivate_menu()

func _on_race_button_pressed() -> void:
	if _tweening: return
	var tween: Tween = create_tween()
	tween.tween_property(self,"modulate",Color.BLACK,1.0)
	_tweening = true
	await tween.finished
	_tweening = false
	modulate = Color.WHITE
	hide()
	race.emit(selection.car)
	MenuHandler.deactivate_menu()
