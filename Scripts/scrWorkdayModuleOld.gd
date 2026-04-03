extends Node

# --- Variables de Juego ---
var user_name = "User"
var current_tick = 360
var day = 1
var money: int = 1000
var money_at_start: int = 100
var season = "Spring"

var ramen_menu: Array[Dictionary] = []
var card_references: Dictionary = {} 

# --- Gastos Fijos ---
const daily_rent = 2000 
const chef_percent = 0.30 
const server_percent = 0.15 

var seats_state: Dictionary = {} 

var customer_rate = 10

var first_save = false

var changes_allowed = true

var current_shop_comfort: float = 0.5  # Rango de 0.0 a 1.0 (0.5 es regular/cutre)

var orders_ready_to_serve: Array = [] # Esta lista guardará los platos que el Chef termina

@onready var hover_sound = preload("res://Audio/SFX/MouseEntered.wav")
@onready var click_sound = preload("res://Audio/SFX/MouseClick.wav") 

# --- NUEVO: Base de data de customers (Diccionario que mapea user_names a paths .tres) ---
var customer_database = {
	"Farmer": preload("res://Customers/common/farmer.tres"),
	"Fisher": preload("res://Customers/common/fisher.tres"),
	"Miner": preload("res://Customers/common/miner.tres"),
	"Pedestrian": preload("res://Customers/common/pedestrian.tres"),
	"Sumo": preload("res://Customers/uncommon/sumo.tres"),
	# Añade el resto de tus customers aquí
}

# Modificamos las probabilidades para que ahora apunten a los user_names key del diccionario de arriba
var calendar_probability = {
	1: {
		"Pedestrian": 0.98, # 60% de probabilidad
		"Farmer": 0.01,     # 20%
		"Fisher": 0.05,     # 10%
		"Miner": 0.05,      # 10%
	},
	2: {
		"Pedestrian": 0.1, 
		"Farmer": 0.98,
		"Fisher": 0.05,
		"Miner": 0.05
	},
	3: {
		"Pedestrian": 0.45, 
		"Farmer": 0.45,
		"Fisher": 0.05,
		"Miner": 0.05
	},
	4: {
		"Pedestrian": 0.05, 
		"Farmer": 0.45,
		"Fisher": 0.45,
		"Miner": 0.05
	},
	5: {
		"Pedestrian": 0.05, 
		"Farmer": 0.05,
		"Fisher": 0.45,
		"Miner": 0.45
	},
	6: {
		"Pedestrian": 0.075, 
		"Farmer": 0.075,
		"Fisher": 0.05,
		"Miner": 0.98
	},
	7: {
		"Miner": 0.1,
		"Farmer": 0.1,
		"Fisher": 0.1,
		"Sumo": 0.60,
		"Pedestrian": 0.1,
	},
	8: {
		"Miner": 0.015,
		"Farmer": 0.015,
		"Fisher": 0.75,
		"Sumo": 0.005,
		"Pedestrian": 0.015
	},
	9: {
		"Miner": 0.33,
		"Farmer": 0.01,
		"Fisher": 0.33,
		"Sumo": 0.33,
		"Pedestrian": 0.01
		
	},
	"default": {
		"Pedestrian": 0.2,
		"Farmer": 0.2,
		"Fisher": 0.2,
		"Miner": 0.2,
		"Sumo": 0.2
	}
}

var tutorial_completed: bool = false

var total_served_customers = 0 
var total_stars = 0.0
var quality_chef_bonus = 1.0 # Este bono debería provenir de la habilidad del chef NPC

var weather = CalendarModule.new() # Asumo que CalendarModule existe
var current_temp: float = 0.0
var delete_timer: Tween

@onready var hboxRecipeSlots = $UI/HBoxContainer
var recipe_card_scene = preload("res://Scenes/scnRecipeCard.tscn")

var wait_line: Array = [] # Añade esto arriba del todo
var customers_on_street: Array = []

const scnRECIPE = preload("res://Scenes/scnRecipeBook.tscn")
const scnMENU = preload("res://Scenes/scnMenuModule.tscn")

const DISTANCE_X = 16 

var color_night = Color.from_hsv(227.0/360.0, 0.74, 0.34, 1)
var color_day = Color.from_hsv(227.0/360.0, 0.0, 1.0, 1)
var color_night_a = Color.from_hsv(227.0/360.0, 0.74, 0.34, 1)
var color_day_a = Color.from_hsv(227.0/360.0, 0.0, 1.0, 1)
var alpha_customers_global: float = 1.0 # El state actual
var alpha_dinner: float = 1.0 # El state actual

#Labels

@onready var label_clock: Label = $UI/Clock
@onready var label_money: Label = $UI/Money
@onready var label_days: Label = $UI/Days
@onready var label_ticks: Label = $Ticks
@onready var label_status: Label = $Areas/Outside/StatusLabel
@onready var label_endofday: Label = $UI/EndOfDay
@onready var label_customer: Label = $UI/Customer
@onready var label_text: Label = $UI/Text
@onready var label_weather: Label = $UI/Weather # Ajusta la ruta si es necesario

#Areas

@onready var Area_Dinner: Node2D = $Areas/Dinner
@onready var Area_Kitchen: Node2D = $Areas/Kitchen
@onready var Area_Outside: Node2D = $Areas/Outside

@onready var music_player = $OST # Asegúrate de tener este node en tu escena

var first_recipe = false

@onready var TickCounter: Timer = $Timer

@onready var View: Camera2D = $Camera2D

@onready var RecipeModule: Control = $UI/RecipeModule
@onready var MenuModule: Control = $UI/MenuModule

@onready var btnMenuModule: Button = $UI/MenuM_Button
@onready var btnRecipeModule: Button = $UI/RecipeM_Button

@onready var btnStaffUpgrades: Button = $UI/btnStaffUpgrades
@onready var btnUpgrades: Button = $UI/btnUpgrades

@onready var btnArrowL: Button = $UI/Arrow_L
@onready var btnArrowR: Button = $UI/Arrow_R

@onready var btnPause: Button = $UI/btnPause
@onready var btnSave: Button = $UI/btnSave
@onready var btnOpen: Button = $UI/btnOpen

@onready var btnSleep: Button = $UI/btnSleep

@onready var panelStaffUpgrades: Panel = $UI/StaffUpgrades
@onready var panelUpgrades: Panel = $UI/Upgrades

@onready var lblAreaName: Label = $UI/AreaName

var playlist: Array[AudioStream] = [
	preload("res://Audio/OST/OST1.mp3"),
	preload("res://Audio/OST/OST2.mp3"),
	preload("res://Audio/OST/OST3.mp3"),
	preload("res://Audio/OST/OST4.mp3"),
	preload("res://Audio/OST/OST5.mp3"),
	preload("res://Audio/OST/OST6.mp3"),
	preload("res://Audio/OST/OST7.mp3")
]

var currect_song_index: int = 0

func _ready():
	$Areas/Dinner/Tiles/Walls1F.show()
	$Areas/Dinner/Tiles/Walls2F.show()
	$Areas/Dinner/Tiles/Walls3F.show()
	
	var all_buttons = $".".find_children("*", "Button", true)
	
	for button in all_buttons:
		button.pressed.connect(_on_any_button_pressed)
		button.mouse_entered.connect(_on_any_button_hover)

	music_player.play()
	# 1. Esperamos al árbol de nodes
	#await get_tree().process_frame
	
	# 2. Cargar partida (Esto debería set el level visual y llamar a setup_seats)
	load_game()
	print(tutorial_completed)
	# 3. SEGURIDAD: Si no cargó nada, forzamos el inicio básico
	if seats_state.is_empty():
		setup_seats() # Esta función ahora usa el límite según el furniture visible

	# 4. Configuración visual y UI
	$Menu.show()
	$UI.hide()
	update_sunlight()
	spawn_visual_pedestrian() 
	ramen_menu = GlobalLogistics.menu_of_day
	update_menu_visual()
	
	if ramen_menu.is_empty():
		write_message("WARNING!: Empty menu.")
	
	label_status.text = "Closed"
	label_status.add_theme_color_override("font_color", Color.RED)
	
	setup_day()
	
	if not tutorial_completed:
		highlight(btnArrowL, true)
			
	# 5. Audio
	music_player.finished.connect(_on_music_finished)
	play_next_song()


