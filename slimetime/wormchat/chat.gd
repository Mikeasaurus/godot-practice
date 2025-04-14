extends Control

@onready var dialogue := $MarginContainer/ScrollContainer/CenterContainer/VBoxContainer
var peer_message_scene := preload("res://wormchat/peer_messages.tscn")
var own_message_scene := preload("res://wormchat/own_message.tscn")

## Notification for when new messages are in chat.
signal new_message_notifier
## Indicates that all new messages have been read.
signal all_messages_read

# A switch to call to_bottom on the next frame of processing.
# Can't change the scroll position from the RPC call where we receive the
# message(s); it immediately forgets the scroll value we set there.
# So, instead ask _process to do it for us on the next cycle.
var do_scroll_to_bottom: bool = false

# Miscellaneous stuff
var _ad_shown: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var s: VScrollBar = $MarginContainer/ScrollContainer.get_v_scroll_bar()
	# Chat connect / disconnect signals
	multiplayer.peer_connected.connect(_register)
	multiplayer.peer_disconnected.connect(_unregister)
	# ScrollContainer signals
	s.value_changed.connect(_on_scrolled)
	s.changed.connect(_on_content_added)
	# Miscellaneous stuff
	$SlimeNetAd/VBoxContainer/HBoxContainer/Button.pressed.connect(MenuHandler.deactivate_menu)
	$SlimeNetAd/VBoxContainer/HBoxContainer/Button2.pressed.connect(MenuHandler.deactivate_menu)
	if Globals.chat_font != null:
		$Title/Center/Label.add_theme_font_override("font",Globals.chat_font)
		$PeerTypingLabel.add_theme_font_override("font",Globals.chat_font)
		$TextEdit.add_theme_font_override("font",Globals.chat_font)
# Handle scroll actions requested from outside of normal processing mode.
func _process(_delta: float) -> void:
	if do_scroll_to_bottom:
		to_bottom()
		do_scroll_to_bottom = false

###############################################################################
# Server-side processing.
###############################################################################

# Keep track of how much history has been sent to each peer.
var peer_chat_index: Dictionary = {}

# Keep track of who is currently typing.
# Key is handle, value is time of last typing activity.
var last_typed: Dictionary = {}

# Remember who the last peer message was from, in case we're continuing
# with more messages from that peer.
var current_peer_messages: PeerMessages = null

# Chat history
var chat := []

# Initialize client bookkeeping when they join.
func _register(id) -> void:
	if multiplayer.get_unique_id() != 1: return
	# Peer hasn't received any messages yet, so start at the beginning.
	peer_chat_index[id] = 0
	# Now that there's at least one peer listening for messages, start the synchronizer.
	if $ChatSyncTimer.is_stopped():
		$ChatSyncTimer.start()

func _unregister(id) -> void:
	if multiplayer.get_unique_id() != 1: return
	peer_chat_index.erase(id)

# Server-side function to send the chat history to a peer.
func _on_chat_sync_timer_timeout() -> void:
	var n: int = len(chat)
	for id in peer_chat_index.keys():
		var start: int = peer_chat_index[id]
		if start < n:
			_new_messages.rpc_id(id,chat.slice(start))
			peer_chat_index[id] = n
	# Also send list of users who are currently typing.
	var typers: Array[String] = []
	var current_time: int = Time.get_ticks_msec()
	for handle in last_typed.keys():
		var duration: int = current_time - last_typed[handle]
		# Include anyone that showed typing activity within the last N milliseconds.
		if duration < 5000:
			typers.append(handle)
		# If no such recent activity, then clear them out.
		# Not really needed, but this keeps the dictionary clean.
		else:
			last_typed.erase(handle)
	_who_is_typing.rpc(typers)

# Receive an update that a client is currently typing.
@rpc("any_peer","reliable")
func _peer_typing (handle: String):
	last_typed[handle] = Time.get_ticks_msec()
# Receive a new message from a client, to be distributed.
@rpc("call_local","any_peer","reliable")
func _send_msg (msg: Array) -> void:
	chat.append(msg)
	# If a client just sent a message, then clear their "typing" status.
	var handle: String = msg[0]
	if handle in last_typed:
		last_typed.erase(handle)


###############################################################################
# Client-side processing.
###############################################################################

# Receive new messages from the server.
@rpc("reliable")
func _new_messages (msgs) -> void:
	for msg in msgs:
		var sender: String = msg[0]
		var text: String = msg[1]
		var icon_colours: Array[Color] = msg[2]
		# Message from this own peer.
		if sender == Globals.handle:
			# Done the last peer messages.
			current_peer_messages = null
			var my_message: OwnMessage = own_message_scene.instantiate()
			my_message.text = text
			dialogue.add_child(my_message)
		# Message from a peer.
		else:
			# Starting a new set of messages?
			if current_peer_messages == null or sender != current_peer_messages.peer_name:
				current_peer_messages = peer_message_scene.instantiate()
				current_peer_messages.peer_name = sender
				dialogue.add_child(current_peer_messages)
			current_peer_messages.add_message(text, icon_colours)
	# Send new message notification, if it wasn't immediately displayed.
	if not visible: new_message_notifier.emit()
	if not at_bottom():
		new_message_notifier.emit()
	# If at bottom, then keep scrolling to bottom.
	if at_bottom():
		do_scroll_to_bottom = true

