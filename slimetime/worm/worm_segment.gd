extends RigidBody2D

class_name WormSegment

# Signal to indicate the segment has landed on a surface
signal landed

# Signal to indicate the segment just took some damage
signal hurt

# Remember contact direction of the last surface that was attached to.
var last_surface_normal: Vector2
# Remember a surface reference point (to help correct trajectory if starting to leave surface).
var last_surface_reference: Vector2
# Indicates if currently standing on a surface (to determine if user can control
# movement)
# Exported so it can be managed by a MultiplayerSynchronizer (so other peers can
# see the walking animation when it's moving on a surface).
@export var on_surface: bool
# Indicates if the feet should "stick" strongly to a surface that it touches.
var sticky_feet: bool

# Optional - body to use as reference frame for maintaining velocity.
# For example, a moving platform.
var reference_body = null

# Whether to turn off usual collision info stuff and let worm be controlled externally.
var _passive: bool = false

# Remember starting position, so we can "respawn" there later in multiplayer.
@onready
var _spawn_position: Vector2 = global_position

# Define a relative velocity based on reference body.
var relative_linear_velocity: Vector2: get = get_relative_linear_velocity
func get_relative_linear_velocity () -> Vector2:
	if reference_body != null:
		return linear_velocity - reference_body.linear_velocity
	else:
		return linear_velocity

# Direction that the segment is pointing towards
# This is exported so it can be managed by a MultiplayerSynchronizer.
@export var facing_direction: Vector2
# Direction that the segment's feet are in.
# Only general direction of this is used.  facing_direction will determine exact angles.
@export var feet_direction: Vector2

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Show the first frame of the walking sprites.
	$Sprites/Animation/Frame1.show()
	$Sprites/Animation/Frame2.hide()
	$Sprites/Animation/Frame3.hide()
	# If this is a multiplayer game and this isn't *our* worm, then make it passive.
	if (Globals.is_client or Globals.is_server) and get_multiplayer_authority() != multiplayer.get_unique_id():
		$DamageArea2D.collision_mask = 0
		_passive = true
		return
	# Initialize the colour scheme of the worm.
	refresh_colour_scheme()
	# Listen for any further updates to colour scheme, and update accordingly.
	Globals.worm_colour_updated.connect(refresh_colour_scheme)
	# Set gravity, so segment will start falling onto the surface below
	# if it's placed above the ground.
	last_surface_normal = Vector2(0,1)
	last_surface_reference = Vector2.ZERO
	# Set the direction that the segment is facing toward.
	facing_direction = Vector2(1,0)
	# Set the feet direction.
	feet_direction = Vector2(0,1)
	# Ready to land and stick to a surface.
	on_surface = false
	sticky_feet = true
	# Detect plaform touching
	body_entered.connect(_on_body_entered)

# Called when the worm's colour scheme needs to be updated.
func refresh_colour_scheme (body = null, back = null, front = null, outline = null) -> void:
	if body == null:
		body = Globals.worm_body_colour
	if back == null:
		back = Globals.worm_back_colour
	if front == null:
		front = Globals.worm_front_colour
	if outline == null:
		outline = Globals.worm_outline_colour
	$Sprites/Body.modulate = body
	$Sprites/Top.modulate = back
	$Sprites/Outline.modulate = outline
	for frame in $Sprites/Animation.get_children():
		frame.get_node("Foreleg").modulate = body
		frame.get_node("Outlines").modulate = outline


# Helper method - flip the segment in the opposite direction.
# Maybe there's a better way to do this?
# can't find a way to do this to all child nodes in one shot, need to
# do each one individually?
func flip_segment() -> void:
	# Flip the components.
	$Sprites/Outline.flip_h = not $Sprites/Outline.flip_h
	$Sprites/Body.flip_h = not $Sprites/Body.flip_h
	$Sprites/Top.flip_h = not $Sprites/Top.flip_h
	# Change sign of horizontal offset.
	$Sprites/Outline.offset.x *= -1
	$Sprites/Body.offset.x *= -1
	$Sprites/Top.offset.x *= -1
	for frame in $Sprites/Animation.get_children():
		for s in frame.get_children():
			s.flip_h = not s.flip_h
			s.offset.x *= -1
