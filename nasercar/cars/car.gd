extends RigidBody2D
class_name Car

## Top speed of car (pixels/second)
@export var max_speed: float = 1500.0

## Acceleration (pixels/second/second)
@export var acceleration: float = 500.0

## Drag (as deceleration)
@export var deceleration: float = acceleration/3

## Brake power (pixels/second/second)
@export var brakes: float = acceleration*2

## How far the wheels can turn in one direction (degrees)
@export var max_wheel_angle: float = 30.0

## How fast the wheels can turn (degrees/sec)
@export var wheel_turn_speed: float = 120.0

## Emit signal when an item block is touched.
signal itemblock

## Emit signal when meteor impacts.
signal meteor_impact

## Effects currently applied to the car
enum EffectType {SLIMED,NAILPOLISHED,CAFFEINATED,SMOULDERING}
var effects: Dictionary = {}

## Effects applied to individual wheels.
@onready var wheels: Array[Node2D] = [$Wheels/FrontLeft, $Wheels/FrontRight, $Wheels/RearLeft, $Wheels/RearRight]
var wheel_skidmarks: Array[SkidMark] = [null, null, null, null]
var wheel_effects: Array[Dictionary] = [{},{},{},{}]

# Tilesets of the world.
# Need a reference to them to query for physics parameters and other effects.
var _tilesets: Array[TileMapLayer]

# Friction modifier (for changing value during a collision.)
var collision_friction_modifier: float = 1.0

## Whether this car is allowed to move.
var moveable: bool = false

enum CarType {PLAYER, CPU, REMOTE}

## Type of car
var type

## The path to follow if this is a CPU.
var path: Path2D = null
var _pathfollow: PathFollow2D = null
# For tracking player progress along path.
var _old_path_pos: Vector2 = Vector2.ZERO
# For restoring proper offset after wavering effect
var _path_offset: float

# For playing crashing sound.
var _crashing: bool = false
# For sinking into water and playing splash sound.
var _splashing: bool = false

## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Raise the z_index so effects like skid marks appear beneath it.
	z_index = 2

# Add track information (world tiles, path from start to finish of race).
func add_to_track (track_path: Path2D, tilesets: Array[TileMapLayer]) -> void:
	_tilesets = tilesets
	type = CarType.REMOTE
	_pathfollow = PathFollow2D.new()
	track_path.add_child(_pathfollow)
	var offset: Vector2 = global_position - track_path.curve.get_point_position(0)
	#TODO: more robost with starting orientation.
	_pathfollow.v_offset = offset.x
	# Remember this offset in case we need to shift the path for wavering effect.
	_path_offset = _pathfollow.v_offset

# Let this car be playable by the local user.
func make_playable () -> void:
	type = CarType.PLAYER
	$Camera2D.enabled = true
	$Arrow.show()
	# Make own engine sound louder.
	$EngineSound.volume_db = 1.0

# Make this car follow a predetermined path
# (as local CPU).
func make_cpu () -> void:
	type = CarType.CPU

# Allow this car to start moving.
func go () -> void:
	moveable = true

