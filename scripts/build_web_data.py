"""Build a compact, anonymized browser snapshot from the prepared report tables."""
from pathlib import Path
import csv, json, gzip
ROOT = Path(__file__).resolve().parents[1]

def rows(name):
    with (ROOT / 'powerbi/Data' / name).open(newline='', encoding='utf8') as f:
        return list(csv.DictReader(f))

def num(x):
    return float(x) if x else None

def cents(x):
    return round(float(x) * 100)
orders = [o for o in rows('Orders.csv') if o['Status'] == 'delivered']
months = sorted({o['Date'][:7] for o in rows('Date.csv')})
states = sorted({o['State'] for o in orders})
items = rows('Items.csv')
payments = rows('Payments.csv')
lookup = {o['Order ID']: i for i, o in enumerate(orders)}
items = [i for i in items if i['Order ID'] in lookup]
payments = [p for p in payments if p['Order ID'] in lookup]
categories = sorted({i['Category'] for i in items})
methods = sorted({p['Payment Method'] for p in payments})
mi = {s: i for i, s in enumerate(months)}
si = {s: i for i, s in enumerate(states)}
ci = {s: i for i, s in enumerate(categories)}
pi = {s: i for i, s in enumerate(methods)}
payload = {'months': months, 'states': states, 'categories': categories, 'methods': methods, 'orders': [[int(o['Customer ID']), mi[o['Purchase Date'][:7]], si[o['State']], num(o['Delivery Days']), num(o['Delay Days']), num(o['Review Score'])] for o in orders], 'items': [[lookup[i['Order ID']], ci[i['Category']], int(i['Seller ID']), cents(i['Product Value']), cents(i['Freight Value'])] for i in items], 'payments': [[lookup[p['Order ID']], pi[p['Payment Method']], cents(p['Payment Value'])] for p in payments]}
raw = json.dumps(payload, separators=(',', ':'), allow_nan=False).encode()
compressed = gzip.compress(raw, mtime=0)
(ROOT / 'web/data.json.gz').write_bytes(compressed)
(ROOT / 'web/data.json').write_bytes(raw)
print('Web snapshot:', len(orders), 'orders;', len(raw), 'JSON bytes;', len(compressed), 'compressed bytes')
