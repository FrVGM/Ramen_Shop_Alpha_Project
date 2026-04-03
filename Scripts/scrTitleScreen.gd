extends Control

@onready var music_bar: ProgressBar = $Settings/VBoxContainer/HBoxContainer2/MusicProgress
@onready var sfx_bar: ProgressBar = $Settings/VBoxContainer/HBoxContainer/SFXProgress

@onready var hover_sound = preload("res://Audio/SFX/MouseEntered.wav")
@onready var click_sound = preload("res://Audio/SFX/MouseClick.wav") 

@onready var main = get_node_or_null("/root/Main")

func _ready():
	await get_tree().process_frame
	if main.tutorial_completed == true:
		$DeleteGame.show()
	else:
		$DeleteGame.hide()
	# Solo dejamos la lógica de música, SFX y visuales de botones
	var todos_los_botones = find_children("*", "Button", true)
	for boton in todos_los_botones:
		boton.pressed.connect(_on_any_button_pressed)
		boton.mouse_entered.connect(_on_any_button_hover)
	
	# Ocultamos el Load Game si no lo vas a usar
	$Options/btnLoadGame.hide()
	
	var idxM = AudioServer.get_bus_index("Music")
	music_bar.value = db_to_linear(AudioServer.get_bus_volume_db(idxM))
	music_bar.value = 0.5
	sync_music()
	
	var idxS = AudioServer.get_bus_index("SFX")
	sfx_bar.value = db_to_linear(AudioServer.get_bus_volume_db(idxS))
	sfx_bar.value = 0.5
	sync_sfx()

	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		$Settings/VBoxContainer/btnResolution.text = "Fullscreen"
	else:
		$Settings/VBoxContainer/btnResolution.text = "Windowed"

func _on_btn_new_game_pressed() -> void:
	# Si el name sigue siendo "User" (valor por defecto de tu Parte 1), pedimos el name
	if $"../..".user_name == "User" or $"../..".user_name == "":
		$YourName.show() # Muestra el cuadro para escribir el name
	else:
		# Si ya tiene name, simplemente despausa y cierra el menú
		$"../../Timer".start()
		$"../../UI".show()
		queue_free()
	

func _on_btn_load_game_pressed() -> void:
	$Timer.start()
	queue_free()

func _on_btn_start_pressed() -> void:
	if $"../..".user_name == "" or $"../..".user_name == "User":
		$"../..".user_name = "Chef Ramen" # Nombre por defecto si no pone nada
	
	$"../../Timer".start()
	$"../../UI".show()
	queue_free()

func _on_btn_yes_pressed() -> void:
	$Timer.start()
	queue_free()

func _on_btn_no_pressed() -> void:
	$NewGame.hide()

func _on_btn_settings_pressed() -> void:
	$Settings.show()

func _on_btn_quit_pressed() -> void:
	$Settings.hide()

func _on_btn_close_pressed() -> void:
	get_tree().quit()

func _on_btn_resolution_pressed() -> void:
	if $Settings/VBoxContainer/btnResolution.text == "Windowed":
		# Cambiar a Fullscreen
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		$Settings/VBoxContainer/btnResolution.text = "Fullscreen"
	else:
		# Cambiar a Windowed
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		$Settings/VBoxContainer/btnResolution.text = "Windowed"

func _on_btn_language_pressed() -> void:
	var btn = $Settings/VBoxContainer/btnLanguage
	
	if btn.text == "English":
		btn.text = "Español"
		TranslationServer.set_locale("es")
	elif btn.text == "Español":
		btn.text = "日本語"
		TranslationServer.set_locale("ja")
	else:
		btn.text = "English"
		TranslationServer.set_locale("en")

func _on_btn_m_minus_pressed() -> void:
	music_bar.value -= 0.1
	sync_music()

func _on_btn_m_plus_pressed() -> void:
	music_bar.value += 0.1 # La barra ya tiene sus propios límites (min/max)
	sync_music()

func _on_btn_sfx_minus_pressed() -> void:
	sfx_bar.value -= 0.1
	sync_sfx()

func _on_btn_sfx_plus_pressed() -> void:
	sfx_bar.value += 0.1
	sync_sfx()

func sync_music():
	# Buscamos el índice al vuelo y usamos el valor de la barra directamente
	var idx = AudioServer.get_bus_index("Music")
	AudioServer.set_bus_volume_db(idx, linear_to_db(music_bar.value))

func sync_sfx():
	# Buscamos el índice al vuelo y usamos el valor de la barra directamente
	var idx = AudioServer.get_bus_index("SFX")
	AudioServer.set_bus_volume_db(idx, linear_to_db(sfx_bar.value))


func _on_line_edit_text_submitted(new_text: String) -> void:
	# Si el texto no está vacío, guardamos y cerramos el cuadro
	if new_text != "":
		$"../..".user_name = new_text
		_on_btn_start_pressed()
		
		# _on_btn_new_game_pressed() 


func _on_line_edit_text_changed(new_text: String) -> void:
	# Actualiza el name en el nodo padre cada vez que escribes una letra
	$"../..".user_name = new_text
	
	# Opcional: Si borra todo, podrías resetearlo a "User"
	if new_text == "":
		$"../..".user_name = "User"

func _on_any_button_hover():
	var asp = AudioStreamPlayer.new()
	asp.stream = hover_sound
	asp.bus = "SFX"
	add_child(asp)
	asp.play()
	asp.finished.connect(asp.queue_free)

func _on_any_button_pressed():
	# 1. Creamos el reproductor
	var asp = AudioStreamPlayer.new()
	asp.stream = click_sound
	asp.bus = "SFX"
	
	# 2. IMPORTANTE: Añadirlo al árbol ANTES de darle a play
	add_child(asp)
	
	# 3. Verificamos si el nodo está dentro del árbol antes de sonar
	if asp.is_inside_tree():
		asp.play()
		asp.finished.connect(asp.queue_free)
	else:
		asp.queue_free() # Si no entró al árbol, lo borramos de una

func _on_delete_game_pressed() -> void:
	var path_save = "user://savegame.cfg"
	var dir = DirAccess.open("user://")
	
	if dir:
		# 1. Borrar el archivo de configuración (.cfg)
		if dir.file_exists(path_save):
			dir.remove(path_save)
			print(".cfg file deleted.")

		# 2. Borrar todas las recipes individuales (.tres)
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.begins_with("recipe_") and file_name.ends_with(".tres"):
				dir.remove(file_name)
				print("Recipe deleted: ", file_name)
			file_name = dir.get_next()
		dir.list_dir_end()

	# 3. RESET DE VARIABLES EN MEMORIA (Importante para que no queden datos viejos)
	GlobalLogistics.menu_of_day = []
	main.money = 1000
	# Si tienes un tutorial, asegúrate de resetearlo aquí también
	main.tutorial_completed = false 
	
	# 4. REINICIO TOTAL
	# Esto recarga la escena principal y limpia todo el árbol de nodos
	get_tree().change_scene_to_file("res://Scenes/scnWorkday.tscn") 
