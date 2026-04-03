extends Resource
class_name CustomerData

# Enumeración maestra para que todo el equipo use los mismos nombres
enum Type {
	# Commons
	Farmer, Fisher, Miner, Pedestrian,
	# Uncommons
	Merchant, Karateka, Samurai, Sumo, Monk, Priestess,
	# Rares
	Lord, Lady, High_Priest, High_Priestess
}

@export_group("Identity")
@export var customer_type: Type
@export var texture: Texture2D
@export_enum("Common", "Uncommon", "Rare") var rarity: String = "Common"

@export_group("Economic & Time")
@export var budget: int = 1500
@export var patience_ticks: int = 20 # Ticks until Speed stars drop
@export var eating_ticks: int = 10 # ¿Cuántos ticks tarda en terminar el plato?

@export_group("Taste Profile")
@export var favorites_hot: Array[Ingredient] = []   # Para > 27 grados
@export var favorites_tempered: Array[Ingredient] = [] # Para 10 a 27 grados
@export var favorites_cold: Array[Ingredient] = []     # Para < 10 grados

@export_group("Priority Weights")
# El rango va de 0.0 a 1.0, con pasos de 0.1
@export_range(0.0, 1.0, 0.1) var weight_taste: float = 0.5
@export_range(0.0, 1.0, 0.1) var weight_speed: float = 0.5
@export_range(0.0, 1.0, 0.1) var weight_service: float = 0.5
@export_range(0.0, 1.0, 0.1) var weight_comfort: float = 0.5
@export_range(0.0, 1.0, 0.1) var weight_price: float = 0.5
@export_range(0.0, 1.0, 0.1) var weight_hygiene: float = 0.5
@export_range(0.0, 1.0, 0.1) var weight_aroma: float = 0.0

@export_group("Requirements")
@export var is_vegetarian: bool = false # Asegúrate de que el nombre sea EXACTAMENTE este
@export var min_freshness_requirement: int = 0 # Los 'Rares' exigirán frescura alta