# Receive updates about who is currently typing.
@rpc("reliable")
func _who_is_typing (peers: Array[String]) -> void:
	if Globals.handle in peers:
		peers.erase(Globals.handle)
	if len(peers) == 0:
		$PeerTypingLabel.text = ""
	elif len(peers) == 1:
		$PeerTypingLabel.text = peers[0] + " is typing..."
	elif len(peers) == 2:
		$PeerTypingLabel.text = peers[0] + " and " + peers[1] + " are typing..."
	else:
		$PeerTypingLabel.text = "Several worms are typing..."


# Send a message to the chat.
func send_msg (text: String) -> void:
	var icon_colours: Array[Color] = [
		Globals.worm_body_colour,
		Globals.worm_back_colour,
		Globals.worm_front_colour,
		Globals.worm_outline_colour,
		Globals.worm_icon_bg_colour,
	]
	_send_msg.rpc_id(1,[Globals.handle,text,icon_colours])

# Check if scrolled to bottom of messages.
func at_bottom () -> bool:
	var scroll: ScrollContainer = $MarginContainer/ScrollContainer
	return scroll.scroll_vertical >= scroll.get_v_scroll_bar().max_value - scroll.size.y
# Scroll to bottom of messages.
func to_bottom () -> void:
	var scroll: ScrollContainer = $MarginContainer/ScrollContainer
	# Need to wait until next frame, in case new content was just added to ScrollContainer.
	await get_tree().process_frame
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	# Update state of the scroll button (it should turn itself off at this point.)
	_update_scroll_button()

# Called when the local user is typing into the text input box.
func _on_text_edit_text_changed(new_text: String) -> void:
	# If the text box is non-empty, then send a "typing" status.
	if new_text != "":
		_peer_typing.rpc_id(1,Globals.handle)
# Called when the local user adds a new chat message.
func _on_text_edit_text_submitted(new_text: String) -> void:
	if new_text == "": return  # Ignore blank text submissions.
	send_msg(new_text)
	# Clear the text entry box.
	$TextEdit.clear()
# Button for submitting text (same effect as pressing enter key).
func _on_submit_button_pressed() -> void:
	_on_text_edit_text_submitted($TextEdit.text)
	# Put focus back on text box.
	$TextEdit.grab_focus()

# Modify appearance of bottom button based on scroll position
func _update_scroll_button () -> void:
	# If already scrolled to the bottom, then hide the button.
	# Also reset any notification about new messages.
	if at_bottom():
		$ToBottom.hide()
		$ToBottom/Notifier.hide()
		# If the user is seeing the bottom messages, clear the notification signal.
		if visible: all_messages_read.emit()
	# Otherwise, show the button.
	else:
		$ToBottom.show()
func _on_scrolled (_value: float) -> void:
	_update_scroll_button()
func _on_visibility_changed() -> void:
	if not visible: return
	to_bottom()
	# Start focus on the text input box, so user can start typing immediately.
	# https://www.reddit.com/r/godot/comments/kun5r7/is_there_a_way_to_set_a_node_as_focused_upon_game/?rdt=54934
	# https://docs.godotengine.org/en/stable/tutorials/ui/gui_navigation.html#necessary-code
	$TextEdit.grab_focus()
	# Before displaying the first message, set horizontal spacing for the chat.
	# Use a dummy chat message from a peer, long enough for line wrapping.
	# This gives the maxiumum amount of horizontal space that would be used for a mesage.
	if dialogue != null and dialogue.custom_minimum_size.x == 0:
		var sample: PeerMessages = peer_message_scene.instantiate()
		sample.modulate = Color.TRANSPARENT
		dialogue.add_child(sample)
		sample.add_message("This is a really long message to cause wrapping.")
		# Need to wait 2 frames before the size of the dummy message gets updated.
		await get_tree().process_frame
		await get_tree().process_frame
		# Enforce this size for the chat.
		dialogue.custom_minimum_size.x = sample.size.x
		# Clean out the dummy message (taking up vertical space).
		dialogue.remove_child(sample)
	# Small chance to display the SlimeNet ad when chat is opened.
	if not _ad_shown and (randi() % 20) == 0:
		await get_tree().create_timer(3).timeout
		MenuHandler.activate_menu($SlimeNetAd)
		_ad_shown = true


# Update appearance of bottom button when new content is available.
func _on_content_added () -> void:
	# If not at bottom of scrolling window, then turn on notification icon.
	if not at_bottom():
		$ToBottom/Notifier.show()

# Highlight bottom button when it's hovered.
func _on_to_bottom_mouse_entered() -> void:
	$ToBottom/Arrow.modulate = Color.WHITE
func _on_to_bottom_mouse_exited() -> void:
	$ToBottom/Arrow.modulate = Color.hex(0x777777ff)

# Scroll to bottom when the button is clicked.
func _on_to_bottom_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			to_bottom()

# Logic for "close" button.
func _on_close_mouse_entered() -> void:
	$Close/X.modulate = Color.WHITE
func _on_close_mouse_exited() -> void:
	$Close/X.modulate = Color.hex(0x777777ff)
func _on_close_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			MenuHandler.deactivate_menu()
