import os
import sys
from pathlib import Path

# Force the mock routing provider so tests never call the public OSRM
# server. Must run BEFORE any `from app...` import in test modules —
# conftest.py is loaded first by pytest so this is safe.
os.environ.setdefault("MYTRAVELPAL_ROUTING", "mock")

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
