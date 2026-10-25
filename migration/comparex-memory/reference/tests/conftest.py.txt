import sys
from pathlib import Path

import pytest
import yaml

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))


@pytest.fixture(scope="session")
def cfg():
    return yaml.safe_load((ROOT / "memory_config.yaml").read_text())
