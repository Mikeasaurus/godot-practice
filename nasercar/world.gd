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
# Helper method - get number of cars behind the specified car.
func _num_cars_behind (car: Car) -> int:
	var num: int = 0
	for other_car in _cars():
		if other_car._pathfollow.progress < car._pathfollow.progress:
			num += 1
	return num


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
enum ItemType {NONE,NAILPOLISH,COFFEE,METEOR,SLIME,BEETLE}
# Map the item types to the visual representations.
@onready var item_pics: Dictionary = {
	ItemType.NAILPOLISH: $ItemSelect/CenterContainer/ScrollContainer/VBoxContainer/NailPolish,
	ItemType.COFFEE: $ItemSelect/CenterContainer/ScrollContainer/VBoxContainer/Coffee,
	ItemType.METEOR: $ItemSelect/CenterContainer/ScrollContainer/VBoxContainer/Meteor,
	ItemType.SLIME: $ItemSelect/CenterContainer/ScrollContainer/VBoxContainer/MangoSlime,
	ItemType.BEETLE: $ItemSelect/CenterContainer/ScrollContainer/VBoxContainer/Beetle,
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
	# Put stub entry for this car, to prevent getting another item while this
	# item is arriving.
	_current_items[car] = ItemType.NONE
	var cars_in_front: Array[Car] = _cars_in_front_of(car)
	# Determine which items are viable selections, and relative probability
	# of occurrence.
	var likelihood: Dictionary = {}
	# Probability of slime increases with number of cars in front.
	# But not available if someone else already has it / is using it.
	if not _sliming:
		if len(cars_in_front) > 0:
			likelihood[ItemType.SLIME] = len(cars_in_front)*10
	# Coffee also becomes more likely the further behind (at least a few cars behind?)
	if len(cars_in_front) >= 3:
		likelihood[ItemType.COFFEE] = len(cars_in_front)*10
	# Similarly, probability of meteor increases with number of cars in front.
	# But relatively less likely overall.
	if not _meteor:
		if len(cars_in_front) > 0:
			likelihood[ItemType.METEOR] = len(cars_in_front)
	# Probability of nail polish increases with number of cars behind.
	var num_cars_behind: int = _num_cars_behind(car)
	if num_cars_behind > 0:
		likelihood[ItemType.NAILPOLISH] = num_cars_behind*10
	# Beetle has equal probability, except for leading car.
	if len(cars_in_front) > 0:
		likelihood[ItemType.BEETLE] = 40
	# Pick an item from these possibilities.
	var sample_size: int = 0
	for n in likelihood.values():
		sample_size += n
	var choice: int = randi() % sample_size
	#print ('?? ', car, ' ', likelihood, ' ', sample_size)
	var item: ItemType
	for item_type in likelihood.keys():
		if choice < likelihood[item_type]:
			item = item_type
			break
		choice -= likelihood[item_type]
	# An item should now be selected.

	# Some item types are exclusive (only one available at a time).
	if item == ItemType.METEOR:
		_meteor = true
	if item == ItemType.SLIME:
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
