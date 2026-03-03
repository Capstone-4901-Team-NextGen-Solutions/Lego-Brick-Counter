# pinecone_service.py - Pinecone Vector Database Integration for Lego Brick Counter
#
# Provides:
#   - Brick embedding storage & similarity search
#   - Persistent inventory per user
#   - Set recommendation via vector similarity
#   - Graceful fallback when Pinecone is unavailable

import os
import logging
import hashlib
from typing import List, Dict, Optional, Any

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Attempt Pinecone import - the rest of the app works without it
# ---------------------------------------------------------------------------
try:
    from pinecone import Pinecone, ServerlessSpec
    PINECONE_AVAILABLE = True
except ImportError:
    PINECONE_AVAILABLE = False
    logger.warning("pinecone-client not installed - running in local-only mode")

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
BRICK_NAMESPACE = "bricks"
SET_NAMESPACE = "sets"
INVENTORY_NAMESPACE = "inventory"
EMBEDDING_DIM = 128  # lightweight embeddings for brick features


class PineconeService:
    """Manages all Pinecone interactions for the Lego Brick Counter."""

    def __init__(self):
        self.enabled = False
        self.index = None
        self._init_pinecone()

    # ------------------------------------------------------------------
    # Initialisation
    # ------------------------------------------------------------------
    def _init_pinecone(self):
        if not PINECONE_AVAILABLE:
            logger.info("Pinecone SDK not available - skipping init")
            return

        api_key = os.getenv("PINECONE_API_KEY", "")
        index_name = os.getenv("PINECONE_INDEX_NAME", "lego-bricks")

        if not api_key or api_key == "your-pinecone-api-key-here":
            logger.info("PINECONE_API_KEY not configured - running in local-only mode")
            return

        try:
            pc = Pinecone(api_key=api_key)

            # Create index if it doesn't exist
            existing = [idx.name for idx in pc.list_indexes()]
            if index_name not in existing:
                logger.info(f"Creating Pinecone index '{index_name}'...")
                pc.create_index(
                    name=index_name,
                    dimension=EMBEDDING_DIM,
                    metric="cosine",
                    spec=ServerlessSpec(
                        cloud=os.getenv("PINECONE_CLOUD", "aws"),
                        region=os.getenv("PINECONE_REGION", "us-east-1"),
                    ),
                )

            self.index = pc.Index(index_name)
            self.enabled = True
            logger.info(f"Pinecone connected - index '{index_name}'")
        except Exception as exc:
            logger.error(f"Pinecone init failed: {exc}")
            self.enabled = False

    # ------------------------------------------------------------------
    # Embedding helpers
    # ------------------------------------------------------------------
    @staticmethod
    def _brick_to_embedding(brick: Dict[str, Any]) -> List[float]:
        """Deterministic lightweight embedding from brick attributes.

        Encodes: part-number hash, colour hash, dimensions proxy,
        quantity signal, confidence signal, padded to EMBEDDING_DIM.
        """
        vec = [0.0] * EMBEDDING_DIM

        # Part-number hash -> first 32 floats
        part_hash = hashlib.md5(brick.get("name", "unknown").encode()).hexdigest()
        for i, ch in enumerate(part_hash[:32]):
            vec[i] = int(ch, 16) / 15.0  # normalise to [0, 1]

        # Colour hash -> next 32 floats
        colour_hash = hashlib.md5(brick.get("color", "unknown").encode()).hexdigest()
        for i, ch in enumerate(colour_hash[:32]):
            vec[32 + i] = int(ch, 16) / 15.0

        # Quantity / confidence signals
        vec[64] = min(brick.get("quantity", 1) / 100.0, 1.0)
        vec[65] = brick.get("confidence", 0.5)

        # Size proxy from name (e.g. "2x4 Brick" -> 2, 4)
        name = brick.get("name", "")
        dims = [c for c in name.split() if "x" in c]
        if dims:
            parts = dims[0].split("x")
            try:
                vec[66] = int(parts[0]) / 10.0
                vec[67] = int(parts[1]) / 10.0
            except (ValueError, IndexError):
                pass

        return vec

    @staticmethod
    def _set_to_embedding(lego_set: Dict[str, Any]) -> List[float]:
        """Deterministic embedding for a Lego set (for recommendation matching)."""
        vec = [0.0] * EMBEDDING_DIM

        name_hash = hashlib.md5(lego_set.get("name", "").encode()).hexdigest()
        for i, ch in enumerate(name_hash[:32]):
            vec[i] = int(ch, 16) / 15.0

        # Encode brick composition of the set
        for j, brick in enumerate(lego_set.get("bricks_included", [])[:10]):
            offset = 32 + j * 8
            bid_hash = hashlib.md5(brick.get("id", "").encode()).hexdigest()[:8]
            for k, ch in enumerate(bid_hash):
                if offset + k < EMBEDDING_DIM:
                    vec[offset + k] = int(ch, 16) / 15.0

        vec[120] = min(lego_set.get("pieces", 0) / 2000.0, 1.0)
        difficulty_map = {"beginner": 0.25, "intermediate": 0.5, "advanced": 0.75}
        vec[121] = difficulty_map.get(
            lego_set.get("difficulty", "").lower(), 0.5
        )
        return vec

    @staticmethod
    def _inventory_embedding(user_id: str, brick: Dict[str, Any]) -> List[float]:
        """Combined user + brick embedding for inventory vectors."""
        vec = PineconeService._brick_to_embedding(brick)
        user_hash = hashlib.md5(user_id.encode()).hexdigest()
        for i, ch in enumerate(user_hash[:16]):
            if 112 + i < EMBEDDING_DIM:
                vec[112 + i] = int(ch, 16) / 15.0
        return vec

    # ------------------------------------------------------------------
    # Brick operations
    # ------------------------------------------------------------------
    def upsert_bricks(self, bricks: List[Dict[str, Any]]) -> bool:
        """Store detected bricks in Pinecone for future similarity lookups."""
        if not self.enabled:
            return False
        try:
            vectors = []
            for brick in bricks:
                vid = f"brick_{brick.get('id', 'unknown')}_{brick.get('color', 'unknown').lower()}"
                vectors.append({
                    "id": vid,
                    "values": self._brick_to_embedding(brick),
                    "metadata": {
                        "brick_id": brick.get("id", ""),
                        "name": brick.get("name", ""),
                        "color": brick.get("color", ""),
                        "quantity": brick.get("quantity", 1),
                        "confidence": brick.get("confidence", 0.0),
                    },
                })
            self.index.upsert(vectors=vectors, namespace=BRICK_NAMESPACE)
            logger.info(f"Upserted {len(vectors)} bricks into Pinecone")
            return True
        except Exception as exc:
            logger.error(f"Brick upsert failed: {exc}")
            return False

    def find_similar_bricks(self, brick: Dict[str, Any], top_k: int = 5) -> List[Dict]:
        """Find visually/dimensionally similar bricks via vector search."""
        if not self.enabled:
            return []
        try:
            embedding = self._brick_to_embedding(brick)
            results = self.index.query(
                vector=embedding,
                top_k=top_k,
                include_metadata=True,
                namespace=BRICK_NAMESPACE,
            )
            return [
                {
                    "id": m.id,
                    "score": m.score,
                    **(m.metadata or {}),
                }
                for m in results.get("matches", [])
            ]
        except Exception as exc:
            logger.error(f"Similar brick query failed: {exc}")
            return []

    # ------------------------------------------------------------------
    # Inventory operations
    # ------------------------------------------------------------------
    def save_inventory(self, user_id: str, bricks: List[Dict[str, Any]]) -> bool:
        if not self.enabled:
            return False
        try:
            vectors = []
            for brick in bricks:
                vid = f"inv_{user_id}_{brick.get('id', '')}_{brick.get('color', '').lower()}"
                vectors.append({
                    "id": vid,
                    "values": self._inventory_embedding(user_id, brick),
                    "metadata": {
                        "user_id": user_id,
                        "brick_id": brick.get("id", ""),
                        "name": brick.get("name", ""),
                        "color": brick.get("color", ""),
                        "quantity": brick.get("quantity", 1),
                    },
                })
            self.index.upsert(vectors=vectors, namespace=INVENTORY_NAMESPACE)
            return True
        except Exception as exc:
            logger.error(f"Inventory save failed: {exc}")
            return False

    def get_inventory(self, user_id: str) -> List[Dict]:
        if not self.enabled:
            return []
        try:
            # Query with a user-specific zero-vector to pull all that user's items
            user_vec = [0.0] * EMBEDDING_DIM
            user_hash = hashlib.md5(user_id.encode()).hexdigest()
            for i, ch in enumerate(user_hash[:16]):
                if 112 + i < EMBEDDING_DIM:
                    user_vec[112 + i] = int(ch, 16) / 15.0

            results = self.index.query(
                vector=user_vec,
                top_k=200,
                include_metadata=True,
                namespace=INVENTORY_NAMESPACE,
                filter={"user_id": {"$eq": user_id}},
            )
            return [
                {**(m.metadata or {}), "score": m.score}
                for m in results.get("matches", [])
            ]
        except Exception as exc:
            logger.error(f"Inventory fetch failed: {exc}")
            return []

    def clear_inventory(self, user_id: str) -> bool:
        if not self.enabled:
            return False
        try:
            self.index.delete(
                filter={"user_id": {"$eq": user_id}},
                namespace=INVENTORY_NAMESPACE,
            )
            return True
        except Exception as exc:
            logger.error(f"Inventory clear failed: {exc}")
            return False

    # ------------------------------------------------------------------
    # Set / Recommendation operations
    # ------------------------------------------------------------------
    def upsert_sets(self, sets: List[Dict[str, Any]]) -> bool:
        if not self.enabled:
            return False
        try:
            vectors = []
            for s in sets:
                vid = f"set_{s.get('set_id', s.get('name', 'unknown'))}"
                vectors.append({
                    "id": vid,
                    "values": self._set_to_embedding(s),
                    "metadata": {
                        "set_id": s.get("set_id", ""),
                        "name": s.get("name", ""),
                        "pieces": s.get("total_pieces", s.get("pieces", 0)),
                        "difficulty": s.get("difficulty", ""),
                    },
                })
            self.index.upsert(vectors=vectors, namespace=SET_NAMESPACE)
            return True
        except Exception as exc:
            logger.error(f"Set upsert failed: {exc}")
            return False

    def recommend_sets(
        self, bricks: List[Dict[str, Any]], top_k: int = 5
    ) -> List[Dict]:
        """Find sets whose brick composition is closest to the user's bricks."""
        if not self.enabled:
            return []
        try:
            # Build an aggregated embedding from all user bricks
            agg = [0.0] * EMBEDDING_DIM
            for brick in bricks:
                emb = self._brick_to_embedding(brick)
                for i in range(EMBEDDING_DIM):
                    agg[i] += emb[i]
            # Normalise
            magnitude = sum(v * v for v in agg) ** 0.5
            if magnitude > 0:
                agg = [v / magnitude for v in agg]

            results = self.index.query(
                vector=agg,
                top_k=top_k,
                include_metadata=True,
                namespace=SET_NAMESPACE,
            )
            return [
                {"score": m.score, **(m.metadata or {})}
                for m in results.get("matches", [])
            ]
        except Exception as exc:
            logger.error(f"Recommendation query failed: {exc}")
            return []

    # ------------------------------------------------------------------
    # Utility
    # ------------------------------------------------------------------
    def get_stats(self) -> Dict:
        if not self.enabled:
            return {"enabled": False}
        try:
            stats = self.index.describe_index_stats()
            return {
                "enabled": True,
                "total_vectors": stats.get("total_vector_count", 0),
                "namespaces": {
                    ns: info.get("vector_count", 0)
                    for ns, info in (stats.get("namespaces") or {}).items()
                },
            }
        except Exception as exc:
            logger.error(f"Stats fetch failed: {exc}")
            return {"enabled": True, "error": str(exc)}
