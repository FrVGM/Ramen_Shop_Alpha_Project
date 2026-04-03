# RecipeSlot.gd
extends Panel

@onready var visual = $VBoxContainer/RamenVisual
@onready var label_user_name = $VBoxContainer/LabelNombre
@onready var label_cost = $VBoxContainer/LabelCosto
@onready var btnAdd = $ButtonAdd # O el nombre de tu botón
@onready var main = $/root/Main

var accumulated_sales = 0
var recipe_reference: RecipeResource

func set_recipe_card(recipe: RecipeResource, sale_price: int = 0):
	recipe_reference = recipe
	
	if recipe == null:
		label_user_name.text = "Empty Slot"
		label_cost.text = "¥0"
		btnAdd.text = "+"
		btnAdd.modulate = Color.WHITE
		for s in visual.get_children(): if s is Sprite2D: s.hide()
		return

	# Si hay recipe, ponemos la X roja
	label_user_name.text = recipe.recipe_name
	btnAdd.text = "X"
	btnAdd.modulate = Color.RED
	
	# Dibujar visual (Bowl + Ingredientes)
	for s in visual.get_children(): if s is Sprite2D: s.hide()
	var bowl = visual.get_node_or_null("Bowl")
	if bowl: bowl.show()
	for cat in ["Bowl", "Broth", "Noodles", "Veggie", "Egg", "Protein", "Garnish"]:
		var item = recipe.ingredients.get(cat)
		var sprite = visual.get_node_or_null(cat)
		if item and sprite:
			sprite.texture = item.texture
			sprite.show()
	
	# CAMBIO AQUÍ: Si el sale_price es mayor a 0, mostramos ese. 
	# Si no, mostramos el costo base.
	if sale_price > 0:
		label_cost.text = "Price: %d¥" % sale_price
	else:
		label_cost.text = "Price: %d¥" % recipe.get_total_cost()
	
	label_user_name.text = recipe.recipe_name
	btnAdd.text = "X"
	btnAdd.modulate = Color.RED
	accumulated_sales = 0 # <--- IMPORTANTE: Limpiar al asignar nueva recipe


func _on_button_add_pressed():
	var menu_module = $"../../MenuModule"
	var id_slot = int(name.right(1)) - 1
	
	# 1. ACTUALIZAR EL ID
	GlobalLogistics.selected_slot = id_slot
	
	# --- AÑADE ESTO AQUÍ ---
	# Forzamos al Main a repintar los bordes para que el verde se mueva ya mismo
	var main_node = get_tree().root.find_child("Main", true, false)
	
	if main_node:
		main_node.update_slot_state(false) # false = modo edición
		
	if not main_node.tutorial_completed:
		main_node.destacar_boton($/root/Main/UI/HBoxContainer/RecipeSlot1, false)
		
	# 2. LÓGICA DE ELIMINAR
	if recipe_reference != null and menu_module.visible:
		GlobalLogistics.menu_of_day[id_slot] = {"resource": null, "price": 0}
		if main_node:
			main_node.update_slot_state(false) 
			main_node.update_menu_visual()
		return

	# 3. LÓGICA DE SELECCIONAR/CAMBIAR
	if menu_module and menu_module.visible:
		menu_module.load_all_recipes()
		# --- AÑADE ESTA LÍNEA AQUÍ ---
		if not main_node.tutorial_completed:
			menu_module.highlight_first_card_available()

func simulation_mode(fixed_price: int):
	# 1. Escondemos el botón (ya sea X o +) para que no se pueda editar en simulación
	var btn = get_node_or_null("ButtonAdd")
	if btn: btn.hide()
	
	# 2. Mostramos el price final que viene del GlobalLogistics
	label_cost.text = "Price: ¥%d" % fixed_price
	
	# 3. Activamos el contador de ventas (Sold)
	var label_sold = get_node_or_null("VBoxContainer/LabelSold")
	if label_sold:
		label_sold.show()
		label_sold.text = "Sold: 0"
		label_sold.modulate = Color.CYAN # Color llamativo para las ventas

# Función para resetear el slot si el jugador lo borra con la "X"
func slot_clean():
	recipe_reference = null
	label_user_name.text = "Empty Slot"
	label_cost.text = "¥0"
	var btn = get_node_or_null("ButtonAdd")
	if btn:
		btn.show()
		btn.text = "+"
		btn.modulate = Color.WHITE
	# Ocultamos los ingredients del ramen
	for s in visual.get_children():
		if s is Sprite2D: s.hide()

# En RecipeSlot.gd
func update_visual_counter():
	# Buscamos el label (asegúrate que el nombre coincida: LabelSold o LabelGanancia)
	var label_sales = get_node_or_null("VBoxContainer/LabelSold")
	if label_sales:
		label_sales.text = "Sold: %d" % accumulated_sales
		label_sales.show() # Por si estaba oculto
