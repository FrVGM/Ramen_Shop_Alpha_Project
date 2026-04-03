extends Node

var user_name = "User"
var current_tick = 360
var day = 1
var money: int = 1000
var money_at_start: int = 100
var season = "Spring"

var ramen_menu: Array[Dictionary] = []
var card_references: Dictionary = {} 

var seats_state: Dictionary = {} 
var customer_rate = 10
var first_save = false
var changes_allowed = true
var current_shop_comfort: float = 0.5  
var orders_ready_to_serve: Array = []
var first_recipe = false

@onready var hover_sound = preload("res://Audio/SFX/MouseEntered.wav")
@onready var click_sound = preload("res://Audio/SFX/MouseClick.wav") 

var tutorial_completed: bool = false

var total_served_customers = 0 
var total_stars = 0.0
#var quality_chef_bonus = 1.0
var calendar = CalendarModule.new()
var current_temp: float = 0.0
var delete_timer: Tween

var recipe_card_scene = preload("res://Scenes/scnRecipeCard.tscn")

var wait_line: Array = []
var customers_on_street: Array = []

const scnRECIPE = preload("res://Scenes/scnRecipeBook.tscn")
const scnMENU = preload("res://Scenes/scnMenuModule.tscn")

#const DISTANCE_X = 16 
var color_night = Color.from_hsv(227.0/360.0, 0.74, 0.34, 1)
var color_day = Color.from_hsv(227.0/360.0, 0.0, 1.0, 1)
var color_night_a = Color.from_hsv(227.0/360.0, 0.74, 0.34, 1)
var color_day_a = Color.from_hsv(227.0/360.0, 0.0, 1.0, 1)
var alpha_customers_global: float = 1.0
var alpha_dinner: float = 1.0

@onready var hboxRecipeSlots = $UI/HBoxContainer
@onready var label_clock: Label = $UI/Clock
@onready var label_money: Label = $UI/Money
@onready var label_days: Label = $UI/Days
@onready var label_ticks: Label = $Ticks
@onready var label_status: Label = $Areas/Outside/StatusLabel
@onready var label_endofday: Label = $UI/EndOfDay
@onready var label_customer: Label = $UI/Customer
@onready var label_text: Label = $UI/Text
@onready var label_weather: Label = $UI/Weather
@onready var Area_Dinner: Node2D = $Areas/Dinner
@onready var Area_Kitchen: Node2D = $Areas/Kitchen
@onready var Area_Outside: Node2D = $Areas/Outside
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

func _ready():
	$Areas/Dinner/Tiles/Walls1F.show()
	$Areas/Dinner/Tiles/Walls2F.show()
	$Areas/Dinner/Tiles/Walls3F.show()
	
	var all_buttons = $".".find_children("*", "Button", true)
	
	for button in all_buttons:
		button.pressed.connect(_on_any_button_pressed)
		button.mouse_entered.connect(_on_any_button_hover)

	load_game()
	print(tutorial_completed)
	if seats_state.is_empty():
		setup_seats()

	#Visual & UI
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
		
	#Audio
	AudioManager.play_daily_song(day)

func _process(_delta: float) -> void:
	var hours: int = int(current_tick / 60.0) 
	var minutes = current_tick % 60
	label_clock.text = "%02d:%02d" % [hours, minutes]
	label_clock.text += " | %.1f°C" % current_temp
	label_money.text = "¥" + str(money)
	label_days.text = "Day " + str(day)
	label_ticks.text = "Ticks: " + str(current_tick)
	current_temp = calendar.get_current_temperature(current_tick)

func setup_day():
	total_served_customers = 0
	total_stars = 0.0
	money_at_start = money
	calendar.generate_new_weather(season)
	
	if label_weather:
		label_weather.text = calendar.get_weather_emojis()

#AVANZAR TICKs
func _on_timer_timeout() -> void:
	current_tick += 1
	
	#From 00:00 is a new day, we call the end of the day
	if current_tick >= 1440:
		current_tick = 0
		end_day()
	
	update_sunlight()
	
	#Staff stays alert
	$Areas/Kitchen/Chef.ticks_process()
	$Areas/Dinner/Server.ticks_process()
	$Areas/Dinner/Hostess.tick_process()
	
	# Node movements
	for c in $Areas.get_children():
		if c.has_method("advance_tick"):
			c.advance_tick()

	# From 07:00 people starts walking on the street
	if current_tick >= 360:
		
		$UI/EndOfDay.hide()
		if randf() < 0.35: 
			spawn_visual_pedestrian()
	
	#From 23:00 the shop is closed
	if current_tick >= 1380:
		changes_allowed = true
		label_status.text = "Closed"
		label_status.add_theme_color_override("font_color", Color.RED)
		
	# Customer generation (From: 11:00 / To: 23:00)
	if current_tick >= 660 and current_tick < 1380:
		changes_allowed = false
		btnSave.hide()
		btnOpen.hide()
		label_status.text = "Open"
		label_status.add_theme_color_override("font_color", Color.LIME_GREEN)
		if current_tick % customer_rate == 0:
			generate_customer()

