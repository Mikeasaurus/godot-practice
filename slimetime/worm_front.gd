extends WormSegment

@export var slime_scene: PackedScene
# Where the mouth is located on the sprite.
var mouth_position: Vector2
# Flip mouth position whenever head flips direction.
func flip_segment():
	mouth_position.x *= -1
	super()

# Keep track of all bugs within range.
var targets: Array = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Get position of mouth (for where to shoot slime from)
	mouth_position = $AnimatedSprite2D/SlimeSource.position
	super()

func _input(event: InputEvent) -> void:
	# Check if we need to shoot some slime.
	if Input.is_action_just_pressed("shoot_slime"):
		# How fast slime shoots out.
		var slime_speed: float = 1000.0
		# Where the slime originates from (based on position of worm's mouth).
		var slime_start: Vector2 = mouth_position.rotated($AnimatedSprite2D.rotation)
		# Get the direction to shoot the slime.
		# Check if any targets in range.
		# Otherwise, shoot straight ahead.
		var slime_direction: Vector2 = facing_direction
		if len(targets) > 0:
			slime_direction = (targets[0].global_position - (global_position+slime_start)).normalized()
		var slime = slime_scene.instantiate()
		slime.position = slime_start
		slime.linear_velocity = slime_direction * slime_speed
		add_child(slime)
# Called every frame. 'delta' is the elapsed time since the previous frame.
func __process(delta: float) -> void:
	pass

func _on_shooting_range_body_entered(body: Node2D) -> void:
	targets.append(body)

func _on_shooting_range_body_exited(body: Node2D) -> void:
	targets.erase(body)
