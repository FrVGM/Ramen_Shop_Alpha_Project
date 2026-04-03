extends VBoxContainer
@onready var vslider = $VSlider
@onready var price_label = $PriceLabel
@export var costo_por_punto = 0.7 
@onready var popup_label = $"../../NotePopUp"
@export var suffix = "%"

var y_centro_original : float

func _ready():
	popup_label.visible = false
	y_centro_original = popup_label.position.y

func _on_v_slider_value_changed(value: float) -> void:
	# --- TU LÓGICA VERTICAL (SE QUEDA IGUAL) ---
	var costo_total = value * costo_por_punto
	price_label.text = "Cost: " + str(int(costo_total))  + "¥" 
	popup_label.text = str(int(value)) + suffix
	
	var ratio = (vslider.value - vslider.min_value) / (vslider.max_value - vslider.min_value)
	var factor_ajuste_v = 0.92  # Tu nuevo factor vertical
	var offset_y = (0.5 - ratio) * (vslider.size.y * factor_ajuste_v)
	
	popup_label.position.y = y_centro_original + offset_y

	# --- LÓGICA HORIZONTAL CORREGIDA ---
	# En lugar de usar el borde (global_position.x + size.x), 
	# buscamos el centro del slider y le sumamos un margen fijo.
	
	var centro_x_slider = vslider.global_position.x + (vslider.size.x / 2.0)
	
	# Ajusta este número (30.0) para separar el label del centro del slider.
	# Al ser desde el centro, no importa si el slider es gordo o flaco.
	var separacion_horizontal = 17.0 
	
	popup_label.global_position.x = centro_x_slider + separacion_horizontal



func _on_v_slider_drag_started() -> void:
	# Forzamos actualización de posición para que no aparezca en el slider anterior
	_on_v_slider_value_changed(vslider.value)
	popup_label.visible = true


func _on_v_slider_drag_ended(_value_changed: bool) -> void:
	popup_label.visible = false