func everyone_finished_eating() -> bool:
	for c in $Areas/Outside.get_children():
		if c.has_method("advance_tick"):
			# If there's anyone who isn't a pedestrian and isn't already leaving, the day goes on
			if c.state != "STREET" and c.state != "LEAVING":
				return false
	return true

func spawn_visual_pedestrian():
	var config_day = calendar.get_config_for_day(day)
	
	var user_name_customer_key = RatingEngine.select_customer_per_probability(config_day)
	
	var new_pedestrian = preload("res://Scenes/scnCustomer.tscn").instantiate()
	$Areas.add_child(new_pedestrian)
	
	var right_pos = $Areas/Outside/Marker_Right.global_position
	var left_pos = $Areas/Outside/Marker_Left.global_position
	
	new_pedestrian.global_position = right_pos
	
	new_pedestrian.setup_street(GlobalLogistics.customer_database[user_name_customer_key], left_pos)
	
	customers_on_street.append(new_pedestrian)

func generate_customer():
	if wait_line.size() >= 10 or customers_on_street.is_empty():
		return

	# We calculate the middle point of the two positions
	var right_pos = $Areas/Outside/Marker_Right.global_position
	var left_pos = $Areas/Outside/Marker_Left.global_position
	var middle_point = (right_pos + left_pos) / 2.0

	# We search for the first candidate who hasn't yet passed the halfway point
	var candidate = null
	for i in range(customers_on_street.size()):
		var c = customers_on_street[i]
		if is_instance_valid(c) and c.global_position > middle_point:
			candidate = c
			customers_on_street.remove_at(i) # Lo sacamos de la lista de la calle
			break
	
	# If everyone has already passed the halfway point, no one can join in this tick
	if candidate == null:
		return

	var temp_of_moment = calendar.get_current_temperature(current_tick)
	var best_choice = RatingEngine.find_best_recipe_for_customer(candidate.data, ramen_menu, temp_of_moment)

	if best_choice == null:
		# If there's no dish, we return it to the street list so it can continue on its way
		customers_on_street.push_back(candidate) 
		return

	# If the line is full, no one else is allowed in.
	if wait_line.size() >= 10: 
		return

	# Here, we ONLY add it to the visual queue. We do NOT assign it a seat yet.
	wait_line.append(candidate)
	candidate.enter_to_restaurant(best_choice, wait_line.size() - 1)

	# We're making sure everyone knows their assigned spot so people don't crowd together
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
	var lvl = SaveManager.get_current_furniture_level(self)
	var limit = lvl + 2 # Si Lvl 1 -> 3 asientos, Lvl 6 -> 8 asientos (según tu lógica)
	
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
				
# Esta función la puedes dejar en Main.gd o donde prefieras
func reveal_recipe_ingredients(recipe: RecipeResource):
	for ing in recipe.ingredients.values():
		if ing != null:
			GlobalLogistics.discover_ingredient(ing.name)

func show_daily_forecast():
	# 1. Le pedimos las probabilidades al calendario
	var probs = calendar.get_config_for_day(day)
	var user_names_customers = ", ".join(probs.keys())
	
	# Obtenemos los emojis del weather
	var emojis = calendar.get_weather_emojis()
	
	# Formateamos el text: Emojis arriba y customers abajo
	var t = emojis + " FORECAST " + emojis
	label_customer.text = t + "\nCustomers: " + user_names_customers
	
	# El timer que ya tenías para limpiar el text
	get_tree().create_timer(5.0).timeout.connect(func(): label_customer.text = "")

func end_day():
	# 1. CÁLCULOS (Lo que hace el EconomyManager)
	var economy_data = {
		"money": money,
		"money_at_start": money_at_start,
		"day": day,
		"stars_average": GlobalLogistics.get_current_average()
	}
	var result = EconomyManager.calculate_day_summary(economy_data)
	
	# 2. APLICAR RESULTADOS
	money -= result.total_expenses
	label_endofday.text = result.summary_text
	label_endofday.show()
	$UI/Rate.text = "%.1f" % GlobalLogistics.get_current_average() + "⭐"

	# 3. LA "LIMPIEZA" (Lo que no debe faltar):
	day += 1 # Ya es mañana
	money_at_start = money # Nueva base para mañana
	
	reset_daily_menu() # Vaciamos el menú del día
	
	# Limpiamos las listas de clientes que quedaron
	var wait_line_copy = wait_line.duplicate()
	for c in wait_line_copy:
		if is_instance_valid(c): c.leave_wait_line("") 
	wait_line.clear()
	customers_on_street.clear()

	# 4. PREPARAR EL MAÑANA
	save_progress()
	update_difficulty_per_average(GlobalLogistics.get_current_average())
	setup_day()
	AudioManager.play_daily_song(day)
	# 5. EFECTO VISUAL (El que tenías de 6 segundos)
	var tween = create_tween()
	tween.tween_interval(6.0)
	tween.tween_property(label_endofday, "modulate:a", 0.0, 2.0)
	tween.tween_callback(label_endofday.hide)
	
	# 6. CHECK DE BANCARROTA
	if result.is_bankrupt:
		label_endofday.text += "\n[color=red]BANKRUPTCY![/color]"
		get_tree().paused = true

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
		# LÓGICA DE CLOSE/OPEN:
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
		
		
		$UI.add_child(recipe_instance)


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
		update_slot_state(false) # Al open, entramos en modo "Edición"

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

