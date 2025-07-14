extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var notracks: Array[TileMapLayer] = []
	$NaserCar.add_to_track($Path2D,notracks)
	$NaserCar.make_cpu()
	_reset_car()
	MenuHandler.done_submenus.connect(_reset_car)

func _reset_car() -> void:
	$NaserCar.set_deferred("global_position",Vector2(-53,-75))
	$NaserCar.set_deferred("linear_velocity",Vector2.ZERO)
	$NaserCar.freeze = true
	$NaserCar.stop()
	$CarTimer.stop()
	$CarTimer.start()

func _on_help_pressed() -> void:
	_reset_car()
	$CarTimer.stop()
	MenuHandler.activate_menu($Help)

func _on_single_player_pressed() -> void:
	_reset_car()
	$CarTimer.stop()
	MenuHandler.activate_menu($CarSelection)

func _on_car_timer_timeout() -> void:
	$NaserCar.freeze = false
	$NaserCar.go()
