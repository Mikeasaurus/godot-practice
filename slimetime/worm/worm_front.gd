extends WormSegment

signal ate_bug

# Use these PackedScenes to instansiate these effects at runtime.
# Alternatively, could use "preload" on the scene files.
# Don't know which is better in this case.  I'm just carrying over this idiom from
# my first Godot tutorial practice.
@export var slime_scene: PackedScene
@export var crumb_scene: PackedScene

# Where the mouth is located on the sprite.
var mouth_position: Vector2

# Helper method - flip the segment in the opposite direction.
# Maybe there's a better way to do this?
# can't find a way to do this to all child nodes in one shot, need to
# do each one individually?
func flip_segment():
	# Flip mouth position whenever head flips direction.
	mouth_position.x *= -1
	$Sprites/EatingArea/CollisionShape2D.position.x *= -1
	# Flip the components.
	$Sprites/Outline.flip_h = not $Sprites/Outline.flip_h
	$Sprites/Body.flip_h = not $Sprites/Body.flip_h
	$Sprites/Top.flip_h = not $Sprites/Top.flip_h
	$Sprites/Belly.flip_h = not $Sprites/Belly.flip_h
	$Sprites/AppendageOutline.flip_h = not $Sprites/AppendageOutline.flip_h
	$Sprites/Eyes.flip_h = not $Sprites/Eyes.flip_h
	$Sprites/Mouth.flip_h = not $Sprites/Mouth.flip_h
	# Change sign of horizontal offset.
	$Sprites/Outline.offset.x *= -1
	$Sprites/Body.offset.x *= -1
	$Sprites/Top.offset.x *= -1
	$Sprites/Belly.offset.x *= -1
	$Sprites/AppendageOutline.offset.x *= -1
	$Sprites/Eyes.offset.x *= -1
	$Sprites/Mouth.offset.x *= -1
	for frame in $Sprites/Animation.get_children():
		for s in frame.get_children():
			s.flip_h = not s.flip_h
			s.offset.x *= -1

# Keep track of all bugs within range.
var targets: Array = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Get position of mouth (for where to shoot slime from)
	mouth_position = $Sprites/SlimeSource.position
	# Continue setting up other properties of the segment.
	super()

# Called when the worm's colour scheme needs to be updated.
func refresh_colour_scheme () -> void:
	$Sprites/Body.modulate = Globals.worm_body_colour
	$Sprites/Top.modulate = Globals.worm_back_colour
	$Sprites/Belly.modulate = Globals.worm_front_colour
	$Sprites/AppendageOutline.modulate = Globals.worm_outline_colour
	$Sprites/Eyes.modulate = Globals.worm_outline_colour
	$Sprites/Mouth.modulate = Globals.worm_body_colour
	$Sprites/Outline.modulate = Globals.worm_outline_colour
	for frame in $Sprites/Animation.get_children():
		frame.get_node("Foreleg").modulate = Globals.worm_body_colour
		frame.get_node("Backleg").modulate = Globals.worm_front_colour
		frame.get_node("Outlines").modulate = Globals.worm_outline_colour
