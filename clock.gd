extends Node2D


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func _process(delta):
#	pass
	var timeDict = OS.get_time()
	var hour = timeDict.hour
	var minute = timeDict.minute
	var seconds = timeDict.second
	var angle = seconds/60.0*360.0
	#print ((minute/60.0+seconds/3600.0)*360.0)
	get_node("hourhand").rotation_degrees = (fmod(hour, 12)+minute/60.0)/12.0*360.0
	get_node("minutehand").rotation_degrees = (minute/60.0+seconds/3600.0)*360.0
	#get_node("secondhand").rotation_degrees = (seconds/60.0)*360.0
#	get_node("hourhandshadow").rotation_degrees = (fmod(hour, 12)+minute/60.0)/12.0*360.0
#	get_node("minutehandshadow").rotation_degrees = (minute/60.0+seconds/3600.0)*360.0
