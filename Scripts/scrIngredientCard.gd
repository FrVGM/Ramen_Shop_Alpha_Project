extends VBoxContainer
signal selected(ingredient)

var ingredient_ref: Ingredient

func setup(ing: Ingredient):
	ingredient_ref = ing
	$NameLabel.text = ing.name
	$CostLabel.text = str(ing.price) + "¥"
	$btnContainer.icon = ing.texture
	$btnContainer.pressed.connect(func(): selected.emit(ingredient_ref))
