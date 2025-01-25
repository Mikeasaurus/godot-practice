extends Node

# Pause menu reference.
# Gets called if there are no more nested menus, and the escape key is pressed.
var pause_menu = null

# Hold active menus in a stack - one on the end is the one currently active.
var menu_stack: Array = []

# Set another menu scene as the active one.
func activate_menu (menu) -> void:
	if len(menu_stack) > 0:
		menu_stack[-1].hide()
	menu.show()
	menu_stack.append(menu)

# Deactivate a menu and return to the parent menu.
func deactivate_menu () -> void:
	var menu = menu_stack.pop_back()
	# Check if there's another menu to return to.
	if len(menu_stack) > 0:
		menu_stack[-1].show()
	# Otherwise, check if game needs to be unpaused.
	elif get_tree().paused:
		get_tree().paused = false
	menu.hide()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Handle escape key trigger - either return to parent menu or pause / unpause the game.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_toggle"):
		# Returning from menu / unpausing
		if len(menu_stack) > 0:
			deactivate_menu()
		# No menu active, so the key will pause the game
		elif pause_menu != null:
			get_tree().paused = true
			activate_menu(pause_menu)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
