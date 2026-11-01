class_name Economy
extends RefCounted
## All money is integer cents. Every change to `cash` goes through _post(),
## which writes a ledger entry — so cash always equals the sum of the ledger
## and nothing can mint or lose money silently.

signal cash_changed(cash: int)
signal posted(entry: Dictionary)

enum Kind { SALE, STOCK, BUILD, REFUND, WAGES, UPKEEP, RENT, OTHER }
const KIND_NAMES := ["Sales", "Stock purchases", "Construction", "Refunds", "Wages", "Utilities & upkeep", "Rent", "Other"]

const START_CASH := 250000
const RENT_PER_DAY := 4500
const BASE_UTILITIES := 600

var cash := START_CASH
var opening_cash := START_CASH
var ledger: Array[Dictionary] = []
var report := {}
var history: Array[Dictionary] = []


func _init() -> void:
	ledger.append({"day": 0, "kind": Kind.OTHER, "amount": START_CASH, "memo": "Opening balance"})
	start_day(1)


func can_afford(cents: int) -> bool:
	return cents <= cash


func charge(kind: int, cents: int, memo: String, allow_debt: bool = false) -> bool:
	assert(cents >= 0)
	if not allow_debt and cents > cash:
		return false
	_post(kind, -cents, memo)
	return true


func credit(kind: int, cents: int, memo: String) -> void:
	assert(cents >= 0)
	_post(kind, cents, memo)


func record_sale(p: ProductDef, units: int, unit_price: int) -> void:
	var revenue := units * unit_price
	credit(Kind.SALE, revenue, "%d × %s" % [units, p.display_name])
	report.revenue += revenue
	report.cogs += units * p.unit_cost_cents
	report.items_sold += units
	var row: Dictionary = report.by_product.get(p.id, {"units": 0, "revenue": 0, "margin": 0})
	row.units += units
	row.revenue += revenue
	row.margin += units * (unit_price - p.unit_cost_cents)
	report.by_product[p.id] = row


func start_day(day: int) -> void:
	opening_cash = cash
	report = {
		"day": day, "revenue": 0, "cogs": 0, "stock_spend": 0, "build_spend": 0, "refunds": 0,
		"wages": 0, "upkeep": 0, "rent": 0, "items_sold": 0, "customers": 0, "served": 0,
		"lost": 0, "satisfaction_sum": 0.0, "by_product": {}, "complaints": {},
	}


func close_day(upkeep_cents: int, wages_cents: int) -> Dictionary:
	## Charge the day's fixed costs and freeze the report.
	charge(Kind.RENT, RENT_PER_DAY, "Rent", true)
	charge(Kind.UPKEEP, BASE_UTILITIES + upkeep_cents, "Utilities & upkeep", true)
	if wages_cents > 0:
		charge(Kind.WAGES, wages_cents, "Staff wages", true)
	var r := report.duplicate(true)
	r["opening_cash"] = opening_cash
	r["closing_cash"] = cash
	r["gross_margin"] = r.revenue - r.cogs
	r["operating_costs"] = r.rent + r.upkeep + r.wages
	r["operating_profit"] = r.gross_margin - r.operating_costs
	history.append(r)
	return r


func ledger_balance() -> int:
	var total := 0
	for e in ledger:
		total += e.amount
	return total


func _post(kind: int, amount: int, memo: String) -> void:
	cash += amount
	var e := {"day": report.get("day", 0), "kind": kind, "amount": amount, "memo": memo}
	ledger.append(e)
	if ledger.size() > 5000:
		# Fold the oldest entries into one carried-forward line.
		var carried := 0
		for i in 1000:
			carried += ledger[i].amount
		ledger = ledger.slice(1000)
		ledger.push_front({"day": 0, "kind": Kind.OTHER, "amount": carried, "memo": "Carried forward"})
	match kind:
		Kind.STOCK: report.stock_spend += -amount
		Kind.BUILD: report.build_spend += -amount
		Kind.REFUND: report.refunds += amount
		Kind.WAGES: report.wages += -amount
		Kind.UPKEEP: report.upkeep += -amount
		Kind.RENT: report.rent += -amount
	posted.emit(e)
	cash_changed.emit(cash)


func to_dict() -> Dictionary:
	return {"cash": cash, "opening_cash": opening_cash, "report": report, "history": history,
			"ledger_tail": ledger.slice(maxi(0, ledger.size() - 200))}


func from_dict(d: Dictionary) -> void:
	cash = int(d.get("cash", START_CASH))
	opening_cash = int(d.get("opening_cash", cash))
	report = d.get("report", report)
	history.assign(d.get("history", []))
	ledger.assign(d.get("ledger_tail", []))
	# Keep the invariant cash == sum(ledger) after a load.
	var diff := cash - ledger_balance()
	if diff != 0:
		ledger.push_front({"day": 0, "kind": Kind.OTHER, "amount": diff, "memo": "Carried forward"})
	cash_changed.emit(cash)
