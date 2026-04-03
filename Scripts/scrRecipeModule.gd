extends Control

const SCN_INGREDIENT_CARD = preload("res://Scenes/scnIngredientCard.tscn")

# --- CONFIGURACIÓN ---
@export var path_ingredients: String = "res://Ingredients/"
var current_recipe: RecipeResource = RecipeResource.new()
var active_category: String = ""

# --- NODOS ---
@onready var grid_ingredients = $FlowContainer/VFlowContainer/IngredientPage/GridContainer
@onready var label_category = $FlowContainer/VFlowContainer/IngredientPage/IngredientTitle
@onready var label_total = $FlowContainer/VFlowContainer2/RecipePage/TotalCost
@onready var bowl_visual = $FlowContainer/VFlowContainer2/RecipePage/Bowl
@onready var line_edit_name = $FlowContainer/VFlowContainer2/RecipePage/NameEdit
@onready var load_sub_menu = $FlowContainer/VFlowContainer2/RecipePage/LoadSubMenu
@onready var grid_recipes = $FlowContainer/VFlowContainer2/RecipePage/LoadSubMenu/ScrollContainer/GridContainer
const SCN_RECIPE_CARD = preload("res://Scenes/scnRecipeCard.tscn")

@onready var main = get_node("/root/Main")

signal recipe_closed

func _ready() -> void:
	# Espera un frame para que Main ejecute su _ready() y cargue variables
	await get_tree().process_frame
	if not main.tutorial_completed:
		highlight_button($"../RecipeM_Button", false)
		highlight_button(%tab_Bowl, true)
	connect_side_tabs()
	print(main.tutorial_completed)

# 1. NAVEGACIÓN (SideTabs)
func connect_side_tabs():
	# Buscamos los buttones dentro de SideTabs/VBoxContainer
	var container_Tabs = $FlowContainer/HFlowContainer/SideTabs/VBoxContainer
	for btn in container_Tabs.get_children():
		if btn is Button:
			# El name del botón debe ser "tab_Broth", "tab_Noodles", etc.
			var clean_name = btn.name.replace("tab_", "")
			btn.pressed.connect(load_category.bind(clean_name))

# 2. CARGA DINÁMICA (Aquí ocurre la magia)
func load_category(category: String):
	active_category = category
	label_category.text = category.to_upper()
	
	# 1. Limpiar el grid
	for n in grid_ingredients.get_children():
		n.queue_free()
	
	# 2. Creamos una lista temporal para guardar los ingredients encontrados
	var filter_ingredients_list: Array[Ingredient] = []
	
	# 3. Leer la carpeta de ingredients
	var dir = DirAccess.open(path_ingredients)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			# CAMBIO VITAL: Detectar .remap (para el .exe) o .tres (para el editor)
			if file_name.ends_with(".tres") or file_name.ends_with(".tres.remap"):
				# Limpiamos el name para que 'load' no se confunda
				var clean_path = path_ingredients + file_name.replace(".remap", "")
				
				var res = load(clean_path) as Ingredient
				if res and res.category == category:
					filter_ingredients_list.append(res)
			
			file_name = dir.get_next()
	
	# 4. --- EL TRUCO DEL ORDENADO ---
	# Comparamos el price de 'a' con el de 'b'
	filter_ingredients_list.sort_custom(func(a, b): 
		return a.price < b.price
	)
	
	# 5. Instanciar las cards ya ordenadas por price
	for ing in filter_ingredients_list:
		instance_ingredient_card(ing)

# 1. Agrega esta variable al inicio de tu script para rastrear categorías
var processed_categories = {}

func instance_ingredient_card(ing: Ingredient):
	var card = SCN_INGREDIENT_CARD.instantiate()
	grid_ingredients.add_child(card)
	card.setup(ing)
	
	var button_in_card = card.get_node("btnContainer")
	
	# Guardamos la categoría en el botón para identificarlo luego
	button_in_card.set_meta("category", ing.category)
	button_in_card.add_to_group("ingredient_buttons")

	# --- LÓGICA DE DESTACADO ÚNICO ---
	# Solo destacamos si es la PRIMERA VEZ que vemos esta categoría en el bucle
	if not processed_categories.has(ing.category):
		if not main.tutorial_completed:
			highlight_button(button_in_card, true)
		processed_categories[ing.category] = true 
	else:
		if not main.tutorial_completed:
			highlight_button(button_in_card, false)

	# --- CONEXIÓN DE SEÑAL ---
	button_in_card.pressed.connect(func():
		# Al tocar cualquier botón, apagamos TODOS los de su misma categoría
		turnoff_category_highlight(ing.category)
		_on_selected_ingredient(ing)
	)

# 2. Nueva función para limpiar los destaques por grupo
func turnoff_category_highlight(name_cat: String):
	var all_buttons = get_tree().get_nodes_in_group("ingredient_buttons")
	for btn in all_buttons:
		if btn.get_meta("category") == name_cat:
			if not main.tutorial_completed:
				highlight_button(btn, false)
	if active_category == "Bowl":
		if not main.tutorial_completed:
			highlight_button(%tab_Broth, true)
	if active_category == "Broth":
		if not main.tutorial_completed:
			highlight_button(%tab_Noodles, true)
	if active_category == "Noodles":
		if not main.tutorial_completed:
			highlight_button(%NameEdit, true)


