# WeatherScene.gd
# Self-contained weather display using Open-Meteo (no API key required)
# Shows temperature, sunny/cloudy icons, and rain icon for a US ZIP code
extends Node2D

export(String) var zip_code

onready var http_request = $HTTPRequest

# UI nodes
onready var temperature_label = $TemperatureLabel
onready var sun_icon = $SunIcon
onready var cloud_icon = $CloudIcon
onready var rain_icon = $RainIcon

# Tracking for chained requests
var current_request_type: String = ""   # "geocode" or "weather"
var current_zip: String = ""

# Signals (optional)
signal weather_updated(zip, temp_f, is_raining, is_sunny, sky_condition)
signal weather_error(zip, message)

func _ready():
	http_request.connect("request_completed", self, "_on_request_completed")
	
	# Hide all icons initially
	if sun_icon: sun_icon.visible = false
	if cloud_icon: cloud_icon.visible = false
	if rain_icon: rain_icon.visible = false
	if temperature_label: temperature_label.text = "-- °F"
	
	# Auto-fetch on scene load (change ZIP as desired)
	_on_Timer_timeout()
#	fetch_weather("27312")  # Pittsboro, NC

# Call this function to fetch weather for any ZIP code
func fetch_weather(zip_code: String) -> void:
	if zip_code.empty():
		_handle_error(zip_code, "Zip code cannot be empty")
		return
	
	var clean_zip = zip_code.strip_edges()
	current_zip = clean_zip
	
	# Step 1: Geocode ZIP to lat/lon
	var geocode_url = "https://geocoding-api.open-meteo.com/v1/search?name=" + clean_zip + "&count=1&format=json"
	
	var headers = PoolStringArray([
		"User-Agent: Godot Weather Scene"
	])
	
	var error = http_request.request(geocode_url, headers, true, HTTPClient.METHOD_GET)
	if error != OK:
		_handle_error(clean_zip, "Geocode request failed (err " + str(error) + ")")
		return
	
	current_request_type = "geocode"
	print("Geocoding ZIP: ", clean_zip)

func _on_request_completed(result, response_code, headers, body):
	if current_request_type.empty():
		return
	
	var zip = current_zip
	
	if current_request_type == "geocode":
		current_request_type = ""
		
		if response_code != 200:
			_handle_error(zip, "Geocode HTTP " + str(response_code))
			return
		
		var json_string = body.get_string_from_utf8()
		var parse_result = JSON.parse(json_string)
		if parse_result.error != OK:
			_handle_error(zip, "Geocode JSON error: " + parse_result.error_string)
			return
		
		var data = parse_result.result
		if not data.has("results") or data.results.empty():
			_handle_error(zip, "ZIP not found")
			return
		
		var loc = data.results[0]
		var lat = str(loc.latitude)
		var lon = str(loc.longitude)
		
		# Step 2: Fetch current weather
		var weather_url = (
			"https://api.open-meteo.com/v1/forecast?" +
			"latitude=" + lat +
			"&longitude=" + lon +
			"&current=temperature_2m,rain,precipitation,weather_code,cloud_cover" +
			"&temperature_unit=fahrenheit" +
			"&timezone=America/New_York"
		)
		
		var error = http_request.request(weather_url, PoolStringArray(["User-Agent: Godot Weather Scene"]), true, HTTPClient.METHOD_GET)
		if error != OK:
			_handle_error(zip, "Weather request failed (err " + str(error) + ")")
			return
		
		current_request_type = "weather"
		print("Fetching weather for ", zip, " at ", lat, ",", lon)
	
	elif current_request_type == "weather":
		current_request_type = ""
		current_zip = ""
		
		if response_code != 200:
			_handle_error(zip, "Weather HTTP " + str(response_code))
			return
		
		var json_string = body.get_string_from_utf8()
		var parse_result = JSON.parse(json_string)
		if parse_result.error != OK:
			_handle_error(zip, "Weather JSON error: " + parse_result.error_string)
			return
		
		var data = parse_result.result
		if not data.has("current"):
			_handle_error(zip, "No current weather data")
			return
		
		var current = data.current
		var temp_f: float = current.temperature_2m
		var rain_mm: float = current.get("rain", 0.0)
		var precip_mm: float = current.get("precipitation", 0.0)
		var wmo_code: int = current.get("weather_code", 0)
		var cloud_pct: int = current.get("cloud_cover", 0)
		
		# Rain detection
		var is_raining = (
			rain_mm > 0.0 or
			precip_mm > 0.0 and wmo_code in [51,53,55,56,57,61,63,65,66,67,80,81,82]
		)

		# Sky condition logic
		var sky_condition: String = "Unknown"
		var is_sunny: bool = false

#		is_raining = true #FOR TESTING
#		wmo_code = 1 #FOR TESTING
		
		match wmo_code:
			0:
				sky_condition = "Sunny"
				is_sunny = true
			1:
				sky_condition = "Mostly Sunny"
				is_sunny = true
			2:
				sky_condition = "Partly Cloudy"
				is_sunny = false
			3:
				sky_condition = "Cloudy"
				is_sunny = false
#			_:
#				# Fallback for rain/fog/etc. using cloud cover
#				if cloud_pct <= 20:
#					sky_condition = "Sunny"
#					is_sunny = true
#				elif cloud_pct <= 50:
#					sky_condition = "Partly Cloudy"
#					is_sunny = false
#				else:
#					sky_condition = "Cloudy"
#					is_sunny = false
		
		# Update UI
		if temperature_label:
			temperature_label.text = "%.1f°F" % temp_f
		
		# Icon visibility logic
		$RainIcon.visible = is_raining
		$SunIcon.visible = is_sunny
		$CloudIcon.visible = not(is_sunny)

		print("Weather for ", zip, ": ", temp_f, "°F | ", sky_condition, 
			  " | Raining: ", is_raining,
			  " (code: ", wmo_code, ", clouds: ", cloud_pct, "%)")
		
		emit_signal("weather_updated", zip, temp_f, is_raining, is_sunny, sky_condition)

func _handle_error(zip: String, msg: String):
	print("Weather error for ", zip, ": ", msg)
	if temperature_label:
		temperature_label.text = "Error"
	if sun_icon: sun_icon.visible = false
	if cloud_icon: cloud_icon.visible = false
	if rain_icon: rain_icon.visible = false
	emit_signal("weather_error", zip, msg)

# Optional: call this from a button or timer to refresh
# func refresh_weather():
#     fetch_weather("27312")


func _on_Timer_timeout():
	fetch_weather(zip_code)  # Pittsboro, NC
