extends Control

signal quit
signal push_menu
signal pop_menu

var options_scene: PackedScene = load("res://options_menu.tscn")
var options_menu: Control

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Make options menu available as a sibling to this scene.
	# Not a child, because then the show/hide logic will interfere between them.
	options_menu = options_scene.instantiate()
	options_menu.hide()
	options_menu.pop_menu.connect(pop_menu.emit)
	add_sibling.call_deferred(options_menu)
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func _on_resume_button_pressed() -> void:
	pop_menu.emit()

func _on_options_button_pressed() -> void:
	# Start options sub-menu.
	push_menu.emit(options_menu)

func _on_quit_button_pressed() -> void:
	get_tree().paused = false  # Unpause before sending quit signal.
	quit.emit()
