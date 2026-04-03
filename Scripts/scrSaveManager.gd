extends Node
class_name SaveManager

const SAVE_PATH = "user://savegame.cfg"

static func save_game(main_node: Node):
	var config = ConfigFile.new()
	
	# --- SECCIÓN: PROGRESO (Usamos main_node. para todo) ---
	config.set_value("Progress", "day", main_node.day)
	config.set_value("Progress", "ticks", main_node.current_tick)
	config.set_value("Progress", "season", main_node.season)
	config.set_value("Progress", "user_name", main_node.user_name)
	config.set_value("Progress", "customer_rate", main_node.customer_rate)
	config.set_value("Progress", "tutorial_completed", main_node.tutorial_completed)
	config.set_value("Progress", "fist_save", main_node.first_save)
	
	config.set_value("Progress", "total_stars", GlobalLogistics.stars_accumulated)
	config.set_value("Progress", "total_served_customers", GlobalLogistics.total_served_customers)
	config.set_value("Progress", "score_history", GlobalLogistics.stars_history)
	
	# --- SECCIÓN: ECONOMÍA ---
	config.set_value("Economy", "yenes", main_node.money)
	config.set_value("Economy", "seats_extras", main_node.seats_state.size() - 7)
	
	# --- SECCIÓN: STAFF (Buscamos los nodos dentro de main_node) ---
	var chef = main_node.get_node("Areas/Kitchen/Chef")
	var server = main_node.get_node("Areas/Dinner/Server")
	var hostess = main_node.get_node("Areas/Dinner/Hostess")
	
	config.set_value("Staff", "lvl_chef", chef.level)
	config.set_value("Staff", "lvl_server", server.level)
	config.set_value("Staff", "lvl_hostess", hostess.level)
	config.set_value("Staff", "chef_ticks", chef.ticks_per_station)
	config.set_value("Staff", "server_ticks", server.ticks_per_action)
	config.set_value("Staff", "server_speed", server.move_speed)
	config.set_value("Staff", "hostess_service", hostess.stat_service)
	config.set_value("Staff", "hostess_comfort", hostess.stat_comfort)

	# --- SECCIÓN: MUNDO (PEATONES) ---
	var pedestrians_data = []
	# Usamos main_node.get_tree() para buscar en el grupo
	for p in main_node.get_tree().get_nodes_in_group("Customer"):
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
	
	# --- SECCIÓN: MUEBLES ---
	var level_to_save = get_current_furniture_level(main_node)
	config.set_value("Progress", "lvl_furniture", level_to_save)
	
	config.save(SAVE_PATH)
	main_node.write_message("Game saved at tick: " + str(main_node.current_tick))

static func load_game(main_node: Node):
	var config = ConfigFile.new()
	if config.load(SAVE_PATH) != OK: 
		print("Can not find a save file.")
		return

	# 1. ASIGNACIÓN (Escribimos en las variables del main_node)
	main_node.day = config.get_value("Progress", "day", 1)
	main_node.current_tick = config.get_value("Progress", "ticks", 360)
	main_node.money = config.get_value("Economy", "yenes", 1000)
	main_node.user_name = config.get_value("Progress", "user_name", "null")
	main_node.customer_rate = config.get_value("Progress", "customer_rate", 10)
	main_node.tutorial_completed = config.get_value("Progress", "tutorial_completed", false)
	main_node.first_save = config.get_value("Progress", "fist_save", false)
	
	var history_loaded = config.get_value("Progress", "score_history", [])
	GlobalLogistics.stars_history.assign(history_loaded)

	# 2. RESTAURAR STAFF
	var chef = main_node.get_node("Areas/Kitchen/Chef")
	var server = main_node.get_node("Areas/Dinner/Server")
	var hostess = main_node.get_node("Areas/Dinner/Hostess")

	chef.level = config.get_value("Staff", "lvl_chef", 1)
	server.level = config.get_value("Staff", "lvl_server", 1)
	hostess.level = config.get_value("Staff", "lvl_hostess", 1)
	chef.ticks_per_station = config.get_value("Staff", "chef_ticks", 2)
	server.ticks_per_action = config.get_value("Staff", "server_ticks", 1)
	server.move_speed = config.get_value("Staff", "server_speed", 8.0)
	hostess.stat_service = config.get_value("Staff", "hostess_service", 0.8)
	hostess.stat_comfort = config.get_value("Staff", "hostess_comfort", 0.2)
		
	# 4. PEATONES
	for p in main_node.get_tree().get_nodes_in_group("Customer"):
		p.queue_free()
	main_node.customers_on_street.clear()

	var saved_pedestrians = config.get_value("World", "pedestrians", [])
	for d in saved_pedestrians:
		var new = preload("res://Scenes/scnCustomer.tscn").instantiate()
		main_node.get_node("Areas").add_child(new) 
		new.load_pedestrian_data(d)
		main_node.customers_on_street.append(new)

	# 5. MENÚ
	GlobalLogistics.clean_menu()
	var paths = config.get_value("Menu", "paths", [])
	var prices = config.get_value("Menu", "prices", [])
	for i in range(paths.size()):
		var recipe_res = load(paths[i])
		if recipe_res:
			GlobalLogistics.add_to_menu(recipe_res, prices[i])
	
	# 6. ACTUALIZACIÓN VISUAL (Usamos main_node. para los labels)
	await main_node.get_tree().process_frame 
	
	main_node.label_money.text = "¥" + str(main_node.money)
	main_node.label_days.text = "Day " + str(main_node.day)
	
	var hours: int = int(main_node.current_tick / 60.0) 
	var minutes = main_node.current_tick % 60
	main_node.label_clock.text = "%02d:%02d" % [hours, minutes]

	var current_average = GlobalLogistics.get_current_average()
	if current_average > 0:
		main_node.get_node("UI/Rate").text = "%.1f" % current_average + "⭐"
		main_node.update_difficulty_per_average(current_average)
	else:
		main_node.get_node("UI/Rate").text = "0.0⭐"

	main_node.update_menu_visual()
	main_node.update_sunlight()
	
	var lvl = config.get_value("Progress", "lvl_furniture", 1)
	main_node.apply_visual_upgrade("dinner_lvl" + str(lvl))
	main_node.setup_seats() 

	main_node.write_message("Game Loaded.\nWelcome " + main_node.user_name + ".")

static func get_current_furniture_level(main_node: Node) -> int:
	for n in range(6, 0, -1):
		var node = main_node.get_node_or_null("Areas/Dinner/Tiles/FurnitureLvl" + str(n))
		if node and node.visible:
			return n
	return 1