func play_next_song():
	if playlist.is_empty(): return
	
	# 1. Calculamos qué canción toca hoy
	var today_index = (day - 1) % playlist.size()
	var new_song = playlist[today_index]

	# 2. Si ya está sonando esa canción, no hacemos nada (evita reinicios bruscos)
	if music_player.stream == new_song and music_player.playing:
		return

	# 3. EFECTO CROSSFADE: Bajamos volumen -> Cambiamos -> Subimos volumen
	var tween = create_tween()
	
	# Bajamos a -80dB (silencio total en Godot) en 1.5 segundos
	tween.tween_property(music_player, "volume_db", -80.0, 1.5).set_trans(Tween.TRANS_SINE)
	
	# Cuando esté en silencio, cambiamos el stream y damos Play
	tween.tween_callback(func():
		music_player.stream = new_song
		music_player.play()
	)
	
	# Volvemos a subir a 0dB (o tu volumen normal) en 1.5 segundos
	tween.tween_property(music_player, "volume_db", 0.0, 1.5).set_trans(Tween.TRANS_SINE)


func _on_music_finished():
	# Si la canción del día terminó, simplemente que vuelva a empezar
	music_player.play()


func _process(_delta: float) -> void:
	
	# ... (código de _process sin cambios) ...
	var hours: int = int(current_tick / 60.0) 
	var minutes = current_tick % 60
	label_clock.text = "%02d:%02d" % [hours, minutes]
	label_clock.text += " | %.1f°C" % current_temp
	label_money.text = "¥" + str(money)
	label_days.text = "Day " + str(day)
	label_ticks.text = "Ticks: " + str(current_tick)
	current_temp = weather.get_current_temperature(current_tick)


func setup_day():
	total_served_customers = 0
	total_stars = 0.0
	money_at_start = money
	weather.generate_new_weather(season)
	# 2. ACTUALIZAMOS EL LABEL FIJO (Solo una vez aquí)
	if label_weather:
		# Usamos directamente la función que ya tiene los emojis
		label_weather.text = weather.get_weather_emojis()

#AVANZAR TICKs
func _on_timer_timeout() -> void:
	current_tick += 1
	
	# REGLA DE ORO: Si pasamos la medaynight (1440), volvemos a 0 y sumamos el día
	if current_tick >= 1440:
		current_tick = 0 # Esto es las 00:00 exactas
		end_day()   # Llamamos a cobrar y guardar (UNA SOLA VEZ)
		# NOTA: No ponemos 'return' aquí para que el resto del tick se procese
	
	# --- RESTO DE PROCESOS (Siguen funcionando en la madrugada) ---
	update_sunlight()
	$Areas/Kitchen/Chef.ticks_process()
	$Areas/Dinner/Server.ticks_process()
	
	# 3. MOVIMIENTO DE nodeS
	for c in $Areas.get_children():
		if c.has_method("advance_tick"):
			c.advance_tick()

	# 4. STREET (Hasta las 00:00)
	if current_tick >= 360: # Empieza a las 7 AM
		
		$UI/EndOfDay.hide()
		if randf() < 0.35: 
			spawn_visual_pedestrian()
	
	if current_tick >= 1380:
		changes_allowed = true
		label_status.text = "Closed"
		label_status.add_theme_color_override("font_color", Color.RED)
		
	# 5. GENERACIÓN DE CLIENTES (Solo hasta las 22:00 / 1320)
	if current_tick >= 660 and current_tick < 1380:
		changes_allowed = false
		btnSave.hide()
		btnOpen.hide()
		label_status.text = "Open"
		label_status.add_theme_color_override("font_color", Color.LIME_GREEN)
		if current_tick % customer_rate == 0:
			generate_customer()
	
	# 6. ATENCIÓN (Incluso después de cerrar la entrada)
	#manage_customers_entry()
	# La Hostess ahora es la encargada de meter gente
	$Areas/Dinner/Hostess.tick_process()

func everyone_finished_eating() -> bool:
	for c in $Areas/Outside.get_children():
		if c.has_method("advance_tick"):
			# Si hay alguien que no sea transeúnte y no esté ya saliendo, el día sigue
			if c.state != "STREET" and c.state != "LEAVING":
				return false
	return true

func spawn_visual_pedestrian():
	var config_day = calendar_probability.get(day, calendar_probability["default"])
	var user_name_customer_key = select_customer_per_probability(config_day)
	
	var new_pedestrian = preload("res://Scenes/scnCustomer.tscn").instantiate()
	$Areas.add_child(new_pedestrian)
	
	# Definimos los puntos
	var right_pos = $Areas/Outside/Marker_Right.global_position
	var left_pos = $Areas/Outside/Marker_Left.global_position
	
	# AQUÍ USAMOS pos_inicio:
	new_pedestrian.global_position = right_pos # Lo teletransportamos al inicio
	
	# Le pasamos los data y el destino final (la izquierda)
	new_pedestrian.setup_street(customer_database[user_name_customer_key], left_pos)
	
	customers_on_street.append(new_pedestrian)


# --- FUNCION DE GENERACION DE CLIENTE REFACTORIZADA ---
func generate_customer():
	if wait_line.size() >= 10 or customers_on_street.is_empty():
		return

	# 1. Calculamos el punto medio de la calle
	var right_pos = $Areas/Outside/Marker_Right.global_position ##IMPROTNAOBFABOF ponerle y
	var left_pos = $Areas/Outside/Marker_Left.global_position ##INASODANDPA ponerle y
	var middle_point = (right_pos + left_pos) / 2.0

	# 2. Buscamos al primer candidate que aún no haya pasado de la mitad
	var candidate = null
	for i in range(customers_on_street.size()):
		var c = customers_on_street[i]
		if is_instance_valid(c) and c.global_position > middle_point:
			candidate = c
			customers_on_street.remove_at(i) # Lo sacamos de la lista de la calle
			break
	
	# Si todos ya pasaron de la mitad, nadie entra en este tick
	if candidate == null:
		return

	# 3. Lógica de negocio (recipe/Menú)
	var temp_of_moment = weather.get_current_temperature(current_tick)
	var best_choice = find_best_recipe_for_customer(candidate.data, temp_of_moment)

	if best_choice == null:
		# Si no hay plato, lo devolvemos a la lista de street para que siga su camino
		customers_on_street.push_back(candidate) 
		return

	# REGLA DE ORO: Si la fila está llena, no entra nadie más.
	if wait_line.size() >= 10: 
		return

	# Aquí SOLO lo metemos a la fila visual. NO le damos seat todavía.
	wait_line.append(candidate)
	candidate.enter_to_restaurant(best_choice, wait_line.size() - 1)

	# NUEVA LÍNEA: Forzamos a que todos se enteren de su lugar para que no se encimen
	update_all_wait_line_positions()

func manage_customers_entry():
	if wait_line.is_empty(): return
	
	var seat = find_free_seat()
	if seat != null:
		# Sacamos al primero de la fila YA
		var customer = wait_line.pop_front() 
		
		if is_instance_valid(customer):
			customer.asignar_a_seat(seat)
			# Forzamos a los que quedan en la fila a moverse
			update_all_wait_line_positions()

func update_all_wait_line_positions():
	for i in range(wait_line.size()):
		var c = wait_line[i]
		if is_instance_valid(c):
			# Forzamos al customer a actualizar su objetivo visual
			c.update_wait_line_position(i) 

func ask_to_chef(customer_node):
	# Ajusta esta ruta si tu Chef se llama distinto
	var chef_node = $Areas/Kitchen/Chef
	if chef_node:
		chef_node.recibir_pedido(customer_node)
	else:
		print("ERROR: Cheft was not found in the path $Panel/Room/Chef")
		

func setup_seats():
	seats_state.clear()
	var container = $Areas/Dinner/SeatContainer
	
	# Determinamos el límite exacto según el furniture que el jugador ve
	var limit = 3 # Nivel 1 (Base)
	
	if $Areas/Dinner/Tiles/FurnitureLvl6.visible: 
		limit = 8
	elif $Areas/Dinner/Tiles/FurnitureLvl5.visible: 
		limit = 7
	elif $Areas/Dinner/Tiles/FurnitureLvl4.visible: 
		limit = 6
	elif $Areas/Dinner/Tiles/FurnitureLvl3.visible: 
		limit = 5
	elif $Areas/Dinner/Tiles/FurnitureLvl2.visible: 
		limit = 4
	elif $Areas/Dinner/Tiles/FurnitureLvl1.visible: 
		limit = 3
	
	# Registro en el diccionario
	for i in range(container.get_child_count()):
		var seat = container.get_child(i)
		if (i + 1) <= limit:
			seats_state[seat] = false # LIBRE
		else:
			# Si no está en el límite, los customers NO la ven
			pass 

	print("Seats ready for the current level: ", seats_state.size())




func find_free_seat() -> Node2D:
	# 1. Obtenemos a los customers actuales para saber qué seats están busys
	var customers_en_escena = get_tree().get_nodes_in_group("DinnerCustomer")
	
	# 2. IMPORTANTE: Solo iteramos sobre las seats que están en 'seats_state'
	# Este diccionario solo tiene las 3, 6 u 8 seats que permitiste según el level.
	for seat in seats_state.keys():
		var seat_busy = false
		for c in customers_en_escena:
			if is_instance_valid(c) and c.assign_seat == seat:
				seat_busy = true
				break
		
		# 3. Si la seat está en nuestro "club de seats permitidas" y está libre...
		if not seat_busy:
			return seat
			
	return null # No hay seats permitidas libres

func release_seat(node_seat: Node2D):
	if is_instance_valid(node_seat) and seats_state.has(node_seat):
		# Solo liberamos si realmente estaba busy para evitar el "Doble Liberando" del log
		if seats_state[node_seat] == true:
			seats_state[node_seat] = false
			# print("seat liberada REAL: ", node_seat.user_name)

func payment_register(amount: int, stars: float, recipe_name: String):
	money += amount
	# SUMAMOS EN EL SINGLETON (EL ÚNICO SITIO QUE IMPORTA)
	#GlobalLogistics.stars_accumulated += stars
	#GlobalLogistics.total_served_customers += 1 
	GlobalLogistics.record_score(stars)
	
		# --- EFECTO DE GANANCIA ---
	show_profit_text(amount)
	
	# Esto es para tus recipe_cards visuales de recipes
	if card_references.has(recipe_name):
		var recipe_card = card_references[recipe_name]
		recipe_card.accumulated_sales += 1
		recipe_card.update_visual_counter()

func show_profit_text(amount: int):
	var lb = $UI/Profit
	var start_point = $UI/ProfitPosition
	
	# 1. RESET INMEDIATO AL MARCADOR
	lb.global_position = start_point.global_position
	lb.modulate.a = 1.0 
	lb.text = "+ ¥" + str(amount)
	lb.show()
	
	# 2. CREAR TWEEN
	var tween = create_tween()
	tween.set_parallel(true)
	
	# 3. ANIMACIÓN: Lenta al inicio, rápida al final (EASE_IN)
	# Subimos un poco más (70px) para que se note la aceleración
	tween.tween_property(lb, "global_position:y", start_point.global_position.y - 70, 1.4)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		
	# El desvanecimiento (Alpha) lo hacemos un pelín más tarde para que se vea el número
	tween.tween_property(lb, "modulate:a", 0.0, 1.0).set_delay(0.4)
	
	# 4. FINALIZAR
	tween.finished.connect(func(): lb.hide())

func customer_leaves_wait_line(customer_node):
	var index = wait_line.find(customer_node)
	
	if index != -1:
		wait_line.remove_at(index) # Lo sacamos de la lista
		write_message("A customer in line has given up.")
		
		# IMPORTANTE: Esto hace que todos los de atrás caminen hacia adelante
		for i in range(wait_line.size()):
			if is_instance_valid(wait_line[i]):
				wait_line[i].update_wait_line_position(i)

func find_best_recipe_for_customer(customer_data: CustomerData, p_current_temp: float) -> Variant:
	var best_choice = null
	var max_affinity: float = -999.0 

	var favorite_at_moment: Array[Ingredient] = []
	if p_current_temp > 27.0: favorite_at_moment = customer_data.favorites_hot
	elif p_current_temp < 10.0: favorite_at_moment = customer_data.favorites_cold
	else: favorite_at_moment = customer_data.favorites_tempered

	for choice in ramen_menu:
		var recipe = choice["resource"]
		if recipe == null: continue # Si el slot está vacío, saltamos al siguiente
		var sale_price = choice["price"]
		
		# FILTROS ELIMINATORIOS
		if sale_price > (customer_data.budget * 2.0): continue
		if customer_data.is_vegetarian and not recipe.is_vegetarian_friendly(): continue
		
		var ing_list = recipe.ingredients.values().filter(func(i): return i != null)
		
		var success = 0
		var negative_score = 0.0 
		
		# 1. Extraemos SOLO las categorías de los favoritos (ej: ["Noodles", "Broth"])
		var liked_category = favorite_at_moment.map(func(f): return f.category)
		
		for ing in ing_list:
			# 2. Comparamos la CATEGORÍA del ingrediente servido
			if ing.category in liked_category:
				success += 1
			else:
				# --- LÓGICA DE DENSIDAD TÉRMICA EN CALOR (Si NO es favorito) ---
				if p_current_temp > 27.0:
					if ing.category == "Broth":
						negative_score += ing.thermal_density * 2.0
					else:
						negative_score += 0.1
				else:
					negative_score += 0.1 #templado/frio
		
		# CALCULAMOS AFINIDAD FINAL
		var affinity_score = (success * 1.0) - negative_score
# NUEVA PENALIZACIÓN DE AFINIDAD:
# Si el price supera el presupuesto, bajamos la afinidad para que el customer
# prefiera recipes que SÍ puede pagar si tienen un sabor similar.
		if sale_price > customer_data.budget:
			var overprice_ratio = float(sale_price) / float(customer_data.budget)
			# Por cada 0.5 extra de presupuesto, restamos afinidad
			affinity_score -= (overprice_ratio - 1.0) * 2.0 

		affinity_score *= customer_data.weight_taste
		
		# DECISIÓN
		# DECISIÓN
		if affinity_score > max_affinity:
			max_affinity = affinity_score
			best_choice = choice
		elif affinity_score == max_affinity and best_choice != null:
			# CORRECCIÓN AQUÍ: Debe ser el user_name exacto de la llave, que es "price"
			if sale_price < best_choice["price"]:
				best_choice = choice

	return best_choice


