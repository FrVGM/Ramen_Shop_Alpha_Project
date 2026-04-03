extends Node2D

var data: CustomerData
var order: Dictionary
var assign_seat: Node2D
var ticks_waiting: int = 0
var total_service_ticks: int = 0 # <--- NUEVA: Acumula todo el tiempo real
# CAMBIO: Empezamos en state WAIT_LINE
var state: String = "WAIT_LINE" 

var entry_position: Vector2 
var position_target: Vector2
var wait_line_index: int = 0

var ticks_eated: int = 0
var ticks_to_delete: int = 4

var position_leave: Vector2 # Nueva variable

var is_angry: bool = false # Nueva variable arriba
var is_angry_wait_line: bool = false # NUEVA: Para el rating final

var customers_on_street: Array = []

@onready var main = get_parent().get_parent()

var bowl_eating: Node2D = null 

var received_service_score: float = 0.0
var received_comfort_bonus: float = 0.0

func _ready():
	add_to_group("Customer")
	
	# Al nacer, pregunta al Main qué alpha le toca:
	if "alpha_customers_global" in main:
		modulate.a = main.alpha_customers_global

func change_my_alpha(new_value: float):
	modulate.a = new_value

# CAMBIO: El setup ya no recibe la seat, recibe el índice de la wait_line
func setup(p_data, p_order, p_index):
	data = p_data
	order = p_order
	wait_line_index = p_index
	
	$Sprite2D.texture = data.texture
	var name_legible = CustomerData.Type.keys()[data.customer_type]
	$Label.text = name_legible.replace("_", " ")
	
	# Buscamos los puntos de referencia en el parent (Room)
	entry_position = get_parent().get_parent().get_node("Dinner/Entrada").global_position
	var base_wait_line_pos = get_parent().get_node("Wait_Line_Position").global_position
	
	# Aparecer directamente en su lugar de la wait_line
	global_position = base_wait_line_pos + Vector2(wait_line_index * 16, wait_line_index * 8)
	position_target = global_position
	state = "WAIT_LINE"
	
	# Obtenemos la posición del nuevo marcador
	var marker_leave = get_parent().get_node_or_null("Leave_Position")
	if marker_leave:
		position_leave = marker_leave.global_position
	else:
		# Por si olvidas poner el marker en alguna escena, que no rompa
		position_leave = global_position + Vector2(-100, 0)
		

func setup_street(p_data, _p_final_pos):
	data = p_data
	$Sprite2D.texture = data.texture
	$Label.text = get_name_legible()
	
	# IMPORTANTE: El objetivo inicial es donde aparece el customere
	position_target = global_position 
	state = "STREET"
	$LabelPuntos.hide()
	
	show_craving_visual()


func enter_to_restaurant(p_order, p_index):
	order = p_order
	wait_line_index = p_index
	
	remove_from_group("Customer")
	add_to_group("DinnerCustomer")
	
	if main:
		# Si 'alpha_customeres_global' es un número (0.4), usa '.a'
		modulate.a = main.alpha_dinner
	
	# 1. ACTUALIZAR POSICIONES CRÍTICAS ANTES DE CAMBIAR EL ESTADO
	# Esto evita que al activar el lerp en _process el objetivo sea (0,0)
	entry_position = get_parent().get_node("Dinner/Entrada").global_position
	var base_wait_line_pos = get_parent().get_node("Outside/Wait_Line_Position").global_position
	
	# Obtenemos la posición del nuevo marcador de salida por si acaso
	var marker_leave = get_parent().get_node_or_null("Leave_Position")
	if marker_leave:
		position_leave = marker_leave.global_position
	
	# 2. DEFINIR EL OBJETIVO DE LA WAIT_LINE
	position_target = base_wait_line_pos + Vector2(wait_line_index * 16, wait_line_index * -8)
	
	# 3. CAMBIAR ESTADO (esto activa el lerp en _process hacia la position_target)
	state = "WAIT_LINE"
	
	
	# Limpieza visual
	$LabelPuntos.hide()

func _process(delta: float):
	if state == "STREET": return 

	if position_target != Vector2.ZERO:
		# Si se amontonan, sube este 10.0 a 20.0 para que lleguen rápido a su sitio
		global_position = global_position.lerp(position_target, 6.0 * delta)

func update_wait_line_position(new_index: int):
	wait_line_index = new_index
	var wait_line_node = get_parent().get_node_or_null("Areas/Outside/WaitLine_Position")
	
	if wait_line_node:
		# Aumentamos los valores para que se vea separación real en isométrico
		# Prueba con 32 y 16 (o -16 según tu eje Y)
		var offset = Vector2(wait_line_index * 32, wait_line_index * -16) 
		position_target = wait_line_node.global_position + offset


func assign_to_seat(p_seat: Node2D):
	assign_seat = p_seat
	state = "ENTRY"
	
	# Cargar el StyleBox desde tu carpeta de archivos
	var my_style = load("res://Resources/BlackGlobe.tres")
	
	# Aplicarlo al nodo Panel (que se llama Text)
	$TextGlobe/Text.add_theme_stylebox_override("panel", my_style)
	$TextGlobe/Arrow/Panel.add_theme_stylebox_override("panel", my_style)

	$TextGlobe.show()
	$TextGlobeTimer.start()
	position_target = entry_position
	wait_line_index = -1 

func get_name_legible():
	return CustomerData.Type.keys()[data.customer_type].replace("_", " ")

# --- LÓGICA DE TICKS ---

func advance_tick():
	if state == "STREET":
		$TextGlobe/Text/Texto.hide()
		# 1. Calculamos el nuevo destino de forma exacta
		position_target -= Vector2(16, -8)
		
		# 2. Matamos cualquier movimiento anterior para evitar "luchas" de posición
		var tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_IDLE)
		
		# 3. Transición fluida con limpieza de jitter
		# Usamos TRANS_LINEAR para que el paso sea constante
		tween.tween_property(self, "global_position", position_target, main.get_node("Timer").wait_time).set_trans(Tween.TRANS_LINEAR)
		
		var marker = get_parent().get_node_or_null("Outside/Marker_Left")
		if marker:
			# Usamos X e Y para seguir la diagonal isométrica
			if global_position.x < marker.global_position.x and global_position.y < marker.global_position.y:
				
				if main and "customers_on_street" in main:
					main.customers_on_street.erase(self)
					
				queue_free()
		# Ejemplo: 20% de probabilidad de que vuelva a pensar en comida cada tick
		if not $TextGlobe.visible and randf() < 0.02:
			show_craving_visual()
		
	if state == "WAIT_LINE":
		# Solo cuenta el tiempo en la wait_line
		ticks_waiting += 1
		if ticks_waiting > data.patience_ticks:
			$LabelPuntos.text = "💢"
			$LabelPuntos.show()
			is_angry_wait_line = true # Se marca de por vida para el rating
		return
	

# NUEVO: Si el customere aún no está comiendo ni saliendo, el tiempo de servicio cuenta
	if state in ["WAIT_LINE", "ENTRY", "AT_DOOR", "MOVING_TO_SEAT", "WAITING"]:
		total_service_ticks += 1

	if state == "LEAVING":
		ticks_to_delete -= 1
		if ticks_to_delete <= 0:
			# Borramos el bowl usando la referencia que nos dio el Server
			if is_instance_valid(bowl_eating):
				bowl_eating.queue_free()
			
			main.release_seat(assign_seat)
			queue_free()
		return
	
	# PASO 1: El Main le dio seat. Le ordenamos ir a la PUERTA.
	if state == "ENTRY":
		$TextGlobe/Text/Texto.show()
		$TextGlobe/Text/IconoVisual.hide()
		position_target = entry_position 
		state = "AT_DOOR" # Nuevo state de transición
		return 

	# PASO 2: Verificamos si ya "llegó" visualmente a la puerta
	if state == "AT_DOOR":
		# Solo si está a menos de 5px de la puerta, le permitimos ir a la seat
		if global_position.distance_to(entry_position) < 5.0:
			position_target = assign_seat.global_position
			state = "MOVING_TO_SEAT"
		return # Si no ha llegado, se queda en este state un tick más

	# PASO 3: Ya está en la seat, ahora sí pide comida
	if state == "MOVING_TO_SEAT":
		if global_position.distance_to(assign_seat.global_position) < 5.0:
			state = "WAITING"
			main.ask_to_chef(self)
			ticks_waiting = 0 # IMPORTANTE: Reseteamos para la espera del Chef
			# Si estaba enojado por la wait_line, ocultamos el emoji un momento 
			# para que el Chef tenga su propia oportunidad de fallar.
			$LabelPuntos.hide() 
		return

	if state == "WAITING":
		ticks_waiting += 1 # Aquí cuenta SOLO cuánto tarda el Chef
		if ticks_waiting > data.patience_ticks:
			$LabelPuntos.text = "💢"
			$LabelPuntos.show()
			is_angry = true # Enojo por el Chef
		return


	if state == "EATING":
		ticks_eated += 1 # El customere da un bocado (pasa 1 tick)
		
		# Comparamos: ¿Ya comió lo que dice su ficha (ej: 10)?
		if ticks_eated >= data.eating_ticks:
			check_out()
		return

