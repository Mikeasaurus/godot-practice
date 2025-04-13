extends RigidBody2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	# Apply gravity force.
	apply_central_force(Vector2(0,Globals.gravity))


# Get normal to any surface that's contacted, align direction vectors accordingly.
func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	# Only check for contacts if this is the server or a local game.
	if multiplayer.get_unique_id() != 1: return
	# Only splat if a surface is hit, and only splat once.
	if state.get_contact_count() > 0 and $Sprite2D.visible:
		var n: Vector2 = state.get_contact_local_normal(0)
		Globals.request_splatter.emit(global_position, n, z_index)
		queue_free()


# Clean up slime if it's been around for a long time and still hasn't hit anything.
# Probably went out of bounds.
func _on_timer_timeout() -> void:
	if multiplayer.get_unique_id() == 1:
		queue_free()
