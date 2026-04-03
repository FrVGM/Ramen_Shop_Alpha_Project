extends Node
class_name StaffManager

# Función para generar los datos de cada empleado de forma limpia
static func get_staff_data(main_node: Node) -> Array:
	return [
		{
			"node": main_node.get_node("Areas/Kitchen/Chef"), 
			"id": "upgrade_chef", 
			"name": "Chef",
			"upgrade_func": "level_up_chef"
		},
		{
			"node": main_node.get_node("Areas/Dinner/Server"), 
			"id": "upgrade_server", 
			"name": "Server",
			"upgrade_func": "level_up_server"
		},
		{
			"node": main_node.get_node("Areas/Dinner/Hostess"), 
			"id": "upgrade_hostess", 
			"name": "Hostess",
			"upgrade_func": "level_up_hostess"
		}
	]

static func calculate_price(level: int) -> int:
	return level * 20000
