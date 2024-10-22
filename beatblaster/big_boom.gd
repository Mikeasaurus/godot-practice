extends Sprite2D
var original_scale
var expansion

func _ready():
	original_scale = scale
	expansion = 1.0

func _process(delta):
	expansion += 10.0 * delta
	if expansion >= 20.0:
		queue_free()
	else:
		set_deferred("scale", original_scale * expansion)
