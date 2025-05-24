extends Line2D

class_name SkidMark

# Whether to start cleaning up old skidmarks (after a fixed time).
var _cleanup: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	default_color = Color.hex(0x00000044)
	$CleanupTimer.start()

# Add a point to the skid mark.
func add_skid (point: Vector2) -> void:
	add_point(point)

func _process(_delta: float) -> void:
	if _cleanup:
		if get_point_count() > 0:
			remove_point(0)
		else:
			queue_free()

func _on_cleanup_timer_timeout() -> void:
	_cleanup = true
