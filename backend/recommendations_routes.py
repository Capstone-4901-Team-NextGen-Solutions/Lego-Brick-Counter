from flask import request, jsonify
from recommendation_engine import get_recommendations_for_user
import logging

logger = logging.getLogger(__name__)


def register_recommendations(app, InventoryItem, pinecone_svc, token_required, now_iso_fn):

    @app.route("/api/recommendations", methods=["GET"])
    @token_required
    def recommendations(current_user):
        """Get real LEGO set recommendations based on user's actual inventory."""
        limit = min(max(request.args.get("limit", 5, type=int), 1), 20)

        # Fetch user's actual inventory from database
        db_items = InventoryItem.query.filter_by(user_id=current_user.id).all()
        user_inventory = [
            {
                "brick_id":   item.brick_id,
                "brick_name": item.brick_name,
                "color":      item.color,
                "quantity":   item.quantity,
            }
            for item in db_items
        ]

        logger.info(
            f"[Recommendations] User {current_user.id} has "
            f"{len(user_inventory)} unique brick types in inventory"
        )

        recs = get_recommendations_for_user(user_inventory, limit=limit)

        logger.info(f"[Recommendations] Returning {len(recs)} recommendations")

        return jsonify(
            {
                "success":         True,
                "recommendations": recs,
                "inventory_size":  len(user_inventory),
                "message": (
                    "Based on your actual inventory"
                    if user_inventory
                    else "Add bricks to inventory to get personalized recommendations"
                ),
                "timestamp": now_iso_fn(),
            }
        )
