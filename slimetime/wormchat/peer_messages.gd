extends Control

class_name PeerMessages

# Series of consecutive chat messages from a peer.
# Arranged with a label above the first message, and the icon appearing only
# on the final message.

var peer_name: String

var icon_scene := preload("res://wormchat/icon.tscn")
var text_scene := preload("res://wormchat/text.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$GridContainer/Label.text = "     " + peer_name

# Add a chat message from the peer.
func add_message (text: String, icon_colours: Array[Color] = []) -> void:
	var icon: Icon
	# If first message, add new icon.
	if $GridContainer.get_child_count() == 2:
		icon = icon_scene.instantiate()
		$GridContainer.add_child(icon)
	# Otherwise, need to move icon down to the next message.
	else:
		icon = $GridContainer.get_child(-4)
		var blank: Control = Control.new()
		icon.add_sibling(blank)
		$GridContainer.move_child(icon,-1)
	# Update colours of the icon, in case the user recently changed them.
	icon.update_colours(icon_colours)
	var textbox: Text = text_scene.instantiate()
	textbox.text = text # text
	$GridContainer.add_child(textbox)
	# Add a spacer between messages.
	var gap: Control = Control.new()
	gap.custom_minimum_size.y = 15
	$GridContainer.add_child(gap)
	$GridContainer.add_child(Control.new())
