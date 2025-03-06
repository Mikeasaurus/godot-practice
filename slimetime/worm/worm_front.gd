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
	$Sprites/HeadDamageArea2D/CollisionShape2D.position.x *= -1
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

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Get position of mouth (for where to shoot slime from)
	mouth_position = $Sprites/SlimeSource.position
	# Continue setting up other properties of the segment.
	super()
	# If this is a multiplayer game and this isn't *our* worm, then make it passive.
	if (Globals.is_client or Globals.is_server) and get_multiplayer_authority() != multiplayer.get_unique_id():
		$DamageArea2D.collision_mask = 0
		_passive = true
		$Sprites/HeadDamageArea2D.collision_mask = 0
		$Sprites/EatingArea.collision_mask = 0
		$Sprites/Camera2D.enabled = false
		return

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
	$Sprites/Belly.modulate = front
	$Sprites/AppendageOutline.modulate = outline
	$Sprites/Eyes.modulate = outline
	$Sprites/Mouth.modulate = body
	$Sprites/Outline.modulate = outline
	for frame in $Sprites/Animation.get_children():
		frame.get_node("Foreleg").modulate = body
		frame.get_node("Backleg").modulate = front
		frame.get_node("Outlines").modulate = outline

func shoot_slime (t = null) -> void:
		# Where the slime originates from (based on position of worm's mouth).
		var slime_start: Vector2 = mouth_position.rotated($Sprites.global_rotation)
		# If no target direction given, then shoot straight ahead.
		var slime_direction: Vector2 = facing_direction
		# The input argument is the direction to shoot.
		if t != null:
			slime_direction = (t-(global_position+slime_start)).normalized()
			# If shooting in backwards direction, turn the head around first.
			# It will turn around anyway after a split second because the walk action will
			# be brielfly triggered, but then the slime starting location would be for the original
			# mouth location before turning around.
			if slime_direction.dot(facing_direction) < 0:
				facing_direction *= -1
				update_sprite()
				# Refresh slime starting location.
				slime_start = mouth_position.rotated($Sprites.global_rotation)

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


func _on_eating_area_body_entered(body: Node2D) -> void:
	if "eat" in body:
		_chew_food()
		body.eat()
		ate_bug.emit()

func _on_landed() -> void:
	$GroundSound.play()
