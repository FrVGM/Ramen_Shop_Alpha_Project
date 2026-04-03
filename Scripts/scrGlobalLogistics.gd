# GlobalLogistics.gd
extends Node

var menu_of_day: Array[Dictionary] = [] 

# --- AÑADE ESTO ---
var stars_accumulated: float = 0.0
var total_served_customers: int = 0

# En tu Singleton (GlobalLogistics)
var stars_history: Array[float] = []
const MAX_HISTORY = 100 # Guardamos las últimas 100 scores (aprox 2 días de clientes)
# GlobalLogistics.gd
var selected_slot: int = -1 # Memoria temporal

# En GlobalLogistics.gd (o tu Autoload)
var discovered_ingredients: Array[String] = []

var customer_database = {
	"Farmer": preload("res://Customers/common/farmer.tres"),
	"Fisher": preload("res://Customers/common/fisher.tres"),
	"Miner": preload("res://Customers/common/miner.tres"),
	"Pedestrian": preload("res://Customers/common/pedestrian.tres"),
	"Sumo": preload("res://Customers/uncommon/sumo.tres"),
	# ... pon aquí todos los que te falten ...
}

func discover_ingredient(ing_name: String):
	if not ing_name in discovered_ingredients:
		discovered_ingredients.append(ing_name)
		#guardar_progreso_diario() # Opcional: guardar al descubrir

func record_score(score: float):
	stars_history.append(score)
	# Si nos pasamos del límite, borramos la más vieja
	if stars_history.size() > MAX_HISTORY:
		stars_history.pop_front()

func get_current_average() -> float:
	if stars_history.is_empty(): return 0.0
	var total = 0.0
	for n in stars_history:
		total += n
	return total / stars_history.size()

# Añadimos el tercer parámetro opcional con un valor por defecto de -1
func add_to_menu(recipe: RecipeResource, sale_price: int, index_replacement: int = -1) -> bool:
	
	# 1. Lógica de Reemplazo por Slot Específico
	if index_replacement >= 0 and index_replacement < 4:
		# Si el menú no tiene ese tamaño aún, lo rellenamos
		while menu_of_day.size() <= index_replacement:
			menu_of_day.append({"resource": null, "price": 0})
		
		# Guardamos la recipe en el lugar exacto del slot pulsado
		menu_of_day[index_replacement] = {"resource": recipe, "price": sale_price}
		print("Slot ", index_replacement, " upgraded with: ", recipe.recipe_name)
		return true

	# 2. Lógica normal (por si se llama sin índice)
	for i in range(menu_of_day.size()):
		if menu_of_day[i]["resource"] and menu_of_day[i]["resource"].recipe_name == recipe.recipe_name:
			menu_of_day[i]["price"] = sale_price
			return true
	
	# 3. Añadir al final si hay espacio
	if menu_of_day.size() < 4:
		menu_of_day.append({"resource": recipe, "price": sale_price})
		return true
	
	print("Menú lleno y no se especificó slot de reemplazo")
	return false


# En GlobalLogistics.gd
func clean_menu():
	menu_of_day.clear()
	# Opcional: Reiniciar el slot seleccionado para el nuevo día
	selected_slot = -1 
