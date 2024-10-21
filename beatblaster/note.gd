extends RigidBody2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
		# Set the note type
		var note_labels = $AnimatedSprite2D.sprite_frames.get_animation_names()
		$AnimatedSprite2D.play(note_labels[randi() % note_labels.size()])

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

# Remove note from the game if it leaves the screen.
func _on_visible_on_screen_notifier_2d_screen_exited():
	queue_free()