# 3. LÓGICA DE SELECCIÓN Y VISUALIZACIÓN
func _on_selected_ingredient(ing: Ingredient):
	# Guardamos el ingredient en el diccionario de la recipe
	current_recipe.ingredients[active_category] = ing
	# Actualizamos el Bowl visualmente
	# Buscamos el Sprite2D que se llame igual que la categoría (ej: "Broth")
	var visual_layer = bowl_visual.get_node_or_null(active_category)
	if visual_layer:
		visual_layer.texture = ing.texture
		visual_layer.show()
	
	update_total_price()

func update_total_price():
	var total = 0
	for ing in current_recipe.ingredients.values():
		if ing: total += ing.price
	label_total.text = "Total: " + str(total) + "¥"

# 4. BOTONES DE ACCIÓN FINAL
func _on_btn_save_pressed():
	if line_edit_name.text.is_empty(): 
		print("Error: Name is empty")
		return
	
	# 1. Preparamos el recurso
	current_recipe.recipe_name = line_edit_name.text
	var name_file = line_edit_name.text.validate_filename()
	var path = "user://recipe_" + name_file + ".tres"
	
	# --- EL TRUCO DEL DUPLICATE ---
	# Guardamos una copia para que Godot no bloquee el archivo original
	var backup = current_recipe.duplicate()
	ResourceSaver.save(backup, path)
	print("Succesful Save: ", path)
	
	# 2. CERRAMOS EL SUBMENÚ (como ya hacías)
	load_sub_menu.hide()
	
	# 3. ACTUALIZAMOS EL MENUMODULE (El de los slots)
	# Buscamos el menú de ventas en el árbol de nodos
	var sale_menu = get_tree().root.find_child("MenuModule", true, false)
	if sale_menu:
		# Llamamos a su función de carga que usa CACHE_MODE_REPLACE
		sale_menu.load_all_recipes()
		print("MenuModule updated with new recipe!")
	
	if not main.tutorial_completed:
		highlight_button($FlowContainer/VFlowContainer2/RecipePage/HBoxContainer/btnSave, false)
		highlight_button($"../RecipeM_Button", true)
		main.first_recipe = true


func _on_btn_erase_pressed():
	# Resetear todo
	current_recipe = RecipeResource.new()
	for layer in bowl_visual.get_children():
		if layer is Sprite2D: layer.hide()
	line_edit_name.text = ""
	update_total_price()

func _on_btn_load_pressed() -> void:
	load_sub_menu.show()
	for n in grid_recipes.get_children(): n.queue_free()
	
	var recipe_list: Array[RecipeResource] = []
	var dir = DirAccess.open("user://")
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres") and file_name.begins_with("recipe_"):
				# --- EL CAMBIO VITAL ESTÁ AQUÍ ---
				# Usamos CACHE_MODE_REPLACE para obligar a Godot a leer el disco y ver los cambios reales
				var path = "user://" + file_name
				var res = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE) as RecipeResource
				
				if res: recipe_list.append(res)
			file_name = dir.get_next()
	
	recipe_list.sort_custom(func(a, b): 
		return a.get_total_cost() < b.get_total_cost()
	)

	for recipe in recipe_list:
		var card = SCN_RECIPE_CARD.instantiate()
		grid_recipes.add_child(card)
		card.set_card(recipe) # Pasamos a modo edición si lo tienes
		
		var btn_select = card.get_node("VBoxContainer/ButtonAdd") # Revisa si es BotonAdd o ButtonAdd
		
		# --- PASO CLAVE: Desconectar la lógica de los slots ---
		if btn_select.pressed.is_connected(card._on_button_add_pressed):
			btn_select.pressed.disconnect(card._on_button_add_pressed)
		
		# --- Ahora conectamos la carga limpia ---
		btn_select.pressed.connect(func(): 
			_load_recipe_to_bowl(recipe)
			load_sub_menu.hide() # Cerramos el selector al cargar
		)

func _load_recipe_to_bowl(recipe: RecipeResource):
	# Al duplicar, nos aseguramos de que los cambios en el editor no toquen el archivo original
	current_recipe = recipe.duplicate(true) 
	line_edit_name.text = current_recipe.recipe_name
	
	# Refrescar visuales
	var valid_categories = ["Bowl", "Broth", "Noodles", "Protein", "Veggie", "Egg", "Garnish"]
	for cat in valid_categories:
		var ingredient = current_recipe.ingredients.get(cat)
		var sprite_layer = bowl_visual.get_node_or_null(cat)
		if sprite_layer:
			if ingredient and ingredient.texture:
				sprite_layer.texture = ingredient.texture
				sprite_layer.show()
			else:
				sprite_layer.texture = null
				sprite_layer.hide()
	
	update_total_price()
	load_sub_menu.hide()

func _on_btn_done_pressed():
	# Esto es lo que "dispara" la señal para que el objeto padre sepa que terminaste
	recipe_closed.emit() 
	queue_free() #self.hide() # O queue_free()

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

func _on_tab_bowl_pressed() -> void:
	if not main.tutorial_completed:
		highlight_button(%tab_Bowl, false)

func _on_tab_broth_pressed() -> void:
	if not main.tutorial_completed:
		highlight_button(%tab_Broth, false)

func _on_tab_noodles_pressed() -> void:
	if not main.tutorial_completed:
		highlight_button(%tab_Noodles, false)

func _on_name_edit_text_changed(_new_text: String) -> void:
	if not main.tutorial_completed:
		highlight_button(%NameEdit, false)
		highlight_button($FlowContainer/VFlowContainer2/RecipePage/HBoxContainer/btnSave, true)
