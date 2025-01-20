extends RigidBody2D

class_name Bug

# Original position of bug.
var starting_position: Vector2

# Whether bug is flying or inactive.
var is_slimed: bool

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$AnimatedSprite2D.play()
	starting_position = global_position
	is_slimed = false

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if is_slimed:
		apply_central_force(Vector2(0,Globals.gravity))
		return
	# For debugging - force bug to be in "slimed" state.
	if Globals.debug_keys and Input.is_action_pressed("slime_all"):
		get_slimed()

# Change state of the bug so it's in a dormant, slimed state.
func get_slimed () -> void:
	is_slimed = true
	$AnimatedSprite2D.play("slimed")

# Get eaten.
func eat () -> void:
	queue_free()

func _on_body_entered(body: Node) -> void:
	# Check if getting slimed.
	if "get_collision_layer" in body:
		if body.get_collision_layer() == 2 and not is_slimed:
			get_slimed()
	# Otherwise, hitting something solid, so make a thud.
	else:
		$GroundSound.play()