func _on_arrow_r_pressed() -> void:
	if View.position == Area_Kitchen.position:
		ViewModule.move_to_dinner(self, "FROM_KITCHEN")
	elif View.position == Area_Dinner.position:
		ViewModule.move_to_outside(self)

func _on_arrow_l_pressed() -> void:
	if View.position == Area_Outside.position:
		ViewModule.move_to_dinner(self, "FROM_OUTSIDE")
	elif View.position == Area_Dinner.position:
		ViewModule.move_to_kitchen(self)


func _on_btn_pause_pressed() -> void:
	var menu_escena = load("res://Scenes/scnTitleScreen.tscn")
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

func payment_register(amount: int, stars: float, recipe_name: String):
	# 1. Sumamos el dinero (esta variable vive en el Main)
	money += amount
	
	# 2. Registramos las estrellas en el Singleton (como ya hacías)
	GlobalLogistics.record_score(stars)
	
	# 3. Mostramos el efecto visual (la función del Tween que ya tienes)
	show_profit_text(amount)
	
	# 4. Actualizamos la tarjeta de la receta si existe
	if card_references.has(recipe_name):
		var recipe_card = card_references[recipe_name]
		recipe_card.accumulated_sales += 1
		recipe_card.update_visual_counter()

func _on_delete_customer_area_entered(area: Area2D) -> void:
	if area.is_in_group("Customer"):
		area.queue_free()

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

# En el Main.gd
func update_upgrade_list():
	# 1. Limpiamos el contenedor
	for child in $UI/Upgrades/VBoxContainer.get_children():
		child.queue_free()

	# 2. Obtenemos el nivel actual (un solo número del 1 al 6)
	var current_lvl = SaveManager.get_current_furniture_level(self)

	if current_lvl >= 6:
		print("Max Level reached")
		return

	# 3. Definimos los precios en una lista (Nivel 2, 3, 4, 5, 6)
	var prices = [20000, 40000, 75000, 100000, 150000]
	
	# El índice del precio es el nivel actual (porque empezamos en nivel 1)
	var next_price = prices[current_lvl - 1]
	var next_lvl = current_lvl + 1

	# 4. Creamos la tarjeta de mejora (UNA SOLA VEZ)
	var item = preload("res://Scenes/scnUpgradeCard.tscn").instantiate()
	item.setup("Wood Chairs Lvl " + str(next_lvl), next_price, "dinner_lvl" + str(next_lvl))
	item.upgrade_bought.connect(_on_upgrade_bought)
	
	$UI/Upgrades/VBoxContainer.add_child(item)

func _on_btn_staff_upgrades_pressed() -> void:
	if changes_allowed == false:
		write_message("You can't make changes when it's already open.")
		return
	if RecipeModule.visible:
		return
	if not panelStaffUpgrades.visible:
		panelUpgrades.hide() 
		
		update_staff_list()
		panelStaffUpgrades.show()
	else:
		panelStaffUpgrades.hide()

func update_staff_list():
	var container = $UI/StaffUpgrades/VBoxContainer
	for child in container.get_children(): child.queue_free()

	var staff_list = StaffManager.get_staff_data(self)

	for data in staff_list:
		var item = preload("res://Scenes/scnUpgradeCard.tscn").instantiate()
		var level = data["node"].level
		var next_price = StaffManager.calculate_price(level)
		
		item.setup("Upgrade " + data["name"] + " (Lvl " + str(level + 1) + ")", next_price, data["id"])
		item.upgrade_bought.connect(_on_upgrade_staff_bought)
		container.add_child(item)

func _on_upgrade_staff_bought(node_item):
	var staff_list = StaffManager.get_staff_data(self)
	var employee_data = null
	
	for data in staff_list:
		if data["id"] == node_item.id_upgrade:
			employee_data = data
			break

	if employee_data and money >= node_item.upgrade_price:
		money -= node_item.upgrade_price
		
		employee_data["node"].call(employee_data["upgrade_func"])
		
		update_staff_list()
		write_message(employee_data["name"] + " upgraded!")
	else:
		write_message("Not enough ¥.")

func _on_btn_open_pressed() -> void:
	btnOpen.hide()
	current_tick = 660

func save_progress():
	SaveManager.save_game(self)

func load_game():
	SaveManager.load_game(self)
