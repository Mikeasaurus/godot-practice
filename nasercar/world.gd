extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Cars/NaserCar.make_playable()
	$Cars/FangCar.make_cpu($TrackPath)
	$Cars/NaomiCar.make_cpu($TrackPath)
	$Cars/StellaCar.make_cpu($TrackPath)
	$Cars/TrishCar.make_cpu($TrackPath)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
