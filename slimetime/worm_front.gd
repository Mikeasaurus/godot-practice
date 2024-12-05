extends WormSegment

@export var slime_scene: PackedScene
# Where the mouth is located on the sprite.
var mouth_position: Vector2
# Flip mouth position whenever head flips direction.
func flip_segment(adjust_zorder=true):
	mouth_position.x *= -1
	super(adjust_zorder)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Get position of mouth (for where to shoot slime from)
	mouth_position = $AnimatedSprite2D/SlimeSource.position
	super()

func _input(event: InputEvent) -> void:
	# Check if we need to shoot some slime.
	if Input.is_action_just_pressed("shoot_slime"):
		var slime = slime_scene.instantiate()
		slime.position = mouth_position.rotated($AnimatedSprite2D.rotation)
		slime.linear_velocity = get_facing_direction() * 1000.0
		add_child(slime)
# Called every frame. 'delta' is the elapsed time since the previous frame.
func __process(delta: float) -> void:
	pass