# Stop this car from moving.
func stop () -> void:
	moveable = false

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Arrow pointing to player needs to stay oriented upward.
	$Arrow.global_rotation = 0
	$Arrow.scale = 2*Vector2(1/$Camera2D.zoom.x, 1/$Camera2D.zoom.y)
	$Arrow.offset.y = -60*$Camera2D.zoom.y
	# Same with smouldering effects.
	$Meteor.global_rotation = 0

	#######################################################
	# Apply effects
	#######################################################
	# CPU cars waver around when slimed.
	if EffectType.SLIMED in effects:
		_pathfollow.v_offset = _path_offset + 200*sin((Time.get_ticks_msec()%1000)/1000. * 2*PI)
	else:
		_pathfollow.v_offset = _path_offset
	# Smouldering cars have effects applied.
	var smoulder_speed_limiter: float = 1.0
	var smoulder_drag: float = 1.0
	if EffectType.SMOULDERING in effects:
		var smoulder_duration: float = Time.get_ticks_msec() - effects[EffectType.SMOULDERING]
		if smoulder_duration < 3000:
			$Body.modulate = Color.BLACK
			$Wheels.modulate = Color.BLACK
			if not $Meteor/CPUParticles2D.emitting:
				$Meteor/CPUParticles2D.emitting = true
			smoulder_speed_limiter = 0.0
			smoulder_drag = 10.0
		elif smoulder_duration < 6000:
			var c: float = (smoulder_duration-3000)/3000
			$Body.modulate = Color(c,c,c)
			$Wheels.modulate = Color(c,c,c)
			smoulder_speed_limiter = c
		else:
			$Body.modulate = Color.WHITE
			$Meteor/CPUParticles2D.emitting = false
			effects.erase(EffectType.SMOULDERING)
	
	var dr: float = wheel_turn_speed * delta / 180 * PI
	var max_r: float = max_wheel_angle / 180 * PI

	#######################################################
	# Path-following for CPUs
	#######################################################
	if type == CarType.CPU and _pathfollow != null:
		# Make sure our target point is far enough ahead.
		var target_direction: Vector2 = _pathfollow.global_position - global_position
		var dx: float = target_direction.length()
		if dx < 10:
			_pathfollow.progress += 300
		else:
			_pathfollow.progress += (300/dx) * linear_velocity.length() * delta
		var angle: float = target_direction.angle() - global_rotation
		for wheel in [$Wheels/FrontLeft, $Wheels/FrontRight]:
			# Target angle of wheel (from wheel frame of reference).
			var target_angle: float = target_direction.angle() - PI/2 - rotation
			# Difference in angle between wheel and target path.
			var angle_diff: float = target_angle - wheel.rotation
			if angle_diff >= PI: angle_diff -= 2*PI
			elif angle_diff <= -PI: angle_diff += 2*PI
			if angle_diff < 0:
				if wheel.rotation > -max_r:
					wheel.rotation -= dr
			elif angle_diff > 0:
				if wheel.rotation < max_r:
					wheel.rotation += dr

	#######################################################
	# Path-tracking for player
	#######################################################
	# (So player can be returned to road when something happens to their car).
	if type == CarType.PLAYER and _pathfollow != null:
		# Check if "progress" is needed for updating the path.
		var distance_to_path: float = (global_position-_pathfollow.global_position).length()
		if distance_to_path < (global_position-_old_path_pos).length():
			_old_path_pos = _pathfollow.global_position
			_pathfollow.progress += 300
		# Point to where player was last on the path, if they wandered too far.
		$LostArrow.global_rotation = (_pathfollow.global_position-global_position).angle() + PI/2
		if distance_to_path > 2000:
			if not $LostArrow.visible:
				$LostArrow/Fade.play("fade_in")
		elif distance_to_path < 500 and $LostArrow.visible:
			$LostArrow/Fade.play("fade_out")

	#######################################################
	# Wheel-turning for player
	#######################################################
	if type == CarType.PLAYER:
		# Turn left
		if Input.is_action_pressed("turn_left"):
			for wheel in [$Wheels/FrontLeft, $Wheels/FrontRight]:
				if wheel.rotation > -max_r:
					wheel.rotation -= dr
		# Turn right
		elif Input.is_action_pressed("turn_right"):
			for wheel in [$Wheels/FrontLeft, $Wheels/FrontRight]:
				if wheel.rotation < max_r:
					wheel.rotation += dr
		# Re-center
		else:
			for wheel in [$Wheels/FrontLeft, $Wheels/FrontRight]:
				if wheel.rotation < 0:
					wheel.rotation += 2*dr
				elif wheel.rotation > 0:
					wheel.rotation -= 2*dr
				if abs(wheel.rotation) <= 2*dr:
					wheel.rotation = 0

	#######################################################
	# Movement
	#######################################################
	var go_pressed: bool = Input.is_action_pressed("go")
	var stop_pressed: bool = Input.is_action_pressed("stop")
	var reverse_pressed: bool = Input.is_action_pressed("reverse")
	# Check for speed modifiers.
	var acceleration_modifier: float = 1.0
	var max_speed_modifier: float = 1.0
	var friction_modifier: float = 1.0
	if EffectType.CAFFEINATED in effects:
		if Time.get_ticks_msec() <= effects[EffectType.CAFFEINATED] + 5000:
			acceleration_modifier *= 5.0
			max_speed_modifier *= 2.0
			friction_modifier *= 2.0
		else:
			$Coffee/CPUParticles2D.emitting = false
			effects.erase(EffectType.CAFFEINATED)
	# Keep track of how fast wheels are spinning (fastest one).
	# Value is used for things like zoom level and engine pitch.
	var fastest_wheel_speed: float = 0.0
	# Check if any wheels end up skidding, so a sound can play.
	var skidding: bool = false
	var skid_sounds: Array[bool] = [false,false,false]
	var sinking: bool = true  # becomes false if any wheel on solid ground.
	for w in range(len(wheels)):
		var wheel: Node2D = wheels[w]
		# Velocity of point where wheel connects to car
		var wheel_velocity: Vector2 = linear_velocity + wheel.position.rotated(rotation+PI/2) * angular_velocity
		# Direction that wheel is pointing.
		var wheel_direction: Vector2 = Vector2.from_angle(wheel.global_rotation + PI/2)
		var wheel_orthogonal_direction: Vector2 = Vector2.from_angle(wheel.global_rotation)
		# Infer current wheel speed based on speed w.r.t. ground.
		var current_speed: float = wheel_velocity.dot(wheel_direction)
		# Update speed based on user input.
		var new_speed: float = current_speed
		# Player hitting the gas, or CPU (which always hits gas).
		var f: Vector2 = Vector2.ZERO
		if moveable:
			if (type == CarType.PLAYER and go_pressed) or type == CarType.CPU:
				if new_speed < max_speed * max_speed_modifier * smoulder_speed_limiter:
					new_speed += acceleration * acceleration_modifier * delta
			# Player hitting the brakes?
			elif (type == CarType.PLAYER and stop_pressed):
				if new_speed > 0: new_speed -= brakes * delta
				elif new_speed < 0: new_speed += brakes * delta
				# To avoid "quivering"
				if abs(new_speed) < brakes * delta: new_speed = current_speed * 0.5
			# Player backing up?
			elif (type == CarType.PLAYER and reverse_pressed):
				if new_speed > -max_speed * max_speed_modifier * smoulder_speed_limiter:
					new_speed -= acceleration * acceleration_modifier * delta
			# Slow down from air drag.
			#else:
			if true:
				if new_speed > 0: new_speed -= deceleration * smoulder_drag * delta
				elif new_speed < 0: new_speed += deceleration * smoulder_drag * delta
				# To avoid "quivering"
				if abs(new_speed) < deceleration * delta: new_speed = current_speed * 0.5
			# Keep track of fastest wheel, the speed will be used for other things
			# further down.
			if abs(new_speed) > fastest_wheel_speed:
				fastest_wheel_speed = abs(new_speed)
			# Calculate the force to apply to get the wheel to the new speed.
			f = mass/4.0 * (new_speed-current_speed) / delta * wheel_direction
		
		# Apply friction force orthogonal to wheel direction.
		current_speed = wheel_velocity.dot(wheel_orthogonal_direction)
		var mag: float = mass/4.0 * current_speed/delta
		# Dampen the magnitude so it's not a completely sudden stop in a single timestep.
		# That would case some weird glitching.
		mag *= 0.5
		# Combine static friction force and force of motion from engine.
		f += mag * -wheel_orthogonal_direction

		#######################################################
		# Skid marks / special effects for wheel.
		#######################################################
		# Get wheel special effects.
		# Check if car is currently in a nail polish puddle.
		# If it is, check which wheels are in the puddle.
		var t: float = Time.get_ticks_msec()
		if EffectType.NAILPOLISHED in effects:
			for np in effects[EffectType.NAILPOLISHED].values():
				var pos: Vector2 = np[0]
				var rad: float = np[1]
				var c: Color = np[2]
				if (wheel.global_position-pos).length() <= rad:
					wheel_effects[w][EffectType.NAILPOLISHED] = [c,t]
		# Clear out old wheel effects.
		if EffectType.NAILPOLISHED in wheel_effects[w]:
			# Nail polish wears off after 1 second.
			var expire: float = wheel_effects[w][EffectType.NAILPOLISHED][1]+1000.0
			if t >= expire:
				wheel_effects[w].erase(EffectType.NAILPOLISHED)
				
		# Limit the static friction force magnitude.
		# First, get auxiliary data about the ground surface.
		var friction: float = 1.0
		var skidmark_colour: Color = Color.TRANSPARENT
		var particle_colour_1: Color = Color.TRANSPARENT
		var particle_colour_2: Color = Color.TRANSPARENT
		var dust_colour: Color = Color.TRANSPARENT
		var wheel_sinking: bool
		var skid_sound: int
		for tilesource in _tilesets:
			if tilesource == null: continue
			var tilepos: Vector2i = tilesource.local_to_map(wheel.global_position/tilesource.scale.x)
			var tiledata: TileData = tilesource.get_cell_tile_data(tilepos)
			if tiledata == null: continue
			if tiledata.get_custom_data("has_skidmarks"):
				# Handle tiles that only give partial coverage.
				if tiledata.get_custom_data("is_partial"):
					var partial_type: int = tiledata.get_custom_data("partial_type")
					var dx: float = tilesource.tile_set.tile_size.x * tilesource.scale.x
					var origin: Vector2
					# 1,2,3,4 = quarter circles
					if partial_type == 1:
						origin = (tilesource.map_to_local(tilepos)) * tilesource.scale.x + Vector2(dx/2,dx/2)
					if partial_type == 2:
						origin = (tilesource.map_to_local(tilepos)) * tilesource.scale.x + Vector2(-dx/2,dx/2)
					if partial_type == 3:
						origin = (tilesource.map_to_local(tilepos)) * tilesource.scale.x + Vector2(dx/2,-dx/2)
					if partial_type == 4:
						origin = (tilesource.map_to_local(tilepos)) * tilesource.scale.x + Vector2(-dx/2,-dx/2)
					if (wheel.global_position - origin).length() > dx:
						continue
				skidmark_colour = tiledata.get_custom_data("skidmark_colour")
			if tiledata.get_custom_data("has_particles"):
				particle_colour_1 = tiledata.get_custom_data("particle_colour_1")
				particle_colour_2 = tiledata.get_custom_data("particle_colour_2")
			else:
				# Turn off particles if layer on top doesn't have them.
				# E.g., paved road on top of grass tile.
				particle_colour_1 = Color.TRANSPARENT
				particle_colour_2 = Color.TRANSPARENT
			if tiledata.get_custom_data("is_dusty"):
				dust_colour = tiledata.get_custom_data("dust_colour")
			else:
				dust_colour = Color.TRANSPARENT
			skid_sound = tiledata.get_custom_data("skid_sound")
			friction = tiledata.get_custom_data("friction")
			# Check if wheel is in water.
			if tiledata.get_custom_data("is_water"):
				wheel_sinking = true
			else:
				wheel_sinking = false
		# Special effects override the tile skidmarks and friction.
		if EffectType.NAILPOLISHED in wheel_effects[w]:
			skidmark_colour = wheel_effects[w][EffectType.NAILPOLISHED][0]
			if w%2 == 1: friction = 0
			else: friction = -0.3
		# Add skid marks and particle effects.
		var max_static_friction = mass*acceleration*friction*friction_modifier*collision_friction_modifier
		var p1: CPUParticles2D = wheel.get_node("Particles1")
		var p2: CPUParticles2D = wheel.get_node("Particles2")
		var dust: CPUParticles2D = wheel.get_node("Dust")
		if f.length() > max_static_friction:
			f = f.limit_length(max_static_friction)
			if skidmark_colour != Color.TRANSPARENT:
				skidding = true
				if wheel_skidmarks[w] == null or wheel_skidmarks[w].default_color != skidmark_colour:
					wheel_skidmarks[w] = load("res://cars/skid_mark.tscn").instantiate()
					wheel_skidmarks[w].default_color = skidmark_colour
					add_sibling(wheel_skidmarks[w])
					wheel_skidmarks[w].z_index = 1
				wheel_skidmarks[w].add_point(wheel.global_position)
			else:
				wheel_skidmarks[w] = null
			if particle_colour_1 != Color.TRANSPARENT:
				p1.color = particle_colour_1
				p1.emitting = true
			else:
				p1.emitting = false
			if particle_colour_2 != Color.TRANSPARENT:
				p2.color = particle_colour_2
				p2.emitting = true
			else:
				p2.emitting = false
			if dust_colour != Color.TRANSPARENT:
				dust.color_ramp.colors[0] = dust_colour
				dust.color_ramp.colors[1] = dust_colour
				dust.color_ramp.colors[0].a = 0.1
				dust.color_ramp.colors[1].a = 0.0
				dust.emitting = true
			else:
				dust.emitting = false
		else:
			wheel_skidmarks[w] = null
			p1.emitting = false
			p2.emitting = false
			dust.emitting = false

		if not wheel_sinking:
			sinking = false  # car not sinking if any wheel is on solid ground.

		apply_force(f, wheel.position.rotated(rotation))

		skid_sounds[skid_sound] = true

	if skidding and skid_sounds[1]:
		if not $TireSquealSound.playing:
			$TireSquealSound.play(2.0)
	if skidding and skid_sounds[2]:
		if not $GravelSound.playing:
			$GravelSound.play()
	if not skidding or not skid_sounds[1]:
		if $TireSquealSound.playing:
			$TireSquealSound.stop()
	if not skidding or not skid_sounds[2]:
		if $GravelSound.playing:
			$GravelSound.stop()

	if sinking:
		_kersplash()

	#######################################################
	# Zoom out camera the faster the car is going.
	#######################################################
	var z: float = 2.0 / (1 + 2*fastest_wheel_speed / max_speed)
	var zoom_limit: float = 0.1 * delta
	if z < $Camera2D.zoom.x:
		$Camera2D.zoom.x = z
		$Camera2D.zoom.y = z
	# When car slowing down, zoom back in.
	# But limit speed of zoom to avoid issues when speed suddenly drops.
	elif z-zoom_limit > $Camera2D.zoom.x:
		$Camera2D.zoom.x += zoom_limit
		$Camera2D.zoom.y += zoom_limit
	else:
		$Camera2D.zoom.x = z
		$Camera2D.zoom.y = z
		

	#######################################################
	# Engine sound
	#######################################################
	if fastest_wheel_speed <= 0.05 * max_speed:
		$EngineSound.pitch_scale = 0.5
	else:
		$EngineSound.pitch_scale = 1 + fastest_wheel_speed / max_speed

