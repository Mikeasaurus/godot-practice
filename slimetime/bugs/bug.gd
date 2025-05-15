extends RigidBody2D

class_name Bug

# Original position of bug.
var starting_position: Vector2

# Whether bug is flying or inactive.
@export var is_slimed: bool = false
# Whether bug is currently stuck to a surface.
@export var is_stuck: bool = false
# Whether bug is eaten.
# Mainly useful for multiplayer mode, to keep the bug in the scene tree but disable it.
@export var is_eaten: bool = false

# Reference for sticking to moving platforms.
var stuck_surface = null
var stuck_offset: Vector2

# Manage multiplayer synchronization of location/position.
# These custom variables will be managed by MultiplayerSynchronizer, and
# they will be connected to the physics via _integrate_forces.
# This will safely sync the position and velocity without physics freaking out.
# See: https://www.reddit.com/r/godot/comments/180ywzs/multiplayersynchronizer_and_rigidbody/
# This should also help with the glitching when "teleporting" rigid bodies to a new location.
@export var synced_position: Vector2
@export var synced_linear_velocity: Vector2
@export var synced_rotation: float
@export var synced_angular_velocity: float
@export var _resync: bool = false
func _sync_properties() -> void:
	if _resync:
		position = synced_position
		linear_velocity = synced_linear_velocity
		rotation = synced_rotation
		angular_velocity = synced_angular_velocity
		_resync = false
		return
	# The rest of this logic is only needed in multiplayer context.
	if not Globals.is_client and not Globals.is_server: return
	if not Globals.is_client:
		synced_position = position
		synced_linear_velocity = linear_velocity
		synced_rotation = rotation
		synced_angular_velocity = angular_velocity
	else:
		position = synced_position
		linear_velocity = synced_linear_velocity
		rotation = synced_rotation
		angular_velocity = synced_angular_velocity
func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	_sync_properties ()
	# Check if a slimed bug is hitting a surface, make splatter effect.
	if is_slimed and state.get_contact_count() > 0:
		var n: Vector2 = state.get_contact_local_normal(0)
		Globals.request_splatter.emit(global_position, n, z_index+1, false)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$AnimatedSprite2D.play()
	starting_position = global_position
	# This fixes a multiplayer glitch where sometimes far away bugs are stuck
	# at (0,0) in a peer's multiplaery instance.
	synced_position = global_position
	# Turn off processing for far away bugs.
	_disable_if_not_visible()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if is_eaten: return  # Don't react eaten bugs with any forces.. they just need to exist somewhere.
	if is_slimed and not freeze:
		apply_central_force(Vector2(0,Globals.gravity))
		return
	if freeze and stuck_surface != null and multiplayer.get_unique_id() == 1:
		position = stuck_surface.global_position + stuck_offset
	# If frozen, _integrate_forces not called.  So need to call sync from here.
	if freeze:
		_sync_properties()

# Change state of the bug so it's in a dormant, slimed state.
func get_slimed () -> void:
	is_slimed = true
	$AnimatedSprite2D.play("slimed")
	# In multiplayer, set a timer to automatically respawn the bug after being slimed for some
	# amount of time... so we don't run out of bugs to play with.
	if Globals.is_server:
		$RespawnTimer.start()
	# Actually, respawn in single player mode too.  So if the player slimes the bug
	# but it lands somewhere inaccessible, it will go back to its usual spot
	# in a minute so the user can try again.
	elif not Globals.is_client:
		$RespawnTimer.start()

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
	if $RespawnTimer.is_stopped():
		$RespawnTimer.start()
# Automatic respaning of bug after getting slimed and/or eaten.
func _on_respawn_timer_timeout() -> void:
	synced_position = starting_position
	synced_linear_velocity = Vector2.ZERO
	synced_rotation = 0
	synced_angular_velocity = 0
	_resync = true
	$AnimatedSprite2D.play("default")
	$CollisionShape2D.set_deferred("disabled",false)
	is_slimed = false
	is_eaten = false
	is_stuck = false
	# Check if bug is visible on screen.
	# For multiplayer server, this is always true (server always needs to "see" everything).
	if Globals.is_server or $VisibleOnScreenNotifier2D.is_on_screen():
		set_deferred("freeze",false)
		set_process(true)
		set_physics_process(true)
	elif not Globals.is_client:
		set_deferred("freeze",true)
		set_process(false)
		set_physics_process(false)
	stuck_surface = null
	visible = true

func _on_body_entered(body: Node) -> void:
	# Only check collisions for server / local game.
	if multiplayer.get_unique_id() != 1: return
	# Check if getting slimed.
	if "get_collision_layer" in body:
		if body.get_collision_layer() == 2 and not is_slimed:
			get_slimed()
		# Check if already slimed, and hitting moving platform.
		elif body.get_collision_layer() == 1 and is_slimed:
			set_deferred("freeze",true)
			stuck_surface = body
			stuck_offset = position - body.global_position
			ground_sound()
			is_stuck = true
	# Otherwise, hitting stationary body.
	else:
		ground_sound()
		is_stuck = true
		# If hitting something solid and already slimed, then stick to the surface.
		set_deferred("freeze",true)
		stuck_surface = null

# Turn off bug movement and processing when it's far enough away.
# Should save some CPU time in single player games.
func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	if not Globals.is_client and not Globals.is_server:
		if not is_slimed:
			freeze = true
			set_process(false)
			set_physics_process(false)
func _on_visible_on_screen_notifier_2d_screen_entered() -> void:
	if not Globals.is_client and not Globals.is_server:
		freeze = is_stuck
		set_process(true)
		set_physics_process(true)
# The above doesn't work for bugs that start off-screen.
# So this function is more brute-force for turning off those sprites at
# the beginning of the game.
# There should be a better way to achieve this???
func _disable_if_not_visible () -> void:
	if not $VisibleOnScreenNotifier2D.is_on_screen():
		_on_visible_on_screen_notifier_2d_screen_exited()

# Play sound when the bug hits a surface.
@rpc("authority","call_local","reliable")
func _ground_sound () -> void:
	$GroundSound.play()
func ground_sound() -> void:
	_ground_sound.rpc()