# He renombrado current_temp a p_temp para evitar el error de SHADOWED_VARIABLE
func calculate_final_rating(p_customer_node: Node2D, choice: Dictionary, p_temp: float, p_angry: bool, p_ticks: int, _p_angry_wait_line: bool) -> float:
	var recipe = choice["resource"]
	var sale_price = float(choice["price"])
	var customer_data = p_customer_node.data 
	
	# --- NUEVO: DESCUBRIMIENTO DE ingredients ---
	# sCada vez que un customer termina, descubrimos lo que comió
	reveal_recipe_ingredients(recipe)
	
	var bonus_hostess_service = p_customer_node.received_service_score
	var bonus_hostess_comfort = p_customer_node.received_comfort_bonus
	
	# --- 1. TASTE (Sabor) ---
	var favoritos = customer_data.favorites_hot if p_temp > 27.0 else (customer_data.favorites_cold if p_temp < 10.0 else customer_data.favorites_tempered)
	
	# REGLA DE CATEGORÍAS (Para evitar el bug de las 3.8 stars)
	var desired_categories = []
	for f in favoritos:
		if not f.category in desired_categories:
			desired_categories.append(f.category)
	
	var success_category = 0
	var ing_list = recipe.ingredients.values().filter(func(i): return i != null)
	
	for cat_sought in desired_categories:
		for ing_servido in ing_list:
			if ing_servido.category == cat_sought:
				success_category += 1
				break 

	var taste_score = float(success_category) / float(desired_categories.size()) if desired_categories.size() > 0 else 0.5
	
	if p_temp > 27.0 and recipe.ingredients.get("Broth") != null:
		taste_score = 0.1

	# --- 2. SPEED ---
	var speed_score = clamp(1.0 - (float(p_ticks) / float(customer_data.patience_ticks * 2.0)), 0.0, 1.0)

	# --- 3. COMFORT ---
	var comfort_score = clamp(current_shop_comfort + bonus_hostess_comfort, 0.0, 1.0)

	# --- 4. PRICE ---
	var recipe_cost = recipe.get_total_cost()
	var price_score = clamp((recipe_cost * 2.0) / sale_price, 0.0, 1.0) if sale_price > 0 else 0.0

	# --- 5. SERVICE & HYGIENE ---
	var base_service = 0.9 if not p_angry else 0.2
	var service_score = clamp(base_service * bonus_hostess_service, 0.0, 1.0)
	var hygiene_score = 0.8 

	# --- CÁLCULO FINAL ---
	var total_score = (
		(taste_score * customer_data.weight_taste) +
		(speed_score * customer_data.weight_speed) +
		(comfort_score * customer_data.weight_comfort) +
		(price_score * customer_data.weight_price) +
		(service_score * customer_data.weight_service) +
		(hygiene_score * customer_data.weight_hygiene)
	)

	var max_possible = (
		customer_data.weight_taste + customer_data.weight_speed + 
		customer_data.weight_comfort + customer_data.weight_price + 
		customer_data.weight_service + customer_data.weight_hygiene
	)

	var rating_final = (total_score / max_possible) * 5.0

	# --- PENALIZACIÓN POR PRESUPUESTO ---
	if sale_price > customer_data.budget:
		var ratio = sale_price / float(customer_data.budget)
		var penalty = 0.5 + ((ratio - 1.5) * 2.0) if ratio > 1.5 else (ratio - 1.0)
		rating_final -= penalty

	return clamp(snapped(rating_final, 0.1), 1.0, 5.0)

# Esta función la puedes dejar en Main.gd o donde prefieras
func reveal_recipe_ingredients(recipe: RecipeResource):
	for ing in recipe.ingredients.values():
		if ing != null:
			GlobalLogistics.discover_ingredient(ing.name)


func select_customer_per_probability(config_day: Dictionary) -> String:
	var total_weight = 0.0
	for weight in config_day.values():
		total_weight += weight
	
	var r = randf() * total_weight
	var accumulated = 0.0
	
	for n_customer in config_day.keys():
		accumulated += config_day[n_customer]
		if r <= accumulated:
			return n_customer
			
	return config_day.keys()[0] # Fallback

func end_day():
	# 1. ACTUALIZAR EL DÍA (Ya es oficialmente el mañana)
	day += 1
	
	# 2. LIMPIEZA DE CLIENTES (Los que quedaron al cerrar)
	reset_daily_menu()
	var wait_line_copy = wait_line.duplicate()
	for c in wait_line_copy:
		if is_instance_valid(c): c.leave_wait_line("") 
	wait_line.clear()
	customers_on_street.clear()

	# 3. CÁLCULO ECONÓMICO DETALLADO
	var average = GlobalLogistics.get_current_average()
	var today_gross_profit: int = money - money_at_start
	if today_gross_profit < 0: today_gross_profit = 0 
	
	# Pagos basados en porcentajes (Chef 10%, Server 5%, Hostess 5%)
	var salary_chef = roundi(today_gross_profit * 0.10)
	var salary_server = roundi(today_gross_profit * 0.05)
	var salary_hostess = roundi(today_gross_profit * 0.05)
	
	# Renta que escala con los días
	var today_rent = 100 + (day * 20)
	var total_expenses = today_rent + salary_chef + salary_server + salary_hostess
	
	# Aplicamos los gastos al capital
	money -= total_expenses
	# Seteamos la base para el cálculo de mañana (que empieza a las 00:00)
	money_at_start = money 

	# 4. INTERFAZ DE RESUMEN DETALLADA (Usando el día que acaba de pasar: day - 1)
	var summary = "--- DAY %d SUMMARY ---\n" % (day - 1)
	summary += "Today's Earnings: ¥%d\n" % today_gross_profit
	summary += "Expenses (Rent + Staff): -¥%d\n" % total_expenses
	summary += "Net Profit: ¥%d\n" % (today_gross_profit - total_expenses)
	summary += "Recent Stars: %.1f | Final Balance: ¥%d" % [average, money]
	
	label_endofday.text = summary
	label_endofday.modulate.a = 1.0 # Aseguramos que sea visible
	label_endofday.show()
	$UI/Rate.text = "%.1f" % average + "⭐"
	
	# 5. GUARDADO (Se guarda Día: Nuevo, Ticks: 0, Dinero: Ya cobrado)
	save_progress()
	
	# 6. MANTENIMIENTO Y SIGUIENTE OST
	update_difficulty_per_average(average)
	setup_day()
	play_next_song() 

	# 7. EFECTO DE DESVANECIMIENTO (Fluidez total)
	var tween = create_tween()
	tween.tween_interval(6.0) # Se queda 6 segundos para que de tiempo a leer
	tween.tween_property(label_endofday, "modulate:a", 0.0, 2.0)
	tween.tween_callback(label_endofday.hide)
	
	# GAME OVER (Check final)
	if average < 1.1 or money < -500:
		label_endofday.text += "\n[color=red]BANKRUPTCY![/color]"
		get_tree().paused = true

func show_daily_forecast():
	var probs = calendar_probability.get(day, calendar_probability["default"])
	var user_names_customers = ", ".join(probs.keys())
	
	# Obtenemos los emojis del weather
	var emojis = weather.get_weather_emojis()
	
	# Formateamos el text: Emojis arriba y customers abajo
	var t = emojis + " FORECAST " + emojis
	label_customer.text = t + "\nCustomers: " + user_names_customers
	
	# El timer que ya tenías para limpiar el text
	get_tree().create_timer(5.0).timeout.connect(func(): label_customer.text = "")

func write_message(new_text: String):
	label_text.text = new_text
	if delete_timer: delete_timer.kill()
	delete_timer = create_tween()
	delete_timer.tween_interval(8.0)
	delete_timer.tween_callback(func(): label_text.text = "")

func update_menu_visual():
	var _customer_menu = GlobalLogistics.menu_of_day
	var slot_list = hboxRecipeSlots.get_children()
	var editing = get_node("UI/MenuModule").visible
	
	# LIMPIAR EL DICCIONARIO ANTES DE EMPEZAR
	card_references.clear() 

	for i in range(slot_list.size()):
		var slot = slot_list[i]
		
		if i < ramen_menu.size() and ramen_menu[i]["resource"] != null:
			var data = ramen_menu[i]
			var recipe = data["resource"] # Sacamos la recipe
			
			# #### ¡ESTA ES LA LÍNEA QUE FALTA! ####
			# Guardamos: "Nombre de recipe" -> node del Slot
			card_references[recipe.recipe_name] = slot
			
			slot.set_recipe_card(recipe, data["price"])
			
			if editing:
				slot.get_node("ButtonAdd").text = "x"
				slot.get_node("ButtonAdd").modulate = Color.RED
				slot.get_node("VBoxContainer/LabelSold").hide()
			else:
				slot.simulation_mode(data["price"])
		else:
			slot.label_user_name.text = "Empty Slot"
			slot.label_cost.text = "¥0"
			var btn = slot.get_node("ButtonAdd")
			btn.show()
			btn.text = "+"
			btn.modulate = Color.WHITE
			slot.get_node("VBoxContainer/LabelSold").hide()
			slot.set_recipe_card(null)

