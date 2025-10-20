extends Control

func run () -> void:
	show()
	await $MarginContainer/CenterContainer/VBoxContainer/BackButton.pressed
	hide()
