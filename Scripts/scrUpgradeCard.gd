extends Panel

signal upgrade_bought(node_item)

var id_upgrade: String = ""
var upgrade_price: int = 0

func setup(p_name: String, p_price: int, p_id: String):
	id_upgrade = p_id
	upgrade_price = p_price
	
	# Asegúrate de que estas rutas sean exactas a tu escena de tarjeta
	$HBoxContainer/Name.text = p_name
	$HBoxContainer/Price.text = "¥" + str(p_price)

# ESTA es la función que debes conectar al botón de la tarjeta en el Editor
func _on_button_pressed() -> void:
	# Emitimos la señal para que el Main la reciba
	emit_signal("upgrade_bought", self)
	
	# OPCIONAL: Si quieres que se guarde la partida JUSTO al comprar:
	# var main = get_tree().root.find_child("Main", true, false)
	# if main: main.guardar_progreso_diario()
