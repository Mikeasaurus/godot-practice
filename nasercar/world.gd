extends Node2D

# Player car
@onready var player_car = $Cars/NaserCar

# Current game state (for applied effects, etc.)

# Indicates that people are already slimed right now, or at least that someone
# has possession of the slime item.
var _sliming: bool = false
# Indicates that someone already has possession of the meteor.
var _meteor: bool = false

# Keep track of which cars are carrying which items.
var _current_items: Dictionary = {}

# Helper method - get all cars in this track.
# Omits other non-car entities that the cars may spawn as siblings.
func _cars () -> Array[Car]:
	var cars: Array[Car] = []
	for car in $Cars.get_children():
		if "CarType" in car:
			cars.append(car)
	return cars
# Helper method - get all cars in front of the specified car.
func _cars_in_front_of (car: Car) -> Array[Car]:
	var cars: Array[Car] = []
	for other_car in _cars():
		if other_car._pathfollow.progress > car._pathfollow.progress:
			cars.append(other_car)
	return cars

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for car in _cars():
		car.add_to_track($TrackPath, $Ground, $Road)
		car.itemblock.connect(func():
			_itemblock(car)
		)
	player_car.make_playable()

	for car in _cars():
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
	for car in _cars():
		car.go()
	var go: Tween = create_tween()
	go.tween_property($CanvasLayer/GoLabel,"modulate",Color.TRANSPARENT,1.0)
	go.parallel().tween_property($CanvasLayer/GoLabel,"scale",Vector2(20,20),1.0)
	go.parallel().tween_property($CanvasLayer/GoLabel,"position", Vector2(400,1),1.0)
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

# All available item types.
enum ItemType {NONE,SLIME}
# Map the item types to the visual representations.
@onready var item_pics: Dictionary = {
	ItemType.SLIME: $ItemSelect/CenterContainer/ScrollContainer/VBoxContainer/MangoSlime,
}

func _itemblock (car: Car) -> void:
	if car not in _current_items:
		_get_item(car)
	

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("use_item"):
		_use_item(player_car)
	if event.is_action_pressed("slime_test"):
		#_slime_screen()
		for car in _cars_in_front_of(player_car):
			car._get_slimed(0.7+0.4, 4.0, 2.0)

func _get_item(car) -> void:
	# First, select an item.
	# Put stub entry for this car, to prevent getting another item.
	_current_items[car] = ItemType.NONE
	var item: ItemType = ItemType.SLIME
	#TODO: remove this hard-coded selection of Mango slime.
	_sliming = true
	# If this is player, then spin to this item.
	if car.type == car.CarType.PLAYER:
		# Move item picture to the last entry.
		$ItemSelect/CenterContainer/ScrollContainer/VBoxContainer.move_child(item_pics[item],-1)
		$ItemSelect.show()
		$ItemSelect/CenterContainer/ScrollContainer.scroll_vertical = 0
		$ItemSelect/D20Sound.play()
		var tween: Tween = create_tween()
		tween.tween_interval(0.4)
		tween.set_ease(Tween.EASE_IN)
		tween.tween_property($ItemSelect/CenterContainer/ScrollContainer,"scroll_vertical",5*256+20,0.75)
		await tween.finished
	else:
		await get_tree().create_timer(2.0).timeout
	_current_items[car] = item

func _use_item(car: Car) -> void:
	if car not in _current_items: return
	var item: ItemType = _current_items.get(car)
	if item == ItemType.NONE: return  # Item not available yet.
	_current_items.erase(car)
	if car.type == car.CarType.PLAYER:
		$ItemSelect/WhooshSound.play()
		var tween: Tween = create_tween()
		tween.tween_property($ItemSelect/CenterContainer,"scale",Vector2(1.0,1.0),0.2)
		tween.parallel().tween_property($ItemSelect/CenterContainer,"modulate",Color.hex(0xffffff00),0.2)
		await tween.finished
		$ItemSelect.hide()
		$ItemSelect/CenterContainer.scale = Vector2(0.5,0.5)
		$ItemSelect/CenterContainer.modulate = Color.WHITE
	if item == ItemType.SLIME:
		for c in _cars_in_front_of(car):
			c._get_slimed(0.7+0.4, 4.0, 2.0)
			if c.type == c.CarType.PLAYER:
				_slime_screen()

func _slime_screen() -> void:
	$ScreenEffects/MangoSlime.show()
	var mango: AnimatedSprite2D = $ScreenEffects/MangoSlime/Mango
	mango.offset.y = 0
	mango.scale.y = 9
	var mangotween: Tween = create_tween()
	mangotween.set_ease(Tween.EASE_IN)
	mangotween.tween_property(mango, "offset", Vector2(0,-108), 0.5)
	mangotween.tween_interval(0.2)
	#tween.tween_property(mango, "scale", Vector2(9,10), 0.0)
	mangotween.tween_interval(0.4)
	#tween.tween_property(mango, "scale", Vector2(9,9), 0.0)
	mangotween.tween_interval(0.2)
	mangotween.set_ease(Tween.EASE_OUT)
	mangotween.tween_property(mango, "offset", Vector2(0,0), 0.3)
	await get_tree().create_timer(0.7).timeout
	mango.animation = "mouth_open"
	$ScreenEffects/MangoSlime/CPUParticles2D.emitting = true
	$ScreenEffects/MangoSlime/HorkSound.play()
	await get_tree().create_timer(0.4).timeout
	$ScreenEffects/MangoSlime/SplatSound.play()
	var slime: AnimatedSprite2D = $ScreenEffects/MangoSlime/Slime
	slime.show()
	slime.play()
	mango.animation = "default"
	#await mangotween.finished
	#slime.hide()
	var slimedrip: Tween = create_tween()
	slimedrip.set_ease(Tween.EASE_OUT)
	var slimefade: Tween = create_tween()
	slimefade.set_ease(Tween.EASE_OUT)
	slimedrip.tween_property(slime, "scale", Vector2(10,50), 6.0)
	slimefade.tween_interval(4.0)
	slimefade.tween_property(slime, "modulate", Color.hex(0xffffff00), 2.0)
	await slimefade.finished
	if slimedrip.is_running():
		await slimedrip.finished
	slime.hide()
	slime.scale.y = 10
	slime.modulate = Color.WHITE
	$ScreenEffects/MangoSlime.hide()
