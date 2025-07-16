extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var notracks: Array[TileMapLayer] = []
	$NaserCar.add_to_track($Path2D,notracks)
	$NaserCar.make_cpu()
	_reset_car()
	$CarTimer.start()
	MenuHandler.done_submenus.connect(_reset_car)
	$CarSelection.race.connect(start_race)

func _reset_car() -> void:
	$NaserCar.set_deferred("global_position",Vector2(-53,-75))
	$NaserCar.set_deferred("linear_velocity",Vector2.ZERO)
	$NaserCar.freeze = true
	$NaserCar.show()
	$NaserCar.stop()
	$CarTimer.stop()

func _on_help_pressed() -> void:
	_reset_car()
	MenuHandler.activate_menu($Help)

func _on_single_player_pressed() -> void:
	_reset_car()
	MenuHandler.activate_menu($CarSelection)

func _on_car_timer_timeout() -> void:
	$NaserCar.freeze = false
	$NaserCar.go()

func start_race (player_car: Car) -> void:
	# Turn off menu stuff.
	_reset_car()
	$NaserCar.call_deferred("hide")
	# Load up the race track.
	var race: World = load("res://world.tscn").instantiate()
	# Set up the player car based on the car type chosen.
	# Can't just set player_car as the one we're given - it has to be one of the instantiated
	# scenes in the race.
	for car in race.get_node("Cars").get_children() as Array[Car]:
		if car.display_name == player_car.display_name:
			race.player_car = car
	add_child(race)
	await (race.quit)
	race.queue_free()
	_reset_car()
	$CarTimer.start()