func reset_daily_menu():
	# 1. Vaciamos la lista de recipes en el Singleton
	GlobalLogistics.menu_of_day.clear()
	
	# 2. Reseteamos el slot que estábamos editing
	GlobalLogistics.selected_slot = -1
	
	# 3. Refrescamos los slots físicos para que vuelvan a mostrar el "+"
	# NO borramos los nodes, solo los "limpiamos" visualmente
	update_slot_state(true) # false = modo edición para el new día
	update_menu_visual()

func update_sunlight():
	var factor = remap(cos((current_tick - 720) * (2.0 * PI / 1440.0)), -1.0, 1.0, 0.0, 1.0)
	var current_color = color_night.lerp(color_day, factor)
	var current_color_a = color_night_a.lerp(color_day_a, factor)
	$Areas/Outside.modulate = current_color_a
	$Areas/Floor.modulate = current_color

func _on_recipe_m_button_pressed() -> void:
	if changes_allowed == false:
		write_message("You can't make changes when it's already open.")
		return
	if panelStaffUpgrades.visible:
		return
	if not tutorial_completed:
		first_recipe = true
		highlight(btnRecipeModule, false)
	#	highlight(btnArrowR, true)
	
	# 1. Buscamos si ya existe en el árbol de nodes
	var existing_recipe = get_node_or_null("UI/RecipeModule")
	
	if existing_recipe:
		# LÓGICA DE CERRAR/ABRIR:
		if existing_recipe.visible:
			TickCounter.wait_time = 0.3
			if not tutorial_completed:
				highlight(btnArrowR, true)
			existing_recipe.hide()
			RecipeModule._on_btn_erase_pressed()
		else:
			TickCounter.wait_time = 2
			existing_recipe.show()
			# Si abrimos recipes, ocultamos el otro menú para que no estorben
			var menu_abierto = get_node_or_null("UI/MenuModule")
			if menu_abierto: menu_abierto.hide()
	else:
		# 2. Si no existe, lo instancemos por primera vez
		var recipe_instance = scnRECIPE.instantiate()
		recipe_instance.user_name = "RecipeMaking" 
		
		# 3. Conectamos su señal para cuando termine de crear la recipe
		if recipe_instance.has_signal("recipe_cerrado"):
			recipe_instance.recipe_cerrado.connect(_on_recipe_end)
		
		$UI.add_child(recipe_instance)

	
# Función que se ejecuta al cerrar el Recipe Maker
func _on_recipe_end():
	print("Recipe Maker closed.")
	# Opcional: Podrías abrir automáticamente el Menu Maker aquí 
	# para agilizar el flujo del jugador antes de que acabe el minuto.
	
# Main.gd
func _on_menu_m_button_pressed() -> void:
	if changes_allowed == false:
		write_message("You can't make changes when it's already open.")
		return
	if panelUpgrades.visible:
		return
	if tutorial_completed == false and View.position == Area_Dinner.position:
		if first_recipe == false:
			write_message("Go to Kitchen and make your first recipe.")
			return
	var menu_module = get_node_or_null("UI/MenuModule")
	if menu_module and menu_module.visible:
		TickCounter.wait_time = 0.3
		if not tutorial_completed:
			highlight(btnMenuModule, false)
			highlight(btnArrowL, true)
			tutorial_completed = true
		else:
			highlight(btnMenuModule, false)
		menu_module.hide()
		update_slot_state(true) # Esto activará el simulation_mode sin errores
		return

	if not menu_module.visible:
		TickCounter.wait_time = 1.25
		if not tutorial_completed:
			highlight(btnMenuModule, false)
			#highlight(hboxRecipeSlots/RecipeSlot1, true)
			menu_module.highlight_first_recipe_card_available()
		menu_module.show()
		update_slot_state(false) # Al abrir, entramos en modo "Edición"


# Nueva función para centralizar la lógica de "Transformación"
func update_slot_state(sale_mode: bool):
	var data = GlobalLogistics.menu_of_day
	var slots = hboxRecipeSlots.get_children()
	var selected = GlobalLogistics.selected_slot

	for i in range(slots.size()):
		var slot = slots[i]
		
		# --- AQUÍ DEFINIMOS LA VARIABLE QUE FALTABA ---
		var has_recipe = i < data.size() and data[i]["resource"] != null
		
		# --- LÓGICA DE BORDES ---
		var style_box = slot.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		
		if i == selected and not sale_mode:
			style_box.border_color = Color.GREEN
			style_box.set_border_width_all(3)
		else:
			style_box.border_color = Color.TRANSPARENT # Cambiado a transparente como querías
			style_box.set_border_width_all(0)
		
		slot.add_theme_stylebox_override("panel", style_box)
		
		# --- EL RESTO DE TU LÓGICA ---
		if sale_mode:
			if has_recipe:
				slot.show()
				slot.get_node("ButtonAdd").hide()
				# Pasamos recipe y price para que no se resetee el cost
				slot.set_recipe_card(data[i]["resource"], data[i]["price"])
				slot.simulation_mode(data[i]["price"])
			else:
				slot.hide()
		else:
			slot.show()
			if has_recipe:
				# Pasamos recipe y price aquí también para mantener el SpinBox actualizado
				slot.set_recipe_card(data[i]["resource"], data[i]["price"])
			
			var btn = slot.get_node_or_null("ButtonAdd")
			if btn: 
				btn.show()
				btn.text = "+" if not has_recipe else "x"


# Esta función se ejecutará cuando presiones "Done" en el MenuMaker
func _on_menu_end():
	print("Menu has been closed, updating HBoxContainer...")
	update_menu_visual()

func buy_new_seat():
	# 1. Buscamos la seat que esté más a la derecha en el diccionario
	var last_seat: Marker2D = null
	for s in seats_state.keys():
		if last_seat == null or s.position.x > last_seat.position.x:
			last_seat = s
	
	if last_seat == null:
		print("Error: There's not seat to duplicate")
		return

	# 2. Duplicamos el node de la última seat
	var new_seat = last_seat.duplicate()
	
	# 3. Configuramos user_name y posición (16px a la derecha)
	new_seat.user_name = "Seat" + str(seats_state.size() + 1)
	new_seat.position = last_seat.position + Vector2(32, 0)
	
	# 4. Añadir al node Room
	Area_Dinner.add_child(new_seat)
	
	# 5. REGISTRAR en el sistema de customers como "Libre"
	seats_state[new_seat] = false 
	
	write_message("Seat " + new_seat.user_name + " gained.")

# ESTA ES LA QUE "RECREA" LA seat (Úsala también en load_game)
func create_visual_seat():
	# 1. Buscamos la seat base
	var last_seat: Marker2D = null
	for s in seats_state.keys():
		if last_seat == null or s.position.x > last_seat.position.x:
			last_seat = s
	
	if last_seat == null: return

	# 2. Duplicamos y posicionamos
	var new_seat = last_seat.duplicate()
	new_seat.user_name = "Seat" + str(seats_state.size() + 1)
	new_seat.position = last_seat.position + Vector2(32, 0)
	
	# 3. Registrar
	Area_Dinner.add_child(new_seat)
	seats_state[new_seat] = false 
	write_message("Seat installed.")

