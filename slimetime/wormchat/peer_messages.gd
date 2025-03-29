extends Control

class_name PeerMessages

# Series of consecutive chat messages from a peer.
# Arranged with a label above the first message, and the icon appearing only
# on the final message.

var peer_name: String

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$GridContainer/Label.text = "     " + peer_name

# Add a chat message from the peer.
func add_message (text: String, icon_colours: Array[Color] = []) -> void:
	var icon: Icon
	# If first message, add new icon.
	if $GridContainer.get_child_count() == 2:
		icon = preload("res://wormchat/icon.tscn").instantiate()
		if len(icon_colours) > 0:
			icon.body = icon_colours[0]
			icon.back = icon_colours[1]
			icon.front = icon_colours[2]
			icon.outline = icon_colours[3]
			icon.bg = icon_colours[4]
		$GridContainer.add_child(icon)
	# Otherwise, need to move icon down to the next message.
	else:
		icon = $GridContainer.get_child(-4)
		var blank: Control = Control.new()
		icon.add_sibling(blank)
		$GridContainer.move_child(icon,-1)
	var textbox: Text = preload("res://wormchat/text.tscn").instantiate()
	textbox.text = text # text
	$GridContainer.add_child(textbox)
	# Add a spacer between messages.
	var gap: Control = Control.new()
	gap.custom_minimum_size.y = 15
	$GridContainer.add_child(gap)
	$GridContainer.add_child(Control.new())
