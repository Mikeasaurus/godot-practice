extends RigidBody2D

class_name WormSegment

# How fast the worm will walk on a surface (pixels/second)
@export var walking_speed: float = 100.0

# Attraction point.  Either for gravity or for sticking to a surface.
var gravity_point: Vector2 = Vector2.ZERO

# Direction that the segment will try to point towards (for standing on a surface)
var stand_angle: float = NAN
# Optional connections to other segments.
var front_segment: WormSegment = null
var segment_spacing: float = 30.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	gravity_point = global_position + Vector2(0,100)

func set_front_segment (segment: WormSegment) -> void:
	front_segment = segment

# Get normal to any surface that's contacted.
func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	pass
	if state.get_contact_count() > 0:
		stand_angle = state.get_contact_local_normal(0).angle() + PI/2
		gravity_point = global_position - state.get_contact_local_normal(0)*50
	else:
		stand_angle = NAN

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var gp: Vector2 = gravity_point
	# Apply a torque to align the body segment with a surface.
	if is_finite(stand_angle):
		var angle_diff: float = stand_angle - rotation
		if angle_diff < -PI: angle_diff += 2*PI
		if angle_diff > PI: angle_diff -= 2*PI
		#TODO: smooth rotation
		$AnimatedSprite2D.global_rotation = stand_angle
	# Apply a force to bring the segment to the correct distance to the front and back neighbours.
	# TODO: revisit this for when the worm is turning around.
	if front_segment != null:
		var to_other: Vector2 = front_segment.position - position
		var distance: float = to_other.length()
		if distance > segment_spacing:
			linear_velocity = (distance - segment_spacing) * to_other.normalized() * 10
	# Check if moving, need to animate legs?
	if linear_velocity.length() > 10:
		$AnimatedSprite2D.play()
	else:
		$AnimatedSprite2D.pause()
	# Check for user-driven movement, if this is the front (leader) segment.
	if front_segment == null:
		if Input.is_action_pressed("move_right") and is_finite(stand_angle):
			gp += (gravity_point - global_position).rotated(-PI/2).normalized() * 50
	# Apply the force to keep stuck to a surface / move in a direction.
	apply_central_force((gp-global_position).normalized()*200)
	# Visual aid for centre of force, for debugging.
	$GravityPoint.global_position = gp
