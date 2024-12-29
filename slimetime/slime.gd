extends RigidBody2D

@export var particle_scene: PackedScene

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	# Apply gravity force.
	apply_central_force(Vector2(0,Globals.gravity))

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()

# Spawn some splatter particles based around the given direction.
func _create_splatter (pos: Vector2, direction: Vector2) -> void:
	for i in range(10):
		var p: Node2D = particle_scene.instantiate()
		var angle: float = (randf() - 0.5) * PI
		var speed: float = 100 + randf() * 200
		p.position = pos
		p.linear_velocity = direction.rotated(angle) * speed
		# Have to do a deferred call for adding the particles, otherwise get the error message:
		# ERROR: Can't change this state while flushing queries. Use call_deferred() or set_deferred() to change monitoring state instead.
		call_deferred("add_sibling",p)

# Get normal to any surface that's contacted, align direction vectors accordingly.
func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if state.get_contact_count() > 0:
		var n: Vector2 = state.get_contact_local_normal(0)
		_create_splatter (position, n)

func _on_body_entered(_body: Node) -> void:
	queue_free()
	pass # Replace with function body.