# Helper method - get optimal angle for targeting the given object.
# Used for targeting bugs with slime.
func _get_targeting_angle (pos: Vector2, obj) -> float:
	# Start by aiming at where the object currently is.
	var angle: float = (obj.global_position - pos).angle()
	# Calculate time needed to get there.
	var t: float = (obj.global_position - pos).length() / Globals.slime_speed
	var dangle: float = 0.1   # "delta angle", not "dangle" :)
	var dt: float = 0.1
	# Iterative solver for optimal angle.
	# Not able to get direct solution, because need to find the intersection between
	# the parabolic curve of the slime, and the sinusoidal oscillation of the bug.
	# Fortunately, the approach taken below seems to converge quickly for the tests done.
	# I have the math written down on paper, if you want to see it.
	# (ha ha, it's probably in the trash by the time you read this)
	# (screw you, future Mike!)
	for n in range(3):
		# Calculate distance at predicted collision point.
		var l: Vector2 = _get_collision_mismatch (pos, obj, angle, t)
		# Get rate of change of collision distance if angle or expected collision time is perturbed.
		var dldangle: Vector2 = (_get_collision_mismatch(pos,obj,angle+dangle,t) - _get_collision_mismatch(pos,obj,angle,t)) / dangle
		var dldt: Vector2 = (_get_collision_mismatch(pos,obj,angle,t+dt) - _get_collision_mismatch(pos,obj,angle,t)) / dt
		# Adjust angle / collision time.
		var a: float = dldangle.x
		var b: float = dldt.x
		var c: float = dldangle.y
		var d: float = dldt.y
		var delta_angle: float = -1/(a*d-b*c) * (d*l.x - b*l.y)
		var delta_t: float = -1/(a*d-b*c) * (-c*l.x + a*l.y)
		angle += delta_angle
		t += delta_t
	return angle
# Helper method - get distance between slime and object at the given point in time.
func _get_collision_mismatch (x0: Vector2, obj, angle: float, t: float) -> Vector2:
	return obj.predict_location(t) - _predict_slime_location (x0, angle, t)
# Helper method - estimate where a slime shot would be at time t after being fired
# at the specified angle.
func _predict_slime_location (x0: Vector2, angle: float, t: float) -> Vector2:
	return x0 + Vector2(Globals.slime_speed*t*cos(angle), Globals.slime_speed*t*sin(angle) + Globals.gravity/2 * t**2)


func shoot_slime (t = null) -> void:
		# Where the slime originates from (based on position of worm's mouth).
		var slime_start: Vector2 = mouth_position.rotated($Sprites.global_rotation)
		# Get the direction to shoot the slime.
		# Check if any targets in range.
		# Otherwise, shoot straight ahead.
		var slime_direction: Vector2 = facing_direction
		# Find first viable target (that isn't already slimed).
		# Or, if a specific target is passed, then only consider that one.
		var target_list: Array = targets
		if t != null:
			target_list = [t]
		for target in target_list:
			if not target.is_slimed:
				var angle: float = _get_targeting_angle(global_position+slime_start, target)
				# Only if angle is good (e.g. not shooting from back of head)
				if abs(angle-facing_direction.angle()) < PI/2:
					slime_direction = Vector2.from_angle(angle)
					break
		var slime = slime_scene.instantiate()
		add_child(slime)
		slime.global_position = global_position + slime_start
		slime.linear_velocity = slime_direction * Globals.slime_speed
		# Play a sound when shooting slime.
		$SpitSound.play()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func __process(_delta: float) -> void:
	pass

# Helper function - spawn particles when chewing food.
func _chew_food () -> void:
	$EatSound.play()
	for i in range(5):
		var p: Node2D = crumb_scene.instantiate()
		var angle: float = (randf() - 0.5) * PI
		var speed: float = 100 + randf() * 200
		p.position = position + mouth_position.rotated($Sprites.global_rotation)
		p.linear_velocity = facing_direction.rotated(angle) * speed
		p.z_index = z_index
		# Have to do a deferred call for adding the particles, otherwise get the error message:
		# ERROR: Can't change this state while flushing queries. Use call_deferred() or set_deferred() to change monitoring state instead.
		call_deferred("add_sibling",p)


func _on_shooting_range_body_entered(body: Node2D) -> void:
	# Only keep track of targetable objects.
	if "predict_location" in body:
		targets.append(body)

func _on_shooting_range_body_exited(body: Node2D) -> void:
	targets.erase(body)


func _on_eating_area_body_entered(body: Node2D) -> void:
	if "eat" in body:
		_chew_food()
		body.eat()
		ate_bug.emit()

func _on_landed() -> void:
	$GroundSound.play()
