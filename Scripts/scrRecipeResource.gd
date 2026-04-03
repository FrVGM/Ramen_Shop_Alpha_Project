extends Resource
class_name RecipeResource

@export var recipe_name: String
@export var ingredients: Dictionary = {
	"Broth": null,
	"Noodles": null,
	"Veggie": null,
	"Egg": null,
	"Garnish": null,
	"Topping": null
}

# --- NUEVO: Comprobación rápida para clientes vegetarianos ---
func is_vegetarian_friendly() -> bool:
	# Un ramen es vegetariano solo si TODOS sus ingredients lo son
	for ing in ingredients.values():
		if ing != null and not ing.is_vegetarian:
			return false
	return true

# --- NUEVO: Cálculo de Frescura Promedio (Para Hygiene) ---
func get_average_freshness() -> float:
	var total = 0.0
	var count = 0
	for ing in ingredients.values():
		if ing != null:
			total += ing.freshness
			count += 1
	return total / count if count > 0 else 0.0

# --- Función de Costo (Actualizada para usar el nuevo .price_costo si lo cambiaste) ---
func get_total_cost() -> int:
	var total = 0
	for ing in ingredients.values():
		if ing != null: 
			# Usamos .price o .cost_price dependiendo de cómo nombraste la variable en el recurso Ingrediente
			total += ing.price 
	return total
