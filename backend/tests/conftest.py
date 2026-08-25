import os
import sys
from pathlib import Path

# Force the mock routing provider so tests never call the public OSRM
# server. Must run BEFORE any `from app...` import in test modules —
# conftest.py is loaded first by pytest so this is safe.
os.environ.setdefault("MYTRAVELPAL_ROUTING", "mock")
# Same rationale for the other external providers — tests must not
# hammer Overpass / NASA FIRMS / etc. on every run.
os.environ.setdefault("MYTRAVELPAL_HOTELS", "mock")
os.environ.setdefault("MYTRAVELPAL_FUEL", "mock")
os.environ.setdefault("MYTRAVELPAL_RESTAURANTS", "mock")
os.environ.setdefault("MYTRAVELPAL_FIRES", "off")
os.environ.setdefault("MYTRAVELPAL_SKIP_PREWARM", "1")

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