func is_flipped() -> bool:
	return $Sprites/Body.flip_h

# Helper method - update sprite based on current facing direction and feet direction.
func update_sprite() -> void:
	var orientation: Vector2 = facing_direction
	# Check if need to flip the segment around.
	# Y direction is flipped (positive downward), so sign check for cross
	# product is flipped as well.
	var need_flip: bool = feet_direction.cross(facing_direction) > 0
	if need_flip != is_flipped():
		flip_segment()
	if is_flipped():
		orientation *= -1
	$Sprites.global_rotation = orientation.angle()
	# Update feet direction.
	var v: Vector2 = orientation.rotated(PI/2)
	if v.dot(feet_direction) > 0:
		feet_direction = v
	else:
		feet_direction = -v

# Get normal to any surface that's contacted, align direction vectors accordingly.
func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if not sticky_feet: return
	if _passive: return
	var n = state.get_contact_count()
	if n > 0:
		# Sum up all contact normals.
		# Should make it less jittery when transitioning from one surface to another?
		var v: Vector2 = Vector2.ZERO
		for i in range(n):
			v  += state.get_contact_local_normal(i)
		# Stand upright on surface.
		last_surface_normal = -v.normalized()
		last_surface_reference = global_position + last_surface_normal * 50
		feet_direction = last_surface_normal
		# Update facing direction based on feet direction.
		if feet_direction.cross(facing_direction) < 0:
			facing_direction = feet_direction.rotated(-PI/2)
		else:
			facing_direction = feet_direction.rotated(PI/2)
		if not on_surface:
			landed.emit()  # For playing landing sound (handled in worm_front)
		on_surface = true

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Check if moving, need to animate legs?
	if on_surface and relative_linear_velocity.length() > 10:
		$AnimationPlayer.play("walk")
	else:
		$AnimationPlayer.pause()
	# Update surface reference?
	# Should move with reference frame (e.g. platform).
	# Otherwise, if the worm is almost landing on the moving platform (but front is not quite touching)
	# then there's some piece of code that will make the front gravitate toward this reference point.
	# If the reference point is not on the platform, then worm ends up stuck in mid-air.
	if reference_body != null and last_surface_reference != null:
		last_surface_reference += reference_body.linear_velocity * delta

# Helper method - Set the velocity along the given direction.
# Velocity in orthogonal direction is left untouched.
func set_relative_velocity_in_direction (direction: Vector2, vel: float) -> void:
	# Normalized direction of effect
	var v: Vector2 = direction.normalized()
	# Target linear velocity
	var lv: Vector2 = relative_linear_velocity
	# Strip out current velocity along that direction.
	lv -= lv.dot(v) * v
	# Add in desired velocity
	lv += vel * v
	# Adjust the velocity through an impulse.
	apply_central_impulse(lv-relative_linear_velocity)

# Helper function - release segment from a surface so it has time for reacting to
# impulses or other forces (such as to initiate a jump).
func release_from_surface () -> void:
	sticky_feet = false
	on_surface = false
	last_surface_reference = Vector2.ZERO
	reference_body = null
	# Re-enable a gravitational force
	last_surface_normal = Vector2(0,1)
	$JumpTimer.start()
# Callback function, called shortly after jump was initiated.
# Re-enables "sticking" to surfaces, for when worm lands from the jump.
func _on_jump_timer_timeout() -> void:
	sticky_feet = true

func _on_damage_area_2d_body_entered(_body: Node2D) -> void:
	hurt.emit()

# Respawn to starting position.
func respawn () -> void:
	set_deferred("global_position",_spawn_position)

# If attaching to something (such as moving platform), then track with that thing's motion.
func _on_body_entered(body: Node) -> void:
	if sticky_feet:
		if "linear_velocity" in body:
			reference_body = body
		else:
			reference_body = null
