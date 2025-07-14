extends Control

var selection: CarSelectionPanel = null

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

func _on_back_button_pressed() -> void:
	MenuHandler.deactivate_menu()
