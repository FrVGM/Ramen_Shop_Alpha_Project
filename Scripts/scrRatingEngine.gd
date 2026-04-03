extends Node
class_name RatingEngine

# Esta función NECESITA que le envíes el diccionario de probabilidades desde el Main
static func select_customer_per_probability(probabilidades: Dictionary) -> String:
	var total_weight = 0.0
	for weight in probabilidades.values():
		total_weight += weight
	
	var r = randf() * total_weight
	var accumulated = 0.0
	
	for n_customer in probabilidades.keys():
		accumulated += probabilidades[n_customer]
		if r <= accumulated:
			return n_customer
			
	return probabilidades.keys()[0] # Si algo falla, devuelve el primer cliente


# --- AFINIDAD (QUÉ QUIERE COMER) ---
static func find_best_recipe_for_customer(customer_data: CustomerData, p_menu: Array, p_temp: float) -> Variant:
	var best_choice = null
	var max_affinity: float = -999.0 

	var favorite_at_moment: Array[Ingredient] = []
	if p_temp > 27.0: favorite_at_moment = customer_data.favorites_hot
	elif p_temp < 10.0: favorite_at_moment = customer_data.favorites_cold
	else: favorite_at_moment = customer_data.favorites_tempered

	for choice in p_menu:
		var recipe = choice["resource"]
		if recipe == null: continue 
		var sale_price = choice["price"]
		
		if sale_price > (customer_data.budget * 2.0): continue
		if customer_data.is_vegetarian and not recipe.is_vegetarian_friendly(): continue
		
		var ing_list = recipe.ingredients.values().filter(func(i): return i != null)
		var success = 0
		var negative_score = 0.0 
		var liked_categories = favorite_at_moment.map(func(f): return f.category)
		
		for ing in ing_list:
			if ing.category in liked_categories:
				success += 1
			else:
				if p_temp > 27.0:
					negative_score += (ing.thermal_density * 2.0) if ing.category == "Broth" else 0.1
				else:
					negative_score += 0.1
		
		var affinity_score = (success * 1.0) - negative_score
		
		if sale_price > customer_data.budget:
			var overprice_ratio = float(sale_price) / float(customer_data.budget)
			affinity_score -= (overprice_ratio - 1.0) * 2.0 

		affinity_score *= customer_data.weight_taste
		
		if affinity_score > max_affinity:
			max_affinity = affinity_score
			best_choice = choice
		elif affinity_score == max_affinity and best_choice != null:
			if sale_price < best_choice["price"]:
				best_choice = choice

	return best_choice

# --- RATING FINAL (QUÉ TAN FELIZ QUEDÓ) ---
static func calculate_final_rating(data_bundle: Dictionary) -> float:
	# Usamos un Dictionary para pasar los datos y no tener 20 parámetros
	var customer_data = data_bundle.customer_data
	var recipe = data_bundle.recipe
	var sale_price = float(data_bundle.price)
	var p_temp = data_bundle.temp
	var p_ticks = data_bundle.ticks_taken
	var p_angry = data_bundle.is_angry
	var shop_comfort = data_bundle.shop_comfort
	var bonus_service = data_bundle.bonus_service
	var bonus_comfort = data_bundle.bonus_comfort

	# 1. TASTE
	var favoritos = customer_data.favorites_hot if p_temp > 27.0 else (customer_data.favorites_cold if p_temp < 10.0 else customer_data.favorites_tempered)
	var desired_categories = []
	for f in favoritos:
		if not f.category in desired_categories: desired_categories.append(f.category)
	
	var success_category = 0
	var ing_list = recipe.ingredients.values().filter(func(i): return i != null)
	for cat_sought in desired_categories:
		for ing_servido in ing_list:
			if ing_servido.category == cat_sought:
				success_category += 1
				break 

	var taste_score = float(success_category) / float(desired_categories.size()) if desired_categories.size() > 0 else 0.5
	if p_temp > 27.0 and recipe.ingredients.get("Broth") != null: taste_score = 0.1

	# 2. SPEED, COMFORT, PRICE, SERVICE
	var speed_score = clamp(1.0 - (float(p_ticks) / float(customer_data.patience_ticks * 2.0)), 0.0, 1.0)
	var comfort_score = clamp(shop_comfort + bonus_comfort, 0.0, 1.0)
	var recipe_cost = recipe.get_total_cost()
	var price_score = clamp((recipe_cost * 2.0) / sale_price, 0.0, 1.0) if sale_price > 0 else 0.0
	var base_service = 0.9 if not p_angry else 0.2
	var service_score = clamp(base_service * bonus_service, 0.0, 1.0)
	var hygiene_score = 0.8 

	# 3. PESOS Y BALANCE
	var total_score = (
		(taste_score * customer_data.weight_taste) +
		(speed_score * customer_data.weight_speed) +
		(comfort_score * customer_data.weight_comfort) +
		(price_score * customer_data.weight_price) +
		(service_score * customer_data.weight_service) +
		(hygiene_score * customer_data.weight_hygiene)
	)

	var max_possible = (customer_data.weight_taste + customer_data.weight_speed + customer_data.weight_comfort + 
						customer_data.weight_price + customer_data.weight_service + customer_data.weight_hygiene)

	var rating_final = (total_score / max_possible) * 5.0

	if sale_price > customer_data.budget:
		var ratio = sale_price / float(customer_data.budget)
		rating_final -= (0.5 + ((ratio - 1.5) * 2.0) if ratio > 1.5 else (ratio - 1.0))

	return clamp(snapped(rating_final, 0.1), 1.0, 5.0)
