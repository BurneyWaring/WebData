# stock.gd
# Attach this to your root node (e.g. Node2D) in main.tscn
# Requires: HTTPRequest node named "HTTPRequest" as direct child

extends Node2D

export(String) var stock_name #= "PG" See the inspector for this node when you click in the scene window

onready var http_request = $HTTPRequest

# Track what we're currently fetching (since HTTPRequest is single-use async)
var current_symbol: String = ""

# Custom signal – NO type hints allowed in Godot 3.x!
signal price_fetched(symbol, price, signd, chang, change_pct)

func _ready():
	_on_Timer_timeout()
	# Connect HTTPRequest signal
	http_request.connect("request_completed", self, "_on_request_completed")
	
# Generalized function to fetch price for any symbol
# Call it like: fetch_price("PG")
# When data arrives → prints to console + emits signal
func fetch_price(symbol: String) -> void:
	if symbol.empty():
		print("Error: Symbol cannot be empty")
		return
	
	var clean_symbol = symbol.to_upper().strip_edges()
	
	var url = "https://query1.finance.yahoo.com/v8/finance/chart/" + clean_symbol + "?interval=1d&range=1d"
	var headers = PoolStringArray([
		"User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
	])
	
	var error = http_request.request(url, headers)
	if error != OK:
		print("Failed to start HTTP request for ", clean_symbol, " (error code: ", error, ")")
		return
	
	current_symbol = clean_symbol
	print("Fetching price for ", clean_symbol, "...")


# Called automatically when HTTPRequest finishes
func _on_request_completed(result, response_code, headers, body):
	if current_symbol.empty():
		return  # No active request
	
	var symbol = current_symbol
	current_symbol = ""  # Clear it
	
	var price: float = 0.0
	var signd: String = ""
	var chang: float = 0.0
	var change_pct: float = 0.0
	
	if response_code != 200:
		print("HTTP error for ", symbol, ": code ", response_code)
		return
	
	var json_string = body.get_string_from_utf8()
	var parse_result = JSON.parse(json_string)
	
	if parse_result.error != OK:
		print("JSON parse error for ", symbol, ": ", parse_result.error_string)
		return
	
	var data = parse_result.result
	
	if not data.has("chart") or not data.chart.has("result") or data.chart.result.empty():
		print("No valid chart data returned for ", symbol)
		return
	
	var meta = data.chart.result[0].meta
	var current_price = meta.get("regularMarketPrice", 0.0)
	var prev_close    = meta.get("chartPreviousClose", 0.0)
	
	if current_price <= 0 or prev_close <= 0:
		print("Invalid price data for ", symbol, " (current: ", current_price, ", prev: ", prev_close, ")")
		return
	
	var change_val = current_price - prev_close
	var pct = (change_val / prev_close) * 100.0
	
	price     = current_price
	chang     = change_val
	change_pct = pct
	signd     = "+" if change_val >= 0 else "-"
	
	# Print the result to Output console
#	print("--- Price fetched for ", symbol, " ---")
#	print("Current price:    $", "%.2f" % price)
#	print("Change:           ", signd, "%.2f" % chang)
#	print("Change percent:   ", "%.2f" % change_pct, "%")
#	print("Previous close:   $", "%.2f" % prev_close)
#	print("------------------------")
	prints(symbol, price, chang, change_pct, prev_close)
	
	# Emit signal (parameters passed without types)
	emit_signal("price_fetched", symbol, price, signd, chang, change_pct)
	$stock_name.text = symbol
	$stock_price.text = "%.2f" % price
	$stock_change_pct.text = "%.2f" % change_pct + "%"
	if change_pct < 0:
		$stock_change_pct.add_color_override("font_color", Color("#ff0101"))
	else:
		$stock_change_pct.add_color_override("font_color", Color("#1cff02"))
	


# ───────────────────────────────────────────────
# Example button handler functions
# Add Buttons in editor, connect their "pressed" signal to these
# ───────────────────────────────────────────────

func _on_fetch_vt_pressed():
	fetch_price("VT")


func _on_fetch_pg_pressed():
	fetch_price("PG")


func _on_fetch_aapl_pressed():
	fetch_price("AAPL")


func _on_fetch_spy_pressed():
	fetch_price("SPY")



func _on_Button_PG_pressed():
	_on_fetch_pg_pressed()

func _on_fetch_any_pressed(any):
	fetch_price(any)

func _on_Button_VT_pressed():
	_on_fetch_vt_pressed()


func _on_Button_any_pressed():
	var any 
	any = stock_name #"^DJI"
	fetch_price(any)


func _on_Timer_timeout():
	var any 
	any = stock_name #"^DJI"
	fetch_price(any)