#SISTEMA DE CAMBIO DE CAMARAS CON FLECHAS DIRECCIONALES
func _on_arrow_r_pressed() -> void:
#RIGHT ARROW
	if View.position == Area_Kitchen.position:
		#Area_Kitchen.hide()
		btnRecipeModule.hide()
		btnSleep.hide()
		btnSave.hide()
		btnStaffUpgrades.hide()
		panelStaffUpgrades.hide()
		if RecipeModule.visible:
			TickCounter.wait_time = 0.3
			RecipeModule.hide()
			RecipeModule._on_btn_erase_pressed()
		update_slot_state(true)
		#Area_Dinner.show()
		#$Areas/Dinner/Control/Background.show()
		Area_Dinner.modulate = Color(1, 1, 1, 1)
		Area_Kitchen.modulate = Color(1, 1, 1, 0.40)
		$Areas/Dinner/Tiles/Walls1L.show()
		$Areas/Dinner/Tiles/Walls2L.show()
		$Areas/Dinner/Tiles/Walls3L.show()
		View.position = Area_Dinner.position
		lblAreaName.text = "Dinner"
		if not tutorial_completed:
			if btnArrowR.material != null:
				highlight(btnArrowR, false)
				highlight(btnMenuModule, true)
			# 5. GENERACIÓN DE CLIENTES (Solo hasta las 6:00 / 1320)
		if current_tick >= 360 and current_tick < 660 and tutorial_completed:
			btnOpen.show()
		if current_tick >= 660 and current_tick < 360:
			btnOpen.hide()
		hboxRecipeSlots.show()
		btnMenuModule.show()
		btnUpgrades.show()
		# 1. Cambiamos la "memoria" del Main para futuros customers
		alpha_dinner = 1.0
		# 2. Buscamos a los que ya están en las tables y los ponemos opacos
		var customers_table = get_tree().get_nodes_in_group("DinnerCustomer")
		for customer in customers_table:
			customer.modulate.a = 1.0 # O usa = alpha_dinner si es un Color
		alpha_customers_global = 0.4
		get_tree().call_group("Customer", "change_my_alpha", alpha_customers_global)

		
	elif View.position == Area_Dinner.position:
		btnMenuModule.hide()
		hboxRecipeSlots.hide()
		btnUpgrades.hide()
		btnOpen.hide()
		if MenuModule.visible:
			MenuModule.hide()
			TickCounter.wait_time = 0.3
		panelUpgrades.hide()
		$Areas/Dinner/Tiles/Walls1F.show()
		$Areas/Dinner/Tiles/Walls2F.show()
		$Areas/Dinner/Tiles/Walls3F.show()
		#Area_Dinner.hide()
		#Area_Outside.show()
		View.position = Area_Outside.position
		lblAreaName.text = "Outside"
		color_day_a.a = 1.0
		color_night_a.a = 1.0
		alpha_customers_global = 1.0
		# Avisar a los que ya están vivos:
		get_tree().call_group("Customer", "change_my_alpha", alpha_customers_global)

func _on_arrow_l_pressed() -> void:
#LEFT ARROW
	if View.position == Area_Outside.position:
		update_slot_state(true)
		#Area_Outside.hide()
		#Area_Dinner.show()
		View.position = Area_Dinner.position
		lblAreaName.text = "Dinner"
		btnMenuModule.show()
		btnUpgrades.show()
		hboxRecipeSlots.show()
		#if not tutorial_completed:
		#	btnOpen.hide()
		#else:
		#	btnOpen.show()
		if current_tick >= 360 and current_tick < 660 and tutorial_completed:
			btnOpen.show()
		if current_tick >= 660 and current_tick < 360:
			btnOpen.hide()
		if tutorial_completed:
			highlight(btnStaffUpgrades, false)
			highlight(btnMenuModule, false)
		$Areas/Dinner/Tiles/Walls1F.hide()
		$Areas/Dinner/Tiles/Walls2F.hide()
		$Areas/Dinner/Tiles/Walls3F.hide()
		Area_Kitchen.modulate = Color(1, 1, 1, 0.40)
		color_day_a.a = 0.4
		color_night_a.a = 0.4
		alpha_customers_global = 0.4
		# Avisar a los que ya están vivos:
		get_tree().call_group("Customer", "change_my_alpha", alpha_customers_global)
		#$Areas/Dinner/Control/Background.show()
	elif View.position == Area_Dinner.position:
		#Area_Dinner.hide()
		#Area_Kitchen.show()
		#$Areas/Kitchen/Control/Background.show()
		Area_Dinner.modulate = Color(1, 1, 1, 0.40)
		if not tutorial_completed:
			if btnArrowL.material != null:
				highlight(btnArrowL, false)
				highlight(btnRecipeModule, true)
		elif tutorial_completed and first_save == false:
			highlight(btnArrowL, false)
			highlight(btnSave, true)
			first_save = true
		btnOpen.hide()
		hboxRecipeSlots.hide()
		btnMenuModule.hide()
		btnUpgrades.hide()
		MenuModule.hide()
		panelUpgrades.hide()
		View.position = Area_Kitchen.position
		lblAreaName.text = "Kitchen"
		btnStaffUpgrades.show()
		btnRecipeModule.show()
		if current_tick >= 0 and current_tick <= 360:
			btnSleep.show()
		else:
			btnSleep.hide()
			
		if current_tick >= 0 and current_tick <= 660:
			btnSave.show()
		else:
			btnSave.hide()
		
		Area_Kitchen.modulate = Color(1, 1, 1, 1)
		$Areas/Dinner/Tiles/Walls1L.hide()
		$Areas/Dinner/Tiles/Walls2L.hide()
		$Areas/Dinner/Tiles/Walls3L.hide()
		alpha_dinner = 0.4
		get_tree().call_group("DinnerCustomer", "change_my_alpha", alpha_dinner)

func _on_btn_pause_pressed() -> void:
	var menu_escena = load("res://scnTitle_Screen.tscn")
	var menu_instance = menu_escena.instantiate()
	$Menu.add_child(menu_instance)
	$UI.hide()
	TickCounter.stop() # Pausamos los ticks

func _on_btn_speed_pressed() -> void:
	var btn = $UI/btnSpeed
	
	if btn.text == "〰️":
		btn.text = "🚄"
		Engine.time_scale = 2.0
	elif btn.text == "🚄":
		btn.text = "⚡"
		Engine.time_scale = 4.0
	else:
		btn.text = "〰️"
		Engine.time_scale = 1.0

func _on_btn_sleep_pressed() -> void:
	if current_tick >= 0 and current_tick <= 360:
		btnSleep.hide()
		current_tick = 360
		

func highlight(button: Control, activated: bool) -> void:
	if activated:
		# 1. Cargamos el material (.tres)
		var my_material = load("res://Resources/Glow.tres")
		
		# 2. Se lo asignamos al botón PRIMERO
		button.material = my_material
		
		# 3. Verificamos que ya NO sea null antes de cambiar el parámetro
		if button.material != null:
			button.material.set_shader_parameter("intensity", 0.6)
	else:
		# Si queremos apagarlo, simplemente quitamos el material
		button.material = null

func _on_any_button_hover():
	var asp = AudioStreamPlayer.new()
	asp.stream = hover_sound
	asp.bus = "SFX"
	add_child(asp)
	asp.play()
	asp.finished.connect(asp.queue_free)

func _on_any_button_pressed():
	if not is_inside_tree(): return # Si ya nos estamos saliendo, no hagas nada
	var asp = AudioStreamPlayer.new()
	asp.stream = click_sound
	asp.bus = "SFX"
	add_child(asp)
	asp.play()
	# Se elimina solo al terminar para no dejar basura en el árbol de nodes
	asp.finished.connect(asp.queue_free)


func _on_delete_customer_area_entered(area: Area2D) -> void:
	if area.is_in_group("Customer"):
		area.queue_free()

# --- SISTEMA DE GUARDADO (AÑADIR AL FINAL DEL MAIN) ---

func save_progress():
	var config = ConfigFile.new()
	
	# --- SECCIÓN: PROGRESO ---
	config.set_value("Progress", "day", day)
	config.set_value("Progress", "ticks", current_tick)
	config.set_value("Progress", "season", season)
	config.set_value("Progress", "user_name", user_name)
	config.set_value("Progress", "customer_rate", customer_rate)
	config.set_value("Progress", "tutorial_completed", tutorial_completed)
	config.set_value("Progress", "fist_save", first_save)
