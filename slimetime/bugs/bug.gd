extends RigidBody2D

class_name Bug

# Original position of bug.
var starting_position: Vector2

# Whether bug is flying or inactive.
@export var is_slimed: bool = false
# Whether bug is eaten.
# Mainly useful for multiplayer mode, to keep the bug in the scene tree but disable it.
@export var is_eaten: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$AnimatedSprite2D.play()
	starting_position = global_position

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if is_eaten: return  # Don't react eaten bugs with any forces.. they just need to exist somewhere.
	if is_slimed:
		apply_central_force(Vector2(0,Globals.gravity))
		return

# Change state of the bug so it's in a dormant, slimed state.
func get_slimed () -> void:
	is_slimed = true
	$AnimatedSprite2D.play("slimed")

# Get eaten.
func eat () -> void:
	# If multiplayer, need to tell server to update state of bug to "eaten".
	if Globals.is_client:
		_eat.rpc_id(1)
	else:
		queue_free()
# For multiplayer games, disable the bug from the server side after it was eaten by a worm.
@rpc("any_peer","reliable")
func _eat () -> void:
	$CollisionShape2D.set_deferred("disabled",true)
	linear_velocity = Vector2.ZERO
	angular_velocity = 0
	is_eaten = true
	visible = false
func _on_body_entered(body: Node) -> void:
	# Only check collisions for server / local game.
	if multiplayer.get_unique_id() != 1: return
	# Check if getting slimed.
	if "get_collision_layer" in body:
		if body.get_collision_layer() == 2 and not is_slimed:
			get_slimed()
	# Otherwise, hitting something solid, so make a thud.
	else:
		$GroundSound.play()
