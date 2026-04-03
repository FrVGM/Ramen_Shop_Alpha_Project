extends Resource
class_name Ingredient

@export_group("Visual & Meta")
@export var name: String
@export var price: int
@export var texture: Texture2D
@export_enum("Bowl", "Broth", "Noodles", "Protein", "Veggie", "Egg", "Garnish") var category: String

@export_group("Quality & Flags")
@export_range(0, 10) var freshness: int = 10 # Calidad base del ingrediente
@export var is_vegetarian: bool = false

@export_group("Cold, Neutral or Hot")
@export_range(0.0, 1.0, 0.1) var thermal_density: float = 0.5 
# 0.0 = Frío/Refrescante (Pepino, Fideos fríos)
# 0.5 = Neutro
# 1.0 = Calórico/Pesado (Caldos grasos, Picantes, Carne)
