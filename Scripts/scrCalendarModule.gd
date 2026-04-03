extends Node # Cambiado de RefCounted a Node para señales
class_name CalendarModule

# --- SEÑALES PARA EL MAIN ---
signal tick_passed(total_ticks)
signal day_ended

# --- TUS CONSTANTES DE CLIMA (Se mantienen igual) ---
const SEASON_RATIO = {"Spring": [15.0, 25.0], "Summer": [25.0, 32.0], "Autumn": [10.0, 22.0], "Winter": [-5.0, 10.0]}
const OFFSETS_SKY = {"Soleado": 3.0, "Lightly Cloudy": 1.0, "Cloudy": -2.0, "Stormy": -4.5}
const OFFSETS_PRECIPITATION = {"None": 0.0, "Drizzle": -1.5, "Rain": -3.5, "Snow": -6.0}
const ICONS = {"Soleado": "☀️", "Lightly Cloudy": "🌤️", "Cloudy": "☁️", "Stormy": "⛈️", "Drizzle": "🌦️", "Rain": "🌧️", "Snow": "❄️"}
const PROB_PRECIPITATION = {
	"Spring": {"Drizzle": 30, "Rain": 10, "None": 60}, "Summer": {"Drizzle": 10, "Rain": 5, "None": 85},
	"Autumn": {"Drizzle": 20, "Rain": 40, "None": 40}, "Winter": {"Snow": 50, "Drizzle": 10, "None": 40}
}
const PROB_SKY = {"None": {"Soleado": 60, "Lightly Cloudy": 30, "Cloudy": 10}, "Drizzle": {"Lightly Cloudy": 40, "Cloudy": 60}, "Rain": {"Cloudy": 70, "Stormy": 30}, "Snow": {"Cloudy": 90, "Stormy": 10}}

# --- DICCIONARIO DE PROBABILIDADES (Trasplantado del Main) ---
var calendar_probability = {
	1: {"Pedestrian": 0.94, "Farmer": 0.02, "Fisher": 0.02, "Miner": 0.02},
	2: {"Pedestrian": 0.2, "Farmer": 0.94, "Fisher": 0.02, "Miner": 0.02},
	3: {"Pedestrian": 0.45, "Farmer": 0.45, "Fisher": 0.05, "Miner": 0.05},
	4: {"Pedestrian": 0.05, "Farmer": 0.45, "Fisher": 0.45, "Miner": 0.05},
	5: {"Pedestrian": 0.05, "Farmer": 0.05, "Fisher": 0.45, "Miner": 0.45},
	6: {"Pedestrian": 0.075, "Farmer": 0.075, "Fisher": 0.05, "Miner": 0.98},
	7: {"Miner": 0.1, "Farmer": 0.1, "Fisher": 0.1, "Sumo": 0.60, "Pedestrian": 0.1},
	8: {"Miner": 0.015, "Farmer": 0.015, "Fisher": 0.75, "Sumo": 0.005, "Pedestrian": 0.015},
	9: {"Miner": 0.33, "Farmer": 0.01, "Fisher": 0.33, "Sumo": 0.33, "Pedestrian": 0.01},
	"default": {"Pedestrian": 0.2, "Farmer": 0.2, "Fisher": 0.2, "Miner": 0.2, "Sumo": 0.2}
}

# --- STATE VARs ---
var current_tick: int = 360
var day_base_temp: float = 0.0
var SKY: String = "Soleado"
var PRECIPITATION: String = "None"

# --- LÓGICA DE TIEMPO (NUEVA) ---
func advance_tick():
	current_tick += 1
	emit_signal("tick_passed", current_tick)
	
	if current_tick >= 1440:
		current_tick = 0
		emit_signal("day_ended")

func get_config_for_day(p_day: int) -> Dictionary:
	return calendar_probability.get(p_day, calendar_probability["default"])

# --- TUS FUNCIONES DE CLIMA (Se mantienen igual) ---
func generate_new_weather(p_season: String):
	var options_p = PROB_PRECIPITATION.get(p_season, PROB_PRECIPITATION["Spring"])
	PRECIPITATION = choose_by_weight(options_p)
	var options_c = PROB_SKY.get(PRECIPITATION, PROB_SKY["None"])
	SKY = choose_by_weight(options_c)
	var temp_ratio = SEASON_RATIO.get(p_season, [15.0, 25.0])
	day_base_temp = temp_ratio[0] + (temp_ratio[1] - temp_ratio[0]) * randf()

func get_current_temperature(ticks: int) -> float:
	var current_hour = ticks / 60.0
	var time_factor = clamp((remap(current_hour, 6, 15, 0.7, 1.1) if current_hour >= 6 and current_hour <= 15 else remap(current_hour if current_hour >= 15 else current_hour + 24, 15, 30, 1.1, 0.6)), 0.6, 1.1)
	return (day_base_temp * time_factor) + OFFSETS_SKY[SKY] + OFFSETS_PRECIPITATION[PRECIPITATION]

func get_weather_emojis() -> String:
	return ICONS.get(PRECIPITATION if PRECIPITATION != "None" else SKY, "❓")

func choose_by_weight(options: Dictionary) -> String:
	var total = 0
	for v in options.values(): total += v
	var r = randi() % total
	var acc = 0
	for k in options.keys():
		acc += options[k]
		if r < acc: return k
	return options.keys()[0]
