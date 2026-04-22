# backend/recommendation_engine.py
from lego_sets_db import LEGO_SETS
import logging

logger = logging.getLogger(__name__)


def calculate_set_completion(user_inventory: list, lego_set: dict) -> dict:
    """
    Compare user inventory against a LEGO set BOM.

    user_inventory: list of dicts with brick_id, color, quantity
    lego_set:       set dict from LEGO_SETS with a 'pieces' list

    Returns completion percentage, owned count, total required, missing pieces.
    """
    total_required = sum(p["qty"] for p in lego_set["pieces"])
    if total_required == 0:
        return {"percentage": 0, "owned_count": 0, "total_count": 0, "missing": []}

    # Build O(1) lookup: "brick_id_color" (both lowercased) -> quantity
    inventory_map = {}
    for b in user_inventory:
        key = (
            f"{str(b.get('brick_id') or b.get('brick_name', '')).lower()}"
            f"_{str(b.get('color', '')).lower()}"
        )
        inventory_map[key] = inventory_map.get(key, 0) + int(b.get("quantity", 0))

    total_owned = 0.0
    missing_pieces = []

    for req in lego_set["pieces"]:
        key = f"{req['brick_id'].lower()}_{req['color'].lower()}"
        owned_qty = inventory_map.get(key, 0)

        # Substitution: if exact colour match missing, try any brick of same type (90% credit)
        substitution_credit = 0.0
        if owned_qty == 0:
            brick_prefix = req["brick_id"].lower() + "_"
            for inv_key, inv_qty in inventory_map.items():
                if inv_key.startswith(brick_prefix):
                    substitution_credit = min(inv_qty, req["qty"]) * 0.9
                    break

        contribution = min(owned_qty, req["qty"]) + substitution_credit
        total_owned += contribution

        if owned_qty < req["qty"]:
            missing_pieces.append(
                {
                    "brick_id": req["brick_id"],
                    "color": req["color"],
                    "needed": req["qty"] - owned_qty,
                    "have": owned_qty,
                }
            )

    percentage = round((total_owned / total_required) * 100, 1)
    percentage = min(percentage, 100.0)

    return {
        "percentage": percentage,
        "owned_count": int(total_owned),
        "total_count": total_required,
        "missing": missing_pieces,
    }


def get_recommendations_for_user(user_inventory: list, limit: int = 5) -> list:
    """
    Run comparison engine against all sets in LEGO_SETS.
    Returns list sorted by completion percentage descending.
    """
    results = []

    for lego_set in LEGO_SETS:
        completion = calculate_set_completion(user_inventory, lego_set)
        pct = completion["percentage"]

        results.append(
            {
                "set_id": lego_set["set_id"],
                "name": lego_set["name"],
                "theme": lego_set.get("theme", ""),
                "image_url": "",  # kept for Flutter backward compat
                "completion_percentage": pct,
                "owned_pieces": completion["owned_count"],
                "total_pieces": completion["total_count"],
                "missing_pieces_count": len(completion["missing"]),
                "missing_pieces": completion["missing"][:10],  # top 10 for UI
                "difficulty": lego_set.get("difficulty", "intermediate"),
                "estimated_build_time": lego_set.get("estimated_build_time", "Unknown"),
            }
        )

    results.sort(key=lambda x: x["completion_percentage"], reverse=True)
    return results[:limit]
