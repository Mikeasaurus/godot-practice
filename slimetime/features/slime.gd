extends RigidBody2D

@export var particle_scene: PackedScene

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	# Apply gravity force.
	apply_central_force(Vector2(0,Globals.gravity))

# Spawn some splatter particles based around the given direction.
@rpc("authority","call_local","reliable")
func _create_splatter (pos: Vector2, direction: Vector2) -> void:
	for i in range(10):
		var p: Node2D = particle_scene.instantiate()
		var angle: float = (randf() - 0.5) * PI
		var speed: float = 100 + randf() * 200
		p.position = pos
		p.linear_velocity = direction.rotated(angle) * speed
		p.z_index = z_index
		# Have to do a deferred call for adding the particles, otherwise get the error message:
		# ERROR: Can't change this state while flushing queries. Use call_deferred() or set_deferred() to change monitoring state instead.
		call_deferred("add_sibling",p)
	# Play a sound.
	$SplatSound.play()

# Get normal to any surface that's contacted, align direction vectors accordingly.
func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	# Only check for contacts if this is the server or a local game.
	if multiplayer.get_unique_id() != 1: return
	# Only splat if a surface is hit, and only splat once.
	if state.get_contact_count() > 0 and $Sprite2D.visible:
		var n: Vector2 = state.get_contact_local_normal(0)
		_create_splatter.rpc (position, n)
		# Turn slime invisible until gets cleaned up.
		$Sprite2D.visible = false
		# Also stop it from colliding, so bugs don't get hit by stray, invisible slimes.
		collision_layer = 0

func _on_splat_sound_finished() -> void:
	# Only clean up from server or single player.
	# Remote clients will have the scene managed by a MultiplayerSpawner.
	if multiplayer.get_unique_id() == 1:
		queue_free()

# Clean up slime if it's been around for a long time and still hasn't hit anything.
# Probably went out of bounds.
func _on_timer_timeout() -> void:
	if multiplayer.get_unique_id() == 1:
		queue_free()
