extends RigidBody2D
signal hit
@export var hit_sprite: PackedScene

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$AnimatedSprite2D.play("default")
	# Turn on contact monitor
	contact_monitor = true
	# Increase contacts reported, so the collision detection works.
	max_contacts_reported = 5

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

# Remove meteor from game if it somehow leaves screen.
# NOTE: This shouldn't happen under normal circumstances.
func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()

# Remove meteor if it gets hit.
func _on_body_entered(body: Node) -> void:
	hit.emit()
	queue_free()
	var h = hit_sprite.instantiate()
	h.position = position
	add_sibling(h)