func _on_body_entered(_body: Node) -> void:
	if _crashing: return  # Only play sound once during a crashing period.
	_crash_effect()
	_crashing = true

func _crash_effect(stun_duration: float = 1.0) -> void:
	$CrashSound.play()
	$CrashSoundTimer.start()
	var tween: Tween = create_tween()
	collision_friction_modifier = 0.0
	tween.tween_property(self, "collision_friction_modifier", 1.0, stun_duration)

func _on_crash_sound_timer_timeout() -> void:
	_crashing = false

# Make car splash into water
func _kersplash () -> void:
	# Only run this once when sinking, not on every tick.
	if _splashing: return
	_splashing = true
	# Stop car from moving any further during this sequence.
	freeze = true
	# Car not moveable (turns off other skidding / particle effects from friction).
	moveable = false
	# Start showing ripple of water when car is sinking.
	# Also fade the car into the water.
	$Splash.global_rotation = 0
	$Splash/Ripple.show()
	var dr: float = 0.20
	var tween: Tween = create_tween()
	var start: PackedFloat32Array = PackedFloat32Array([0,1-2*dr,1-dr,1,1])
	var almost: PackedFloat32Array = PackedFloat32Array([0,0,dr,2*dr,1])
	var finish: PackedFloat32Array = PackedFloat32Array([0,0,0,dr,1])
	$Splash/Ripple/Dark.texture.gradient.offsets = start
	$Splash/Ripple/Light.texture.gradient.offsets = start
	var dt: float = 0.3
	tween.tween_property($Splash/Ripple/Dark.texture.gradient, "offsets", almost, dt)
	tween.parallel().tween_property($Splash/Ripple/Light.texture.gradient, "offsets", almost, dt)
	var modulated_stuff: Array = [$Body, $Wheels/FrontLeft/Sprite2D, $Wheels/FrontRight/Sprite2D, $Wheels/RearLeft/Sprite2D, $Wheels/RearRight/Sprite2D]
	for m in modulated_stuff:
		tween.parallel().tween_property(m, "modulate", Color.hex(0x00000000), dt)
	# Start playing splashing sound as well.
	$Splash/SplashSound.play(0.3)
	await tween.finished
	# Near end of inward convergence of water, show spray of water particles.
	$Splash/Particles.emitting = true
	tween = create_tween()
	tween.tween_property($Splash/Ripple/Dark.texture.gradient, "offsets", finish, dt*dr*2)
	tween.parallel().tween_property($Splash/Ripple/Light.texture.gradient, "offsets", finish, dt*dr*2)
	tween.parallel().tween_property($Splash/Ripple/Dark, "modulate", Color.TRANSPARENT, dt*dr*2)
	tween.parallel().tween_property($Splash/Ripple/Light, "modulate", Color.TRANSPARENT, dt*dr*2)
	await tween.finished
	$Splash/Ripple.hide()
	$Splash/Particles.emitting = false
	# Move car back onto the road.
	_move_to_road ()
	# Cut off sound before second splash in the .wav file.
	await get_tree().create_timer(1.0).timeout
	$Splash/SplashSound.stop()
	# Restore visibility of car, and make mobile again.
	for m in modulated_stuff:
		m.modulate = Color.WHITE
	$Splash/Ripple/Dark.modulate = Color.WHITE
	$Splash/Ripple/Light.modulate = Color.WHITE
	freeze = false
	moveable = true
	# Done
	_splashing = false

