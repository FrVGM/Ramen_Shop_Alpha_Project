extends Panel

# Referencias a nodes visuales
@onready var visual = $VBoxContainer/RamenVisual
@onready var label_name = $VBoxContainer/LabelName
# NUEVOS NODOS:
@onready var label_cost = $VBoxContainer/LabelCost # Asegúrate de que la ruta sea correcta
@onready var spinbox_sale = $VBoxContainer/SpinBoxSale # Asegúrate de que la ruta sea correcta
@onready var label_profit = $VBoxContainer/LabelProfit # Asegúrate de que la ruta sea correcta

var accumulated_sales: int = 0

var recipe_reference: RecipeResource # Guardamos la referencia a la recipe para los cálculos

@onready var hover_sound = preload("res://Audio/SFX/MouseEntered.wav")
@onready var sound_click = preload("res://Audio/SFX/MouseClick.wav") 

@onready var main = get_node("/root/Main")

enum Mode { DAY_MENU, RECIPE_EDIT, SIMULATION }

func _ready():
	# Busca TODOS los buttones que sean descendientes del contenedor
	# "*" significa cualquier nombre, "Button" es la clase
	var all_buttons = $".".find_children("*", "Button", true)
	
	for button in all_buttons:
		button.pressed.connect(_on_any_button_pressed)
		button.mouse_entered.connect(_on_any_button_hover)

func setup_card(recipe: RecipeResource, current_mode: Mode = Mode.DAY_MENU):
	recipe_reference = recipe
	label_name.text = recipe.recipe_name
	
	# --- Lógica de Sprite ---
	var categories = ["Bowl", "Broth", "Noodles", "Veggie", "Egg", "Protein", "Garnish"]
	for s in visual.get_children():
		if s is Sprite2D: s.hide()
	var bowl_sprite = visual.get_node_or_null("Bowl")
	if bowl_sprite: bowl_sprite.show()
	for cat in categories:
		var item = recipe.ingredients.get(cat)
		var sprite_node = visual.get_node_or_null(cat)
		if item != null and sprite_node:
			sprite_node.texture = item.texture
			sprite_node.show()
		elif sprite_node:
			sprite_node.hide()

	match current_mode:
		Mode.DAY_MENU:
			# Tamaño normal para el menú del día
			custom_minimum_size = Vector2(62, 136)
			spinbox_sale.show()
			$VBoxContainer/ButtonAdd.text = "Add to Menu"
			
		Mode.RECIPE_EDIT:
			# TAMAÑO MÁS PEQUEÑO para que quepan muchas en el menú de carga
			custom_minimum_size = Vector2(59, 100) 
			spinbox_sale.hide()
			label_profit.hide()
			$VBoxContainer/ButtonAdd.text = "📤"
			
		Mode.SIMULATION:
			# Tamaño para la simulación
			custom_minimum_size = Vector2(62, 136)
			spinbox_sale.hide()
			$VBoxContainer/ButtonAdd.hide()

	# --- Lógica de Costo y Ganancia ---
	var total_cost = recipe_reference.get_total_cost()
	label_cost.text = "Cost: %d¥" % total_cost
	
	# Configurar SpinBox:
	# Permitimos un price mínimo igual al cost
	spinbox_sale.min_value = total_cost 
	# Inicializamos el price de venta con una profit sugerida (ej. 50% extra)
	spinbox_sale.value = total_cost * 3
	spinbox_sale.max_value = 9999
	
	# Conectar la señal del SpinBox para actualizar la profit en tiempo real
	spinbox_sale.value_changed.connect(_on_spinbox_sale_value_changed)
	
	# Calcular la profit inicial
	update_profit()

func _on_spinbox_sale_value_changed(_value: float) -> void:
	highlight_button($VBoxContainer/SpinBoxSale, false)
	highlight_button($VBoxContainer/ButtonAdd, true)
	update_profit()

func update_profit() -> void:
	var sale_price = spinbox_sale.value
	var cost = recipe_reference.get_total_cost()
	var profit = sale_price - cost
	
	label_profit.text = "Profit: %d¥" % profit
	
	# Pequeño extra: cambiar el color si hay pérdida
	if profit < 0:
		label_profit.label_settings.font_color = Color.RED
	else:
		label_profit.label_settings.font_color = Color.GREEN

# En TarjetaReceta.gd

func _on_button_add_pressed():
	var menu_module = get_tree().root.find_child("MenuModule", true, false)
	
	# SI EL SELECTOR ESTÁ ABIERTO (Eligiendo recipe para el slot)
	if menu_module and menu_module.visible:
		if recipe_reference == null: return
		
		var price = recipe_reference.get_total_cost()
		# Guardamos en el Singleton pero NO llamamos a hide()
		if GlobalLogistics.add_to_menu(recipe_reference, price, GlobalLogistics.selected_slot):
			# Feedback visual para saber que se guardó
			modulate = Color(0.5, 1, 0.5) # Se pone verde un momento
			await get_tree().create_timer(0.2).timeout
			modulate = Color.WHITE
			
			# Actualizamos el fondo para ver el cambio mientras el menú sigue abierto
			if main: main.update_menu_visual()
	
	# SI EL SELECTOR ESTÁ CERRADO (Pulsando el slot vacío en el Main)
	else:
		var id_slot = int(name.right(1)) - 1
		GlobalLogistics.selected_slot = id_slot
		if menu_module:
			menu_module.load_all_recipes()
			menu_module.show()
			menu_module.highlight_first_card() 

func simulation_mode(fixed_price: int):
	highlight_button($VBoxContainer/SpinBoxSale, true)
	# Ocultamos lo que no sirve en la simulación
	if has_node("VBoxContainer/ButtonAdd"): $VBoxContainer/ButtonAdd.hide()
	if has_node("VBoxContainer/SpinBoxSale"): 
		$VBoxContainer/SpinBoxSale.hide()
	
	# Creamos un Label temporal o usamos uno existente para mostrar el price fijo
	# Si ya tienes un Label de price, simplemente le asignamos el valor
	label_cost.text = "Price: ¥%d" % fixed_price
	
	# Inicializamos el texto
	update_visual_counter()
	
func update_visual_counter():
	# Usamos el label de profit para mostrar las ventas
	label_profit.text = "Sold: %d" % accumulated_sales
	label_profit.label_settings.font_color = Color.CYAN # Un color que destaque

func highlight_button(button: Control, activated: bool) -> void:
	if activated:
		# 1. Cargamos el material (.tres)
		var my_material = load("res://Glow.tres")
		
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
	add_child(asp)
	asp.play()
	asp.finished.connect(asp.queue_free)

func _on_any_button_pressed():
	var asp = AudioStreamPlayer.new()
	asp.stream = sound_click
	add_child(asp)
	asp.play()
	# Se elimina solo al terminar para no dejar basura en el árbol de nodes
	asp.finished.connect(asp.queue_free)

func load_mode():
	$VBoxContainer/ButtonAdd.text = "EDIT"
	$VBoxContainer/SpinBoxSale.hide()
	$VBoxContainer/LabelGanancia.hide()
