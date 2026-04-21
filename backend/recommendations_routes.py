from flask import request, jsonify

_SET_CATALOG = { #existing sets, Add more sets here
    "10698": {
        "name": "Classic Creative Brick Box",
        "total_pieces": 790,
        "difficulty": "beginner",
        "image_url": "https://images.brickset.com/sets/images/10698-1.jpg",
        "required_bricks": {
            "3001": 12,  # Brick 2x4
            "3003": 10,  # Brick 2x2
            "3023": 15,  # Plate 1x2
            "3005": 8,   # Brick 1x1
            "3022": 6,   # Plate 2x2
        },
    },
    "31134": {
        "name": "Space Rocket",
        "total_pieces": 837,
        "difficulty": "intermediate",
        "image_url": "https://images.brickset.com/sets/images/31134-1.jpg",
        "required_bricks": {
            "3001": 15,
            "3004": 8,   # Brick 1x2
            "3622": 6,   # Brick 1x3
            "2456": 4,   # Brick 2x6
            "3039": 5,   # Slope 2x2
        },
    },
    "10302": {
        "name": "Optimus Prime",
        "total_pieces": 1508,
        "difficulty": "advanced",
        "image_url": "https://images.brickset.com/sets/images/10302-1.jpg",
        "required_bricks": {
            "3001": 20,
            "3003": 15,
            "3023": 10,
            "2456": 5,
            "3039": 8,
            "3010": 6,   # Brick 1x4
            "3009": 4,   # Brick 1x6
        },
    },
    "60197": {
        "name": "Passenger Train",
        "total_pieces": 677,
        "difficulty": "intermediate",
        "image_url": "https://images.brickset.com/sets/images/60197-1.jpg",
        "required_bricks": {
            "3001": 10,
            "3023": 20,
            "3004": 12,
            "3005": 8,
            "3622": 6,
        },
    },
    "21318": {
        "name": "Tree House",
        "total_pieces": 3036,
        "difficulty": "advanced",
        "image_url": "https://images.brickset.com/sets/images/21318-1.jpg",
        "required_bricks": {
            "3001": 30,
            "3003": 20,
            "3023": 25,
            "3022": 18,
            "3005": 12,
            "3004": 15,
        },
    },
    "12345": {
        "name": "Test Set 1",
        "total_pieces": 3,
        "difficulty": "beginner",
        "image_url": "https://images.brickset.com/sets/images/21318-1.jpg",
        "required_bricks": {
            "3005": 3,
        },
    },
    "23456": {
        "name": "Test Set 2",
        "total_pieces": 5,
        "difficulty": "beginner",
        "image_url": "https://images.brickset.com/sets/images/21318-1.jpg",
        "required_bricks": {
            "3005": 5,
        },
    },
}


def _compute_recommendations(inventory_items: list, limit: int = 10) -> list:
    """
    Computes set recommendations from the user's inventory.

    inventory_items: list of dicts with keys brick_id (str) and quantity (int).

    Returns a list of dicts whose keys match exactly what the existing Flutter
    RecommendationsScreen parses:
        name                  str
        completion_percentage int   (0–100, based on % of brick *types* satisfied)
        missing_pieces        int   (total count of individual bricks still needed)
        image_url             str
    """
    #Aggregate owned bricks: {brick_id: total_quantity}
    owned: dict[str, int] = {}
    for item in inventory_items:
        bid = str(item.get("brick_id") or item.get("id", ""))
        qty = int(item.get("quantity", 1))
        if bid:
            owned[bid] = owned.get(bid, 0) + qty

    results = []

    for set_id, info in _SET_CATALOG.items():
        required: dict[str, int] = info["required_bricks"]

        matched_types = 0
        total_missing_qty = 0

        for bid, needed in required.items():
            have = owned.get(bid, 0)
            if have >= needed:
                matched_types += 1
            else:
                total_missing_qty += needed - have

        total_types = len(required)
        if total_types == 0:
            continue

        completion_pct = round(matched_types / total_types * 100)

        #Only surface sets where at least 30% of brick types are already owned
        if completion_pct < 30:
            continue

        results.append({
            "name": info["name"],
            "completion_percentage": completion_pct,
            "missing_pieces": total_missing_qty,
            "image_url": info.get("image_url", ""),
            # Extra fields ignored by the current Flutter screen but
            # available if you want to expand the UI later:
            "set_id": set_id,
            "total_pieces": info["total_pieces"],
            "difficulty": info["difficulty"],
        })

    #Best match first; break ties by fewest missing pieces
    results.sort(key=lambda r: (-r["completion_percentage"], r["missing_pieces"]))
    return results[:limit]


def register_recommendations(app, InventoryItem, pinecone_svc, token_required, now_iso_fn):

    @app.route("/api/recommendations", methods=["GET"])
    @token_required
    def recommendations(current_user):
        limit = min(request.args.get("limit", 10, type=int), 20)

        #Try the user's database inventory first
        db_items = InventoryItem.query.filter_by(user_id=current_user.id).all()
        inventory = [{"brick_id": i.brick_id, "quantity": i.quantity} for i in db_items]

        #Fall back to Pinecone if the DB inventory is empty
        if not inventory and pinecone_svc.enabled:
            pinecone_inv = pinecone_svc.get_inventory(str(current_user.id))
            if pinecone_inv:
                inventory = [
                    {
                        "brick_id": i.get("brick_id") or i.get("id", ""),
                        "quantity": i.get("quantity", 1),
                    }
                    for i in pinecone_inv
                ]

        recs = _compute_recommendations(inventory, limit=limit)

        return jsonify({
            "recommendations": recs,
            "source": "database" if db_items else ("pinecone" if pinecone_svc.enabled else "local"),
            "timestamp": now_iso_fn(),
        })