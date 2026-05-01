"""Verify ytd and py periods."""
import urllib.request, json

for period in ['ytd', 'py']:
    url = f'http://localhost:8000/api/v1/analytics/bi-dashboard?period={period}'
    req = urllib.request.Request(url, headers={'Authorization': 'Bearer dev_bypass_token_12345'})
    with urllib.request.urlopen(req) as resp:
        data = json.loads(resp.read())
    months = len(data['financial']['monthly_breakdown'])
    print(f'period={period} -> {months} months')