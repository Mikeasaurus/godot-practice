extends RigidBody2D

@export var resync: bool
@export var synced_position: Vector2
@export var synced_velocity: Vector2
@export var synced_rotation: float
@export var synced_angular_velocity: float

func _integrate_forces(_state: PhysicsDirectBodyState2D) -> void:
	if not Globals.is_server and not Globals.is_client: return
	if Globals.is_server:
		synced_position = global_position
		synced_velocity = linear_velocity
		synced_rotation = rotation
		synced_angular_velocity = angular_velocity
		resync = true
	elif resync:
		global_position = synced_position
		linear_velocity = synced_velocity
		rotation = synced_rotation
		angular_velocity = synced_angular_velocity
		resync = false
