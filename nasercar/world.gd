extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for car in $Cars.get_children():
		car.add_to_track($TrackPath, $Ground, $Road)
		car.itemblock.connect(func():
			_itemblock(car)
		)
	$Cars/NaserCar.make_playable()

	for car in $Cars.get_children():
		if car.type != car.CarType.PLAYER:
			car.make_cpu()

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
	go.parallel().tween_property($CanvasLayer/GoLabel,"position", Vector2(400,1),1.0)
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

# Indicate if player already has an item or is getting an item.
# So if they touch another item block while holding an item, nothing new happens.
var _has_item: bool = false
# Description of item
enum ItemType {SLIME}

func _itemblock (car: Node2D) -> void:
	if car.type == car.CarType.PLAYER and not _has_item:
		_get_item()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("use_item") and _has_item:
		_use_item()

func _get_item() -> void:
	if _has_item: return
	_has_item = true
	$ItemSelect.show()
	$ItemSelect/CenterContainer/ScrollContainer.scroll_vertical = 0
	$ItemSelect/D20Sound.play()
	var tween: Tween = create_tween()
	tween.tween_interval(0.4)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property($ItemSelect/CenterContainer/ScrollContainer,"scroll_vertical",5*256,0.75)

func _use_item() -> void:
	if not _has_item: return
	$ItemSelect/WhooshSound.play()
	var tween: Tween = create_tween()
	tween.tween_property($ItemSelect/CenterContainer,"scale",Vector2(1.0,1.0),0.2)
	tween.parallel().tween_property($ItemSelect/CenterContainer,"modulate",Color.hex(0xffffff00),0.2)
	await tween.finished
	_has_item = false
	$ItemSelect.hide()
	$ItemSelect/CenterContainer.scale = Vector2(0.5,0.5)
	$ItemSelect/CenterContainer.modulate = Color.WHITE
