# main.gd
# Attach this to your root node (e.g. Node2D) in main.tscn
# Requires: HTTPRequest node named "HTTPRequest" as direct child

extends Node2D


func _ready():
	pass

func _input(event):
	if event is InputEventKey and event.pressed and event.scancode == KEY_ESCAPE:
		get_tree().quit()
