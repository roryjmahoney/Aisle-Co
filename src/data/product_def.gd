class_name ProductDef
extends Resource
## Immutable description of a product line. Runtime quantities (stock, the
## player's chosen price) never live here — see Inventory and Pricing.

@export var id: StringName
@export var display_name: String
@export var brand: String
@export_enum("pantry", "drinks", "dairy", "produce", "household") var category: String = "pantry"
## Where the product can be displayed: ambient shelving or chilled cases.
@export_enum("ambient", "chilled") var storage: String = "ambient"

@export_group("Economics")
## Wholesale price per unit, in cents.
@export var unit_cost_cents: int = 100
## The price shoppers consider fair, in cents. Players may set their own.
@export var reference_price_cents: int = 200
## Units per delivered case.
@export var case_size: int = 12
## 0..1 — how often this shows up on shopping lists.
@export_range(0.0, 1.0) var popularity: float = 0.5
## How sharply willingness to buy falls as price rises above reference.
@export_range(0.2, 3.0) var price_elasticity: float = 1.0
## Days before spoilage. 0 = shelf stable. (Reserved: spoilage not simulated yet.)
@export var shelf_life_days: int = 0

@export_group("Presentation")
## Physical size of one unit (width, height, depth) in metres. Shelf capacity
## is derived from this, so what you see on the shelf is exactly what's stocked.
@export var unit_size: Vector3 = Vector3(0.08, 0.12, 0.08)
@export_enum("cereal_box", "can", "jar", "bottle", "carton", "cheese") var shape: String = "can"
@export var color_main: Color = Color.WHITE
@export var color_second: Color = Color.WHITE
@export var color_accent: Color = Color.WHITE
