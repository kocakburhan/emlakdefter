"""Verify bi-dashboard period filter via live HTTP request."""
import sys
import urllib.request
import json

# Import test cases from command line args
mode = sys.argv[1] if len(sys.argv) > 1 else "check"

if mode == "check":
    # No argument = test default (12m)
    url = "http://localhost:8000/api/v1/analytics/bi-dashboard"
    req = urllib.request.Request(url, headers={"Authorization": "Bearer dev_bypass_token_12345"})
    with urllib.request.urlopen(req) as resp:
        data = json.loads(resp.read())
    months = len(data["financial"]["monthly_breakdown"])
    assert months == 12, f"default test: expected 12 months, got {months}"
    print(f"OK default period ({months} months)")
else:
    # Argument = period value
    period = sys.argv[1]
    expected = int(period[:-1])
    url = f"http://localhost:8000/api/v1/analytics/bi-dashboard?period={period}"
    req = urllib.request.Request(url, headers={"Authorization": "Bearer dev_bypass_token_12345"})
    with urllib.request.urlopen(req) as resp:
        data = json.loads(resp.read())
    months = len(data["financial"]["monthly_breakdown"])
    assert months == expected, f"period={period}: expected {expected}, got {months}"
    print(f"OK period={period} ({months} months)")