func _move_to_road () -> void:
	freeze = true # Rigid bodies don't like being relocated when they're undergoing physics.
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "global_position", _pathfollow.global_position, 1.0)
	await tween.finished
	global_rotation = (_pathfollow.global_position - _old_path_pos).angle() - PI/2
	freeze = false

func get_slimed (delay: float, full_slime_duration: float, end: float) -> void:
	# Wait a bit for Mango to spit the slime (same timing as screen slime).
	await get_tree().create_timer(delay).timeout
	var slime: Sprite2D = $Slimed/Slime
	slime.modulate = Color.hex(0xffffffcc)
	slime.show()
	# Player will already heaar the splat sound from the screen effect, so skip it here.
	if type == CarType.CPU:
		$Slimed/SplatSound.play()
	$Slimed/CPUParticles2D.emitting = true
	effects[EffectType.SLIMED] = true
	var slimefade: Tween = create_tween()
	slimefade.set_ease(Tween.EASE_OUT)
	slimefade.tween_interval(full_slime_duration)
	slimefade.tween_property(slime, "modulate", Color.hex(0xffffff00), end)
	await slimefade.finished
	effects.erase(EffectType.SLIMED)
	slime.hide()

func entered_nailpolish (obj: Node2D, nailpolish_position: Vector2, radius: float, colour: Color) -> void:
	if EffectType.NAILPOLISHED not in effects:
		effects[EffectType.NAILPOLISHED] = {}
	var np: Dictionary = effects[EffectType.NAILPOLISHED]
	np[obj] = [nailpolish_position, radius, colour]

func exited_nailpolish (obj: Node2D) -> void:
	if EffectType.NAILPOLISHED not in effects: return
	effects[EffectType.NAILPOLISHED].erase(obj)

func sip_coffee () -> void:
	$Coffee/SippingSound.play()
	effects[EffectType.CAFFEINATED] = Time.get_ticks_msec()
	$Coffee/CPUParticles2D.emitting = true

func space_rock () -> void:
	#meteor_impact.emit()
	#return
	var shadow: TextureRect = $Meteor/Shadow
	shadow.show()
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	shadow.scale = Vector2(0.1,0.1)
	shadow.position = Vector2(-5,-5)
	shadow.modulate = Color.hex(0x00000000)
	tween.tween_property(shadow, "scale", Vector2(10.0,10.0), 2.0)
	tween.parallel().tween_property(shadow, "position", Vector2(-500,-500),2.0)
	tween.parallel().tween_property(shadow, "modulate", Color.hex(0xffffffaa), 2.0)
	$Meteor/WhooshSound.play()
	await tween.finished
	shadow.hide()
	meteor_impact.emit()

func smoulder () -> void:
	effects[EffectType.SMOULDERING] = Time.get_ticks_msec()
	$Meteor/CPUParticles2D.emitting = true
