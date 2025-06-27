extends Node

# Code for managing menu systems.
# Controls delegation to sub-menus, and returning to parent menus afterwards.

# A signal that is sent when all submenus are finished.
signal done_submenus

# A signal that is sent out when there are no submenus active, but an escape key is pressed.
# This could be intercepted by a scene and handled as a pause key.
signal pause

# Hold active menus in a stack - one on the end is the one currently active.
var menu_stack: Array = []

# Set another menu scene as the active one.
func activate_menu (menu) -> void:
	if len(menu_stack) > 0:
		menu_stack[-1].get_node("MarginContainer").hide()
	menu.show()
	menu_stack.append(menu)

# Deactivate a menu and return to the parent menu.
func deactivate_menu () -> void:
	# In case a nested menu is launched directly (for testing), need to ignore
	# any deactivation signals.
	if len(menu_stack) == 0:
		print ("Menu stack empty - nothing to deactivate!")
		return
	var menu = menu_stack.pop_back()
	# Check if there's another menu to return to.
	if len(menu_stack) > 0:
		menu_stack[-1].get_node("MarginContainer").show()
	else:
		done_submenus.emit()
	menu.hide()

# Called before scene is changed, to avoid holding onto invalid references.
func clear_menus () -> void:
	menu_stack = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Need to always be able to listen for escape key.
	process_mode = PROCESS_MODE_ALWAYS

# Handle escape key trigger - either return to parent menu or pause / unpause the game.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_toggle"):
		# Returning from menu / unpausing
		if len(menu_stack) > 0:
			deactivate_menu()
		# No menu active, so the key will pause the game
		else:
			pause.emit()
