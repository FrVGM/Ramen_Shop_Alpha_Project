extends Node
class_name EconomyManager

# --- CONSTANTES DE NEGOCIO ---
const BASE_RENT = 100
const RENT_INCREMENT_PER_DAY = 20

# Porcentajes de Staff
const PERCENT_CHEF = 0.10
const PERCENT_SERVER = 0.05
const PERCENT_HOSTESS = 0.05

# --- CÁLCULO DE CIERRE DE DÍA ---
static func calculate_day_summary(data_bundle: Dictionary) -> Dictionary:
	var current_money = data_bundle.money
	var money_at_start = data_bundle.money_at_start
	var day = data_bundle.day
	var stars_average = data_bundle.stars_average

	# 1. Ganancia Bruta (Gross Profit)
	var today_gross_profit = current_money - money_at_start
	if today_gross_profit < 0: today_gross_profit = 0
	
	# 2. Salarios (Basados en la ganancia del día)
	var salary_chef = roundi(today_gross_profit * PERCENT_CHEF)
	var salary_server = roundi(today_gross_profit * PERCENT_SERVER)
	var salary_hostess = roundi(today_gross_profit * PERCENT_HOSTESS)
	
	# 3. Renta escalable
	var today_rent = BASE_RENT + (day * RENT_INCREMENT_PER_DAY)
	
	# 4. Total Gastos
	var total_expenses = today_rent + salary_chef + salary_server + salary_hostess
	var net_profit = today_gross_profit - total_expenses
	
	# 5. Formatear el texto para la UI (El resumen que lee el jugador)
	var summary_text = "--- DAY %d SUMMARY ---\n" % day
	summary_text += "Today's Earnings: ¥%d\n" % today_gross_profit
	summary_text += "Expenses (Rent + Staff): -¥%d\n" % total_expenses
	summary_text += "Net Profit: ¥%d\n" % net_profit
	summary_text += "Recent Stars: %.1f | Final Balance: ¥%d" % [stars_average, current_money - total_expenses]

	# Devolvemos un paquete con todos los resultados
	return {
		"total_expenses": total_expenses,
		"summary_text": summary_text,
		"net_profit": net_profit,
		"is_bankrupt": (stars_average < 1.1 or (current_money - total_expenses) < -500)
	}
