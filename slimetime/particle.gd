extends RigidBody2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass # Replace with function body.
	
# Remove particle if it touches something solid, or leaves the screen. 
func _on_body_entered(body: Node2D) -> void:
	queue_free()
func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()