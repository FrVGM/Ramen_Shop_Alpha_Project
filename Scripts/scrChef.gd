# Chef.gd
extends Node2D

@export var pos_preparation_1: Marker2D
@export var pos_preparation_2: Marker2D

var order_queue: Array = []
var current_customer = null
var tick_process: int = 0
var target_position: Vector2 # Para el movimiento visual

@export var ticks_per_station: int = 2

@export var pos_bar: Marker2D
@onready var main = get_parent().get_parent().get_parent()

var level: int = 1 

func _ready():
	# Empezamos en la primera estación para que no salga volando al iniciar
	target_position = global_position

func _process(delta):
	# Interpolación simple para que el movimiento sea fluido entre estaciones
	global_position = global_position.lerp(target_position, 10 * delta)

func recibir_pedido(customer_node):
	order_queue.append(customer_node)

func ticks_process():
	if current_customer == null:
		if order_queue.size() > 0:
			current_customer = order_queue.pop_front()
			tick_process = 1 
			target_position = pos_preparation_1.global_position
		return

	# 1. ACTUALIZAR POSICIÓN SEGÚN EL TICK ACTUAL
	if tick_process <= ticks_per_station:
		target_position = pos_preparation_1.global_position
	
	elif tick_process <= (ticks_per_station * 2):
		target_position = pos_preparation_2.global_position
	
	elif tick_process <= (ticks_per_station * 3):
		if pos_bar:
			target_position = pos_bar.global_position

	# 2. ACCIÓN ESPECIAL SI ES EL ÚLTIMO TICK
	if tick_process == (ticks_per_station * 3):
		var bowl_scene = preload("res://Scenes/scnBowl.tscn").instantiate()
		
		# Ruta segura: Main (parent del parent del parent) -> Areas -> Dining
		# O mejor usamos la variable 'main' que ya tienes:
		var node_dining = main.get_node("Areas/Dinner") 
		
		if node_dining:
			node_dining.add_child(bowl_scene)
			bowl_scene.global_position = pos_bar.global_position
			
			# Notificamos al Main para que el Server lo vea
			main.orders_ready_to_serve.append({
				"bowl": bowl_scene, 
				"customer": current_customer
			})
			
			current_customer = null
			tick_process = 0
			return

	# 3. SUMAR TICK (Fuera de los IF de posición para que siempre avance)
	tick_process += 1

func deliver_food():
	# Esta función ya casi no se usa porque la lógica está en tick_process,
	# pero la mantenemos por seguridad.
	if is_instance_valid(current_customer):
		current_customer.receive_food()
	current_customer = null
	tick_process = 0

func level_up_chef():
	level += 1
	# Cada 2 leveles, el chef cocina 1 tick más rápido por estación
	if level % 2 == 0 and ticks_per_station > 1:
		ticks_per_station -= 1
	print("Chef Lvl ", level, " cooks at ", ticks_per_station, " t/e")