# --- EL RESTO DE TUS FUNCIONES SE MANTIENEN IGUAL ---

func receive_food():
	state = "EATING"
	ticks_waiting = 0

func check_out():
	# 1. Preparamos toda la info que el RatingEngine necesita
	var data_bundle = {
		"customer_data": data,
		"recipe": order["resource"],
		"price": order["price"],
		"temp": main.current_temp,
		"ticks_taken": total_service_ticks,
		"is_angry": is_angry or is_angry_wait_line,
		"shop_comfort": main.current_shop_comfort,
		"bonus_service": received_service_score,
		"bonus_comfort": received_comfort_bonus
	}
	
	# 2. Llamamos a la clase global RatingEngine (la que creamos antes)
	var stars = RatingEngine.calculate_final_rating(data_bundle)
	
	# 3. Registramos el pago en el Main
	main.payment_register(order["price"], stars, order["resource"].recipe_name)
	
	# 4. Nos vamos
	leave_store(stars)


func leave_store(puntos: float):
	var score_label = $LabelPuntos 
	score_label.text = "%.1f★" % puntos
	score_label.show()
	
	if puntos >= 4.5: score_label.label_settings.font_color = Color.LIME_GREEN
	elif puntos < 2.5: score_label.label_settings.font_color = Color.CRIMSON
	else: score_label.label_settings.font_color = Color.GOLD

	main.release_seat(assign_seat)
	
	position_target = entry_position
	state = "LEAVING"
	ticks_to_delete = 3

func leave_wait_line(message_p: String = ""): 
	# 1. Avisamos al Main para que reacomode a los que vienen detrás en la fila
	if main.has_method("customer_leaves_wait_line"):
		main.customer_leaves_wait_line(self)
	
	# 2. Si por algún error raro ya tenía silla asignada, la liberamos
	if assign_seat != null:
		main.release_seat(assign_seat)
		assign_seat = null 

	# 3. Lo mandamos al punto de salida (la calle)
	position_target = position_leave
	state = "LEAVING"
	ticks_to_delete = 4 
	
	# 4. Mostramos el mensaje (ej: "💢" o "Very slow!")
	if message_p == "":
		$LabelPuntos.hide()
	else:
		$LabelPuntos.text = message_p
		$LabelPuntos.show()

func _exit_tree():
	# Si el customere desaparece por CUALQUIER motivo (borrado manual, error, cambio de escena)
	# debemos asegurar que la seat no se quede bloqueada.
	if is_instance_valid(assign_seat):
		if main.has_method("release_seat"):
			main.release_seat(assign_seat)


func _on_timer_timeout() -> void:
	$TextGlobe.hide()

func save_pedestrian_data() -> Dictionary:
	return {
		"res_path": data.resource_path,
		"pos": global_position,
		"obj": position_target,
		"state": state
	}

func load_pedestrian_data(d: Dictionary):
	data = load(d["res_path"])
	global_position = d["pos"]
	position_target = d["obj"]
	state = d["state"]
	
	# Restaurar visuales
	$Sprite2D.texture = data.texture
	$Label.text = get_name_legible()
	$LabelPuntos.hide()


func show_craving_visual():
	# 1. Referencia al icono dentro del globo
	# Ajusta la ruta según tu jerarquía (ej: $TextGlobe/Text/IconoFavorito)
	var icon_sprite = $TextGlobe/Text/IconoVisual 
	
	# 2. Elegir la lista de favoritos según la temperatura del Main
	var favs: Array[Ingredient] = []
	var temp = main.current_temp
	
	if temp > 27.0: favs = data.favorites_hot
	elif temp < 10.0: favs = data.favorites_cold
	else: favs = data.favorites_tempered
	
	# 3. Lógica de visualización (como en tu TarjetaReceta)
	if favs.size() > 0:
		var craving = favs.pick_random()
		icon_sprite.texture = craving.texture
		
		# --- LÓGICA DE SILUETA INTERMEDIA ---
		if craving.name in GlobalLogistics.discovered_ingredients:
			icon_sprite.modulate = Color.WHITE # Color original
		else:
			# Usamos un gris muy oscuro (0.2 en cada canal R, G, B)
			# Esto permite ver la silueta y sombras, pero no el color real
			icon_sprite.modulate = Color(0.0, 0.0, 0.0, 0.282) 
		
		$TextGlobe.show()
		$TextGlobeTimer.start()
