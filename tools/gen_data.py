#!/usr/bin/env python3
"""Generates the .tres data definitions from one readable table.

Run from the project root:  python3 tools/gen_data.py
Editing the .tres files directly in the Godot inspector also works; this script
just keeps the initial catalogue reviewable in one place.
"""
import os

PRODUCTS = [
    dict(id="oats", display_name="Sunny Oats", brand="Hearthfield", category="pantry", storage="ambient",
         unit_cost_cents=210, reference_price_cents=389, case_size=12, popularity=0.65, price_elasticity=1.0,
         shelf_life_days=0, unit_size=(0.19, 0.27, 0.07), shape="cereal_box",
         color_main="f2b33d", color_second="e2553a", color_accent="f4f7f2"),
    dict(id="soup", display_name="Tomato Soup", brand="Old Kettle", category="pantry", storage="ambient",
         unit_cost_cents=85, reference_price_cents=179, case_size=24, popularity=0.8, price_elasticity=0.8,
         shelf_life_days=0, unit_size=(0.074, 0.105, 0.074), shape="can",
         color_main="e2553a", color_second="f4f7f2", color_accent="f2b33d"),
    dict(id="jam", display_name="Strawberry Jam", brand="Bramble Lane", category="pantry", storage="ambient",
         unit_cost_cents=165, reference_price_cents=329, case_size=12, popularity=0.45, price_elasticity=1.2,
         shelf_life_days=0, unit_size=(0.08, 0.1, 0.08), shape="jar",
         color_main="a8283f", color_second="f4f7f2", color_accent="e2553a"),
    dict(id="water", display_name="Spring Water", brand="Clearbrook", category="drinks", storage="ambient",
         unit_cost_cents=40, reference_price_cents=119, case_size=24, popularity=0.9, price_elasticity=1.4,
         shelf_life_days=0, unit_size=(0.07, 0.22, 0.07), shape="bottle",
         color_main="a9d8e6", color_second="f4f7f2", color_accent="3e5f8a"),
    dict(id="milk", display_name="Whole Milk", brand="Meadowvale", category="dairy", storage="chilled",
         unit_cost_cents=95, reference_price_cents=199, case_size=12, popularity=0.85, price_elasticity=0.7,
         shelf_life_days=7, unit_size=(0.075, 0.2, 0.075), shape="carton",
         color_main="f4f7f2", color_second="3e5f8a", color_accent="2f7a57"),
    dict(id="cheddar", display_name="Aged Cheddar", brand="Old Barn", category="dairy", storage="chilled",
         unit_cost_cents=260, reference_price_cents=499, case_size=10, popularity=0.4, price_elasticity=1.1,
         shelf_life_days=21, unit_size=(0.11, 0.05, 0.07), shape="cheese",
         color_main="f0c04a", color_second="74405f", color_accent="f4f7f2"),
]

def row(z, xs):
    return [(x, z) for x in xs]

