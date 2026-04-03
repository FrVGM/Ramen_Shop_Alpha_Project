extends Node2D

@export var pos_idle: Marker2D
@export var pos_bar: Marker2D

var state = "IDLE"
var current_order = null
var ticks_in_state = 0
@export var ticks_per_action = 1 # 1 tick para recoger, 1 para dejar

@onready var main = get_parent().get_parent().get_parent()
var target_position: Vector2

var level: int = 1

var move_speed: float = 8.0 # Velocidad inicial del lerp

func _ready():
	if pos_idle:
		target_position = pos_idle.global_position

func _process(delta):
	# Movimiento visual siempre hacia el objetivo
	global_position = global_position.lerp(target_position, move_speed * delta)
	
	# Si el bowl es hijo del Server (agarrado), se mueve con él automáticamente.
	# Si no quieres usar add_child, mantén esta lógica:
	if current_order != null and is_instance_valid(current_order["bowl"]):
		if current_order["bowl"].get_parent() == self:
			current_order["bowl"].position = Vector2(0, -15) # Posición local

func ticks_process():
	if state == "IDLE":
		if main.orders_ready_to_serve.size() > 0:
			var candidate = main.orders_ready_to_serve.pop_front()
			# VALIDACIÓN CRÍTICA: Si el customer se fue mientras el chef cocinaba
			if is_instance_valid(candidate.customer) and candidate.customer.state != "LEAVING":
				current_order = candidate
				state = "GO_TO_BAR"
				target_position = pos_bar.global_position
			else:
				# Si el customer no es válido, borramos el bowl de la barra para que no estorbe
				if is_instance_valid(candidate.bowl): 
					candidate.bowl.queue_free()
				print("SERVER: Cliente se fue, tirando comida de la barra.")
			return

	if state == "GO_TO_BAR":
		if global_position.distance_to(pos_bar.global_position) < 25.0:
			#print("SERVER: En la barra. Empezando a recoger...")
			state = "PICK_BOWL" # <--- CAMBIO: Primero recoge
			ticks_in_state = 0
			# Agarrar el bowl visualmente
			var bowl = current_order["bowl"]
			if is_instance_valid(bowl):
				bowl.reparent(self) 
				bowl.position = Vector2(0, 0) 
		return

	if state == "PICK_BOWL":
		ticks_in_state += 1
		if ticks_in_state >= ticks_per_action:
			#print("SERVER: Recogido. Yendo al customer...")
			state = "GO_TO_CUSTOMER" # <--- CAMBIO: Ahora camina
			if is_instance_valid(current_order["customer"]):
				target_position = current_order["customer"].assign_seat.global_position
		return

	if state == "GO_TO_CUSTOMER":
		if is_instance_valid(current_order["customer"]):
			# IMPORTANTE: Apuntamos al CLIENTE, no a la seat.
			target_position = current_order["customer"].global_position
			
			if global_position.distance_to(target_position) < 30.0:
				state = "DELIVERING"
				ticks_in_state = 0
		else:
			# Si el customer se fue mientras el server caminaba:
			if is_instance_valid(current_order["bowl"]): 
				current_order["bowl"].queue_free()
			current_order = null
			state = "IDLE"

	if state == "DELIVERING":
		ticks_in_state += 1
		if ticks_in_state >= ticks_per_action:
			deliver_to_customer()

func deliver_to_customer():
	var customer = current_order["customer"]
	var bowl = current_order["bowl"]
	
	if is_instance_valid(customer) and is_instance_valid(bowl):
		# 1. El bowl pasa a la mesa (Dining)
		bowl.reparent(main.get_node("Areas/Dinner"))
		
		# 2. DETECTAR ORIENTACIÓN POR NOMBRE
		var seat = customer.assign_seat
		var final_offset = Vector2.ZERO
		
		# Buscamos la "R" o "L" en el nombre (ignorando mayúsculas)
		if "_R_" in seat.name.to_upper() or "SEATR" in seat.name.to_upper():
			# Ajusta estos números para que el bowl quede bien a la DERECHA
			final_offset = Vector2(16, -42) 
		else:
			# Tu valor original para la IZQUIERDA
			final_offset = Vector2(-16, -42) 
		
		# 3. POSICIONAR
		bowl.global_position = seat.global_position + final_offset
		
		# 4. Vínculo con el customer
		customer.bowl_eating = bowl 
		customer.receive_food()
	
	# Reset
	current_order = null
	state = "IDLE"
	target_position = pos_idle.global_position


func level_up_server():
	level += 1
	# Aumentamos la fuerza del lerp para que llegue antes a las mesas
	move_speed += 2.5 
	# Si tardaba mucho en recoger/entregar, lo bajamos a 1
	if ticks_per_action > 1:
		ticks_per_action = 1
	print("Server Lvl ", level, " velocidad: ", move_speed)
