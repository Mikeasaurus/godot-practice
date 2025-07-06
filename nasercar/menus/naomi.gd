extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$NaomiCar.add_to_track($Path2D, [] as Array[TileMapLayer])
	$NaomiCar.make_cpu()
	$NaomiCar.go()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