FIXTURES = [
    dict(id="shelf_wall", display_name="Wall Shelving", category="fixtures", price_cents=18000,
         description="Four tiers of warm oak on a painted frame. Back it against a wall.",
         footprint=(3, 1), access_cells=row(1, range(3)), slot_count=4, slot_storage="ambient",
         slot_size=(1.40, 0.36, 0.42), slot_heights=[0.16, 0.56, 0.96, 1.36], art="shelf_wall",
         height=2.15, icon="shelf", appeal=0, allow_shop=True),
    dict(id="shelf_island", display_name="Gondola Shelving", category="fixtures", price_cents=32000,
         description="A double-sided island unit. Shoppers browse from both aisles.",
         footprint=(3, 2), access_cells=row(2, range(3)) + row(-1, range(3)), slot_count=8,
         slot_storage="ambient", slot_size=(1.40, 0.36, 0.42), slot_heights=[0.16, 0.56, 0.96, 1.36],
         double_sided=True, art="shelf_island", height=1.75, icon="gondola", allow_shop=True),
    dict(id="fridge", display_name="Chiller Case", category="fixtures", price_cents=65000,
         upkeep_cents_per_day=300,
         description="Glass-door refrigeration for dairy. Draws a little power every day.",
         footprint=(3, 2), access_cells=row(2, range(3)), slot_count=4, slot_storage="chilled",
         slot_size=(1.32, 0.34, 0.55), slot_heights=[0.22, 0.62, 1.02, 1.42], art="fridge",
         height=2.2, icon="fridge", allow_shop=True),
    dict(id="checkout", display_name="Checkout Counter", category="fixtures", price_cents=42000,
         description="Conveyor, till and card reader. Shoppers queue along the open side.",
         footprint=(3, 4), access_cells=[(3, 0), (3, 1), (3, 2), (3, 3)], is_checkout=True,
         art="checkout", height=1.6, icon="register", allow_shop=True),
    dict(id="storage_rack", display_name="Stockroom Racking", category="storage", price_cents=14000,
         description="Heavy-duty racking for delivered cases. Holds 18 cases.",
         footprint=(3, 2), access_cells=row(2, range(3)), storage_cases=18, art="storage_rack",
         height=2.2, icon="rack", allow_shop=False, allow_backroom=True),
    dict(id="plant", display_name="Potted Monstera", category="decor", price_cents=3500,
         description="A generous leafy plant. Shoppers like a store that feels cared for.",
         footprint=(1, 1), access_cells=[], art="plant", height=1.2, icon="plant", appeal=3,
         allow_shop=True, allow_backroom=True),
    dict(id="floor_lamp", display_name="Brass Floor Lamp", category="decor", price_cents=6000,
         upkeep_cents_per_day=20,
         description="A warm pool of light for a cosy corner.",
         footprint=(1, 1), access_cells=[], art="floor_lamp", height=1.7, icon="lamp", appeal=4,
         allow_shop=True),
    dict(id="basket_stand", display_name="Basket Stand", category="decor", price_cents=4500,
         description="A stack of red baskets by the door. Shoppers carry a little more.",
         footprint=(1, 1), access_cells=[], art="basket_stand", height=0.8, icon="basket", appeal=2,
         allow_shop=True),
    dict(id="chalkboard", display_name="Chalkboard Sign", category="decor", price_cents=2500,
         description="Hand-lettered specials. A small touch of personality.",
         footprint=(1, 1), access_cells=[], art="chalkboard", height=1.1, icon="sign", appeal=2,
         allow_shop=True),
]

def fmt(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, int):
        return str(v)
    if isinstance(v, float):
        return repr(v)
    if isinstance(v, str):
        return '"%s"' % v
    raise TypeError(v)

def write(path, script, cls, d, special):
    lines = [f'[gd_resource type="Resource" script_class="{cls}" load_steps=2 format=3]', "",
             f'[ext_resource type="Script" path="{script}" id="1"]', "", "[resource]",
             'script = ExtResource("1")']
    for k, v in d.items():
        if k in special:
            lines.append(f"{k} = {special[k](v)}")
        elif k == "id":
            lines.append(f'id = &"{v}"')
        else:
            lines.append(f"{k} = {fmt(v)}")
    open(path, "w").write("\n".join(lines) + "\n")

col = lambda h: "Color(%.4f, %.4f, %.4f, 1)" % tuple(int(h[i:i+2], 16) / 255 for i in (0, 2, 4))
v3 = lambda t: "Vector3(%s, %s, %s)" % t
v2i = lambda t: "Vector2i(%d, %d)" % t
v2i_arr = lambda a: "Array[Vector2i]([%s])" % ", ".join(v2i(tuple(x)) for x in a)
pfa = lambda a: "PackedFloat32Array(%s)" % ", ".join(repr(float(x)) for x in a)
sn = lambda s: '&"%s"' % s

os.makedirs("data/products", exist_ok=True)
os.makedirs("data/fixtures", exist_ok=True)
for p in PRODUCTS:
    write(f"data/products/{p['id']}.tres", "res://src/data/product_def.gd", "ProductDef", p,
          {"unit_size": v3, "color_main": col, "color_second": col, "color_accent": col})
for f in FIXTURES:
    write(f"data/fixtures/{f['id']}.tres", "res://src/data/fixture_def.gd", "FixtureDef", f,
          {"footprint": v2i, "access_cells": v2i_arr, "slot_size": v3, "slot_heights": pfa,
           "art": sn, "icon": sn})
print("wrote", len(PRODUCTS), "products and", len(FIXTURES), "fixtures")
