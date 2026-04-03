extends Node2D

# Estos valores luego los puedes subir con mejoras (Upgrades)
var stat_speed: int = 1    # Ticks que tarda en procesar a un customer
var stat_service: float = 0.8 # Calidad del servicio (0.0 a 1.0)
var stat_comfort: float = 0.2 # Bono de comodidad extra

var ticks_waiting: int = 0
var busy: bool = false

@onready var main = get_parent().get_parent().get_parent() # Ajusta hasta llegar al script Main

var level: int = 1

func tick_process():
	if not busy:
		# 1. ¿Hay alguien en la fila y hay seats libres?
		if main.wait_line.size() > 0:
			var seat = main.find_free_seat()
			if seat != null:
				busy = true
				ticks_waiting = 0
	
	if busy:
		ticks_waiting += 1
		# 2. Cuando termina sus ticks de "trabajo", deja pasar al customer
		if ticks_waiting >= stat_speed:
			let_pass_customer()

func let_pass_customer():
	var seat = main.find_free_seat()
	if seat != null and main.wait_line.size() > 0:
		var customer = main.wait_line.pop_front()
		
		# --- AQUÍ LE "INYECTAMOS" LOS PUNTOS AL CLIENTE ---
		# El customer guardará estos valores para su rating final
		customer.received_service_score = stat_service
		customer.received_comfort_bonus = stat_comfort
		
		# Mandamos al customer a su seat (lo que antes hacía el Main)
		customer.assign_to_seat(seat)
		main.update_all_wait_line_positions()
	
	busy = false
	$TextGlobe.show()
	$Timer.start()

func _on_timer_timeout() -> void:
	$TextGlobe.hide()

func level_up_hostess():
	level += 1
	# Mejora los puntos que le "regala" al customer al entrar
	stat_service = clamp(stat_service + 0.05, 0.0, 1.2)
	stat_comfort = clamp(stat_comfort + 0.05, 0.0, 1.0)
	# A level 5, ya no hace esperar al customer en la puerta
	if level >= 5: stat_speed = 0
	print("Hostess Lvl ", level, " upgrades services to ", stat_service)
