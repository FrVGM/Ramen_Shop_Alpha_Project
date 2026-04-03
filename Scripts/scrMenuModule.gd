extends Control

@onready var grid_container = $Panel/ScrollContainer/GridContainer
var recipe_card_scene = preload("res://Scenes/scnRecipeCard.tscn") # Cargamos el molde

signal closed_menu  # Definimos la señal

@onready var hover_sound = preload("res://Audio/SFX/MouseEntered.wav")
@onready var click_sound = preload("res://Audio/SFX/MouseClick.wav") 

func _ready():
	# Busca TODOS los buttones que sean descendientes del grid_container
	# "*" significa cualquier nombre, "Button" es la clase
	var all_buttons = $".".find_children("*", "Button", true)
	
	for button in all_buttons:
		button.pressed.connect(_on_any_button_pressed)
		button.mouse_entered.connect(_on_any_button_hover)
	load_all_recipes()

# En MenuModule.gd

func load_all_recipes():
	# 1. Limpieza inicial (USA SOLO ESTA)
	for child in grid_container.get_children():
		child.free() 

	var recipe_list: Array[RecipeResource] = []
	
	# 2. Escaneo de archivos
	var dir = DirAccess.open("user://")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if file_name.ends_with(".tres") and file_name.begins_with("recipe_"):
				var path = "user://" + file_name
				# Usamos CACHE_MODE_REPLACE para que sea instantáneo
				var recipe = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE) as RecipeResource
				if recipe:
					recipe_list.append(recipe)
			file_name = dir.get_next()
		dir.list_dir_end()

	# 3. Ordenar
	recipe_list.sort_custom(func(a, b): 
		return a.get_total_cost() < b.get_total_cost()
	)
	
	# --- AQUÍ HABÍA UN SEGUNDO BUCLE DE LIMPIEZA QUE DEBES BORRAR ---
	# (Si dejas el queue_free aquí, borrarás las cards según se crean)
		
	# 4. Instanciar cards finales
	for recipe_item in recipe_list:
		var new_card = recipe_card_scene.instantiate()
		grid_container.add_child(new_card)
		new_card.setup_card(recipe_item)
		
		var btn = new_card.get_node("VBoxContainer/ButtonAdd")
		var sb_sale = new_card.get_node("VBoxContainer/SpinBoxSale")
		
		# Limpiar señales y conectar con el precio del SpinBox
		for c in btn.pressed.get_connections(): 
			btn.pressed.disconnect(c.callable)
		
		btn.pressed.connect(func(): _confirm_slot_selection(recipe_item, int(sb_sale.value)))

func _confirm_slot_selection(selected_recipe: RecipeResource, spinbox_price: int):
		# --- AÑADE ESTO: Limpiar brillos de todas las cards del selector ---
	for card in grid_container.get_children():
		var btn = card.get_node_or_null("VBoxContainer/ButtonAdd")
		if btn:
			highlight_button(btn, false) # Apagamos el material de Glow
	
	var idx = GlobalLogistics.selected_slot
	
	# GUARDAMOS EL PRECIO REAL que viene de la card elegida
	GlobalLogistics.add_to_menu(selected_recipe, spinbox_price, idx)
	
	# Refrescamos el Main
	var main_node = get_tree().root.find_child("Main", true, false)
	if main_node:
		main_node.update_menu_visual()
		
	if main_node.tutorial_completed == false:
		highlight_button($"../MenuM_Button", true)


func _on_done_pressed() -> void:
	closed_menu.emit() # Avisamos que terminamos de configurar
	self.hide()

func highlight_button(button: Control, activated: bool) -> void:
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
	var asp = AudioStreamPlayer.new()
	asp.stream = click_sound
	asp.bus = "SFX"
	add_child(asp)
	asp.play()
	# Se elimina solo al terminar para no dejar basura en el árbol de nodes
	asp.finished.connect(asp.queue_free)

func highlight_first_recipe_card_available():
	# Esperamos un frame para que el GridContainer termine de acomodar los childs
	await get_tree().process_frame
	
	if grid_container.get_child_count() > 0:
		var first_card = grid_container.get_child(0)
		# Buscamos el botón "Add to Menu" dentro de esa card
		var btn = first_card.get_node_or_null("VBoxContainer/ButtonAdd")
		if btn:
			highlight_button(btn, true)
