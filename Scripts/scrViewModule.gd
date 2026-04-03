extends Node
class_name ViewModule

static func move_to_kitchen(main: Node):
	# Posición y Nombres
	main.View.position = main.Area_Kitchen.position
	main.lblAreaName.text = "Kitchen"
	
	# Ocultar UI de otras áreas
	main.btnOpen.hide()
	main.hboxRecipeSlots.hide()
	main.btnMenuModule.hide()
	main.btnUpgrades.hide()
	main.MenuModule.hide()
	main.panelUpgrades.hide()
	
	# Mostrar UI de Kitchen
	main.btnStaffUpgrades.show()
	main.btnRecipeModule.show()
	main.btnSleep.visible = (main.current_tick >= 0 and main.current_tick <= 360)
	main.btnSave.visible = (main.current_tick >= 0 and main.current_tick <= 660)

	# --- GESTIÓN DE MUROS Y COLORES ---
	main.Area_Dinner.modulate = Color(1, 1, 1, 0.40)
	main.Area_Kitchen.modulate = Color(1, 1, 1, 1.0)
	
	# Escondemos muros específicos (WallsL)
	main.get_node("Areas/Dinner/Tiles/Walls1L").hide()
	main.get_node("Areas/Dinner/Tiles/Walls2L").hide()
	main.get_node("Areas/Dinner/Tiles/Walls3L").hide()
	
	# --- GESTIÓN DE ALPHAS (CLIENTES) ---
	main.alpha_dinner = 0.4
	main.get_tree().call_group("DinnerCustomer", "change_my_alpha", main.alpha_dinner)
	
	# --- TUTORIAL Y HIGHLIGHTS ---
	if not main.tutorial_completed:
		if main.btnArrowL.material != null:
			main.highlight(main.btnArrowL, false)
			main.highlight(main.btnRecipeModule, true)
	elif main.tutorial_completed and main.first_save == false:
		main.highlight(main.btnArrowL, false)
		main.highlight(main.btnSave, true)
		main.first_save = true

static func move_to_dinner(main: Node, direction: String):
	main.View.position = main.Area_Dinner.position
	main.lblAreaName.text = "Dinner"
	main.update_slot_state(true)
	
	# UI General
	main.btnRecipeModule.hide()
	main.btnStaffUpgrades.hide()
	main.btnSleep.hide()
	main.btnSave.hide()
	main.hboxRecipeSlots.show()
	main.btnMenuModule.show()
	main.btnUpgrades.show()
	
	# Lógica de botón OPEN
	main.btnOpen.visible = (main.current_tick >= 360 and main.current_tick < 660 and main.tutorial_completed)

	# --- VISUALES Y MUROS ---
	main.Area_Dinner.modulate = Color(1, 1, 1, 1)
	main.Area_Kitchen.modulate = Color(1, 1, 1, 0.40)
	
	if direction == "FROM_KITCHEN":
		main.get_node("Areas/Dinner/Tiles/Walls1L").show()
		main.get_node("Areas/Dinner/Tiles/Walls2L").show()
		main.get_node("Areas/Dinner/Tiles/Walls3L").show()
		if not main.tutorial_completed:
			if main.btnArrowR.material != null:
				main.highlight(main.btnArrowR, false)
				main.highlight(main.btnMenuModule, true)
	
	if direction == "FROM_OUTSIDE":
		main.get_node("Areas/Dinner/Tiles/Walls1F").hide()
		main.get_node("Areas/Dinner/Tiles/Walls2F").hide()
		main.get_node("Areas/Dinner/Tiles/Walls3F").hide()
		if main.tutorial_completed:
			main.highlight(main.btnStaffUpgrades, false)
			main.highlight(main.btnMenuModule, false)

	# --- GESTIÓN DE ALPHAS ---
	main.alpha_dinner = 1.0
	main.get_tree().call_group("DinnerCustomer", "change_my_alpha", 1.0)
	main.alpha_customers_global = 0.4
	main.get_tree().call_group("Customer", "change_my_alpha", 0.4)
	
	# Colores de día/noche (Dinner usa alpha reducido para los de afuera)
	main.color_day_a.a = 0.4
	main.color_night_a.a = 0.4

static func move_to_outside(main: Node):
	main.View.position = main.Area_Outside.position
	main.lblAreaName.text = "Outside"
	
	# UI
	main.btnMenuModule.hide()
	main.hboxRecipeSlots.hide()
	main.btnUpgrades.hide()
	main.btnOpen.hide()
	if main.MenuModule.visible:
		main.MenuModule.hide()
		main.TickCounter.wait_time = 0.3
	main.panelUpgrades.hide()

	# --- MUROS ---
	main.get_node("Areas/Dinner/Tiles/Walls1F").show()
	main.get_node("Areas/Dinner/Tiles/Walls2F").show()
	main.get_node("Areas/Dinner/Tiles/Walls3F").show()
	
	# --- COLORES Y ALPHAS ---
	main.color_day_a.a = 1.0
	main.color_night_a.a = 1.0
	main.alpha_customers_global = 1.0
	main.get_tree().call_group("Customer", "change_my_alpha", 1.0)
