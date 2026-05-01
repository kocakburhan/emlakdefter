"""
BI Analytics Period Filter Tests

Tests the /analytics/bi-dashboard endpoint respects the period parameter.
Requires backend running on localhost:8000.

Run: pytest tests/test_analytics_period.py -v
"""
import subprocess
import sys


def test_bi_dashboard_respects_period_param():
    for period, expected in [("1m", 1), ("3m", 3), ("6m", 6), ("12m", 12)]:
        result = subprocess.run(
            [sys.executable, "tests/verify_period.py", period],
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            raise AssertionError(f"period={period} failed: {result.stderr}")
        print(result.stdout.strip())


def test_bi_dashboard_default_is_12m():
    result = subprocess.run(
        [sys.executable, "tests/verify_period.py", "check"],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise AssertionError(f"default test failed: {result.stderr}")
    print(result.stdout.strip())
