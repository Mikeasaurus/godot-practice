extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Cars/NaserCar.make_playable()
	$Cars/NaserCar/Camera2D.limit_top = $Marker2D.position.y
	$Cars/FangCar.make_cpu($TrackPath)
	$Cars/NaomiCar.make_cpu($TrackPath)
	$Cars/StellaCar.make_cpu($TrackPath)
	$Cars/TrishCar.make_cpu($TrackPath)
	$Cars/ReedCar.make_cpu($TrackPath)
	$Cars/SageCar.make_cpu($TrackPath)
	# Start of race.
	$CanvasLayer/FadeIn.show()
	var fadein: Tween = create_tween()
	fadein.tween_property($CanvasLayer/FadeIn, "modulate", Color.TRANSPARENT, 1.0)
	await fadein.finished
	$CanvasLayer/GoLabel.show()
	$CanvasLayer/GoLabel.text = "3"
	$Beep1.play()
	await get_tree().create_timer(1.0).timeout
	$CanvasLayer/GoLabel.text = "2"
	$Beep1.play()
	await get_tree().create_timer(1.0).timeout
	$CanvasLayer/GoLabel.text = "1"
	$Beep1.play()
	await get_tree().create_timer(1.0).timeout
	$CanvasLayer/GoLabel.text = "GO!!!"
	$Beep2.play()
	for car in $Cars.get_children():
		car.go()
	var go: Tween = create_tween()
	go.tween_property($CanvasLayer/GoLabel,"modulate",Color.TRANSPARENT,1.0)
	go.parallel().tween_property($CanvasLayer/GoLabel,"scale",Vector2(20,20),1.0)
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