# Dentro de save_progress()
	config.set_value("Progress", "total_stars", GlobalLogistics.stars_accumulated)
	config.set_value("Progress", "total_served_customers", GlobalLogistics.total_served_customers)
	
	# --- SECCIÓN: ECONOMÍA ---
	config.set_value("Economy", "yenes", money)
	config.set_value("Economy", "seats_extras", seats_state.size() - 7)
	
	# --- SECCIÓN: STAFF (CORREGIDA) ---
	config.set_value("Staff", "lvl_chef", $Areas/Kitchen/Chef.level)
	config.set_value("Staff", "lvl_server", $Areas/Dinner/Server.level) # Antes decía lvl_chef
	config.set_value("Staff", "lvl_hostess", $Areas/Dinner/Hostess.level) # Antes decía lvl_chef
	
	config.set_value("Staff", "chef_ticks", $Areas/Kitchen/Chef.ticks_per_station)
	config.set_value("Staff", "server_ticks", $Areas/Dinner/Server.ticks_per_action)
	config.set_value("Staff", "server_speed", $Areas/Dinner/Server.move_speed) # Guarda la velocidad
	config.set_value("Staff", "hostess_service", $Areas/Dinner/Hostess.stat_service)
	config.set_value("Staff", "hostess_comfort", $Areas/Dinner/Hostess.stat_comfort)

	config.set_value("Progress", "score_history", GlobalLogistics.stars_history)
	
	# --- SECCIÓN: MUNDO (PEATONES) ---
	var pedestrians_data = []
	for p in get_tree().get_nodes_in_group("Customer"):
		if is_instance_valid(p) and p.state == "STREET":
			pedestrians_data.append(p.save_pedestrian_data())
	config.set_value("World", "pedestrians", pedestrians_data)
	
	# --- SECCIÓN: MENÚ ---
	var menu_path = []
	var prices_menu = []
	for item in GlobalLogistics.menu_of_day:
		if item.has("resource") and item["resource"] != null:
			menu_path.append(item["resource"].resource_path)
			prices_menu.append(item["price"])
	config.set_value("Menu", "paths", menu_path)
	config.set_value("Menu", "prices", prices_menu)
	
	# --- SECCIÓN: DETECTAR NIVEL DE MUEBLES (DINÁMICO) ---
	var level_to_save = 1 # Nivel base por defecto

# Buscamos del 6 hacia abajo. El primero que encuentre visible será el level actual.
	for n in range(6, 1, -1): 
		var node_path = "Areas/Dinner/Tiles/FurnitureLvl" + str(n)
		var node_furniture = get_node_or_null(node_path)
		
		if node_furniture and node_furniture.visible:
			level_to_save = n
			break # Encontramos el level más alto, dejamos de buscar

	config.set_value("Progress", "lvl_furniture", level_to_save)
	
	config.save("user://savegame.cfg")
	write_message("Game save at tick: " + str(current_tick))

func load_game():
	var config = ConfigFile.new()
	if config.load("user://savegame.cfg") != OK: 
		print("Can not find a save file.")
		return

	# 1. ASIGNACIÓN DE VARIABLES AL MAIN Y AL SINGLETON
	day = config.get_value("Progress", "day", 1)
	current_tick = config.get_value("Progress", "ticks", 360)
	money = config.get_value("Economy", "yenes", 1000)
	user_name = config.get_value("Progress", "user_name", "null")
	customer_rate = config.get_value("Progress", "customer_rate", 10)
	tutorial_completed = config.get_value("Progress", "tutorial_completed", false)
	first_save = config.get_value("Progress", "fist_save", false)
	
	# --- CARGAR HISTORIAL (FORMA CORRECTA) ---
	var history_loaded = config.get_value("Progress", "score_history", [])
	GlobalLogistics.stars_history.assign(history_loaded) # Esto evita el error de Array

	# 2. RESTAURAR STAFF (Niveles y Estadísticas)
	var chef = $Areas/Kitchen/Chef
	var server = $Areas/Dinner/Server
	var hostess = $Areas/Dinner/Hostess

	chef.level = config.get_value("Staff", "lvl_chef", 1)
	server.level = config.get_value("Staff", "lvl_server", 1)
	hostess.level = config.get_value("Staff", "lvl_hostess", 1)

	chef.ticks_per_station = config.get_value("Staff", "chef_ticks", 2)
	server.ticks_per_action = config.get_value("Staff", "server_ticks", 1)
	server.move_speed = config.get_value("Staff", "server_speed", 8.0)

	hostess.stat_service = config.get_value("Staff", "hostess_service", 0.8)
	hostess.stat_comfort = config.get_value("Staff", "hostess_comfort", 0.2)
		
	# 4. LIMPIAR Y RECREAR PEATONES
	for p in get_tree().get_nodes_in_group("Customer"):
		p.queue_free()
	customers_on_street.clear()

	var saved_pedestrians = config.get_value("World", "pedestrians", [])
	for d in saved_pedestrians:
		var new = preload("res://Scenes/scnCustomer.tscn").instantiate()
		$Areas.add_child(new) 
		new.load_pedestrian_data(d)
		customers_on_street.append(new)

	# 5. RECONSTRUIR MENÚ
	GlobalLogistics.clean_menu()
	var paths = config.get_value("Menu", "paths", [])
	var prices = config.get_value("Menu", "prices", [])
	for i in range(paths.size()):
		var recipe_res = load(paths[i])
		if recipe_res:
			GlobalLogistics.add_to_menu(recipe_res, prices[i])
	
	# 6. ACTUALIZACIÓN VISUAL
	await get_tree().process_frame 
	
	label_money.text = "¥" + str(money)
	label_days.text = "Day " + str(day)
	
	var hours: int = int(current_tick / 60.0) 
	var minutes = current_tick % 60
	label_clock.text = "%02d:%02d" % [hours, minutes]

	# --- ACTUALIZACIÓN DEL RATE DINÁMICO ---
	var current_average = GlobalLogistics.get_current_average()
	if current_average > 0:
		$UI/Rate.text = "%.1f" % current_average + "⭐"
		update_difficulty_per_average(current_average)
	else:
		$UI/Rate.text = "0.0⭐"

	update_menu_visual()
	update_sunlight()
	
	var lvl = config.get_value("Progress", "lvl_furniture", 1)
	apply_visual_upgrade("dinner_lvl" + str(lvl))
	setup_seats() 

	write_message("Game Loaded.\nWelcome " + user_name + ".")

func update_difficulty_per_average(p_average: float):
	if p_average > 4.9: customer_rate = 1
	elif p_average > 4.6: customer_rate = 2
	elif p_average > 4.4: customer_rate = 3
	elif p_average > 4.3: customer_rate = 4
	elif p_average > 4.2: customer_rate = 5
	elif p_average > 4.0: customer_rate = 6
	elif p_average > 3.5: customer_rate = 7
	elif p_average > 3.0: customer_rate = 8
	elif p_average > 2.5: customer_rate = 10
	elif p_average > 1.1: customer_rate = 20
	else: customer_rate = 30 # Muy lento si te odayn

func upgrade_chef():
	var cost = 15000
	if money >= cost and $Areas/Kitchen/Chef.ticks_per_station > 0:
		money -= cost
		$Areas/Kitchen/Chef.ticks_per_station -= 1 # Ahora cocina más rápido
	write_message("Chef upgraded! (Faster)")

func upgrade_hostess():
	var cost = 10000
	if money >= cost:
		money -= cost
		$Areas/Dinner/Hostess.stat_service += 0.05 # Mejora el rating de los customers
		write_message("Hostess upgraded! (Better Service)")

func _on_btn_save_pressed() -> void:
	if first_save == true:
		highlight(btnSave, false)
	save_progress()

func apply_visual_upgrade(id_upgrade: String):
	# Ocultamos todos para asegurar limpieza
	$Areas/Dinner/Tiles/FurnitureLvl1.hide()
	$Areas/Dinner/Tiles/FurnitureLvl2.hide()
	$Areas/Dinner/Tiles/FurnitureLvl3.hide()
	$Areas/Dinner/Tiles/FurnitureLvl4.hide()
	$Areas/Dinner/Tiles/FurnitureLvl5.hide()
	$Areas/Dinner/Tiles/FurnitureLvl6.hide()

	match id_upgrade:
		"dinner_lvl1":
			$Areas/Dinner/Tiles/FurnitureLvl1.show()
		"dinner_lvl2":
			$Areas/Dinner/Tiles/FurnitureLvl2.show()
		"dinner_lvl3":
			$Areas/Dinner/Tiles/FurnitureLvl3.show()
		"dinner_lvl4":
			$Areas/Dinner/Tiles/FurnitureLvl4.show()
		"dinner_lvl5":
			$Areas/Dinner/Tiles/FurnitureLvl5.show()
		"dinner_lvl6":
			$Areas/Dinner/Tiles/FurnitureLvl6.show()
	
	# Llamamos a setup_seats SIN NÚMEROS. 
	# Ella sola leerá qué FurnitureLvl.show() hiciste arriba.
	setup_seats() 

func activate_new_seats(level: int):
	# Supongamos que las seats del level 2 se llaman "SeatLvl2_1", "SeatLvl2_2"...
	var container = $Areas/Dinner/SeatContainer
	for seat in container.get_children():
		# Si el user_name de la seat indica que pertenece a este level o anteriores
		if "Lvl" + str(level) in seat.user_name:
			if not seats_state.has(seat):
				seats_state[seat] = false # La habilitamos para el sistema de customers
				print("New chair enabled: ", seat.user_name)

func _on_upgrade_bought(node_item):
	if money >= node_item.upgrade_price:
		money -= node_item.upgrade_price
		
		# Aplicamos el cambio visual y activamos las seats
		apply_visual_upgrade(node_item.id_upgrade)
		
		# --- LA CLAVE ESTÁ AQUÍ ---
		# Forzamos al menú a borrar la recipe_card vieja y buscar la siguiente mejora
		update_upgrade_list() 
		
		write_message("Dinner upgraded!")
	else:
		write_message("Insufficient funds.")


func _on_btn_upgrades_pressed() -> void:
	if changes_allowed == false:
		write_message("You can't make changes when it's already open.")
		return
	if MenuModule.visible:
		return
	if not panelUpgrades.visible:
		# Si está oculto, lo actualizamos y mostramos
		update_upgrade_list()
		if not MenuModule.visible:
			panelUpgrades.show()
	else:
		# Si ya está visible, lo cerramos
		panelUpgrades.hide()

func update_upgrade_list():
	# 1. Limpiamos siempre al inicio
	for child in $UI/Upgrades/VBoxContainer.get_children():
		child.queue_free()

	# 2. Prioridad: ¿Ya tenemos el level MÁXIMO (Lvl 3)? 
	# Si es visible, no añadimos nada más (Menú vacío o mensaje de "Todo mejorado")

	if $Areas/Dinner/Tiles/FurnitureLvl6.visible:
		print("Max Level")
		return # Cerramos aquí para que no evalue el siguiente IF

	if $Areas/Dinner/Tiles/FurnitureLvl5.visible:
		var item5 = preload("res://Scenes/scnUpgradeCard.tscn").instantiate()
		item5.setup("Wood Chairs Lvl 6", 150000, "dinner_lvl6")
		item5.upgrade_bought.connect(_on_upgrade_bought)
		$UI/Upgrades/VBoxContainer.add_child(item5)
		return # Cerramos aquí para que no evalue el siguiente IF

	if $Areas/Dinner/Tiles/FurnitureLvl4.visible:
		var item4 = preload("res://Scenes/scnUpgradeCard.tscn").instantiate()
		item4.setup("Wood Chairs Lvl 5", 100000, "dinner_lvl5")
		item4.upgrade_bought.connect(_on_upgrade_bought)
		$UI/Upgrades/VBoxContainer.add_child(item4)
		return # Cerramos aquí para que no evalue el siguiente IF

	if $Areas/Dinner/Tiles/FurnitureLvl3.visible:
		var item3 = preload("res://Scenes/scnUpgradeCard.tscn").instantiate()
		item3.setup("Wood Chairs Lvl 4", 75000, "dinner_lvl4")
		item3.upgrade_bought.connect(_on_upgrade_bought)
		$UI/Upgrades/VBoxContainer.add_child(item3)
		return # Cerramos aquí para que no evalue el siguiente IF

	# 3. ¿Tenemos el level 2? Entonces ofrecemos el 3
	if $Areas/Dinner/Tiles/FurnitureLvl2.visible:
		var item2 = preload("res://Scenes/scnUpgradeCard.tscn").instantiate()
		item2.setup("Wood Chairs Lvl 3", 40000, "dinner_lvl3")
		item2.upgrade_bought.connect(_on_upgrade_bought)
		$UI/Upgrades/VBoxContainer.add_child(item2)
		return # Cerramos aquí para que no evalue el siguiente IF

	# 4. Si llegamos aquí es que solo tenemos el level 1, ofrecemos el 2
	if $Areas/Dinner/Tiles/FurnitureLvl1.visible:
		var item = preload("res://Scenes/scnUpgradeCard.tscn").instantiate()
		item.setup("Wood Chairs Lvl 2", 20000, "dinner_lvl2")
		item.upgrade_bought.connect(_on_upgrade_bought)
		$UI/Upgrades/VBoxContainer.add_child(item)

func _on_btn_staff_upgrades_pressed() -> void:
	if changes_allowed == false:
		write_message("You can't make changes when it's already open.")
		return
	if RecipeModule.visible:
		return
	if not panelStaffUpgrades.visible:
		# Si el panel de furniture está abierto, lo cerramos para que no se solapen
		panelUpgrades.hide() 
		
		update_staff_list() # <--- Esta es la función key
		panelStaffUpgrades.show()
	else:
		panelStaffUpgrades.hide()

func update_staff_list():
	# 1. Limpiamos el container para que no se acumulen recipe_cards viejas
	var container = $UI/StaffUpgrades/VBoxContainer
	for child in container.get_children():
		child.queue_free()

	# 2. Definimos los data de nuestro personal actual
	var personal_list = [
		{"node": $Areas/Kitchen/Chef, "id": "upgrade_chef", "user_name": "Chef"},
		{"node": $Areas/Dinner/Server, "id": "upgrade_server", "user_name": "Server"},
		{"node": $Areas/Dinner/Hostess, "id": "upgrade_hostess", "user_name": "Hostess"}
	]

	# 3. Creamos una recipe_card por cada empleado
	for data in personal_list:
		var item = preload("res://Scenes/scnUpgradeCard.tscn").instantiate()
		
		# Calculamos un price que suba con el level: Lvl 1=5000, Lvl 2=10000...
		var next_price = data["node"].level * 20000 
		var text_btn = "Upgrade " + data["user_name"] + " (Lvl " + str(data["node"].level + 1) + ")"
		
		# Configuramos la recipe_card (Usamos los user_names de variables que pusimos en scr_Upgrade_Card.gd)
		item.setup(text_btn, next_price, data["id"])
		
		# IMPORTANTE: Conectamos la señal de la recipe_card a la función de compra del Staff
		item.upgrade_bought.connect(_on_upgrade_staff_bought)
		
		container.add_child(item)

func _on_upgrade_staff_bought(node_item):
	# Usamos los user_names de variables exactos de tu scr_Upgrade_Card
	if money >= node_item.upgrade_price:
		money -= node_item.upgrade_price
		
		# Aplicamos la mejora según el ID que le dimos en update_staff_list
		match node_item.id_upgrade:
			"upgrade_chef":
				$Areas/Kitchen/Chef.level_up_chef()
			"upgrade_server":
				$Areas/Dinner/Server.level_up_server()
			"upgrade_hostess":
				$Areas/Dinner/Hostess.level_up_hostess()
		
		# Refrescamos la lista para que el price suba y el text diga "Lvl X+1"
		update_staff_list()
		write_message("Staff upgraded!")
	else:
		write_message("Not enough ¥ to upgrade staff.")

func _on_btn_open_pressed() -> void:
	btnOpen.hide()
	current_tick = 660
