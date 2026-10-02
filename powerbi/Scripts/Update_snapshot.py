"""Update the embedded snapshot from the prepared CSVs. Python standard library only."""
from pathlib import Path
import json,gzip,base64,csv,io

root=Path(__file__).resolve().parents[1]
path=root/'Olist.SemanticModel/model.bim'
model=json.loads(path.read_text(encoding='utf-8'))
for table in model['model']['tables']:
    source=root/'Data'/f'{table["name"].replace(" ","_")}.csv'
    data=source.read_bytes()
    headers=next(csv.reader(io.StringIO(data.decode('utf-8-sig'))))
    expected=[c['name'] for c in table['columns']]
    if headers != expected:
        raise ValueError(f'{source.name}: expected columns {expected}; found {headers}')
    encoded=base64.b64encode(gzip.compress(data,mtime=0)).decode()
    chunks=[encoded[i:i+24000] for i in range(0,len(encoded),24000)]
    table['partitions'][0]['source']['expression'][1]='    Encoded = Text.Combine({'+','.join('"'+s+'"' for s in chunks)+'}),'
backup=path.with_suffix('.bim.backup')
backup.write_bytes(path.read_bytes())
temp=path.with_suffix('.bim.tmp')
temp.write_text(json.dumps(model,indent=2,ensure_ascii=False),encoding='utf-8')
temp.replace(path)
print('Embedded snapshot updated. Reopen the project, click Refresh, and recheck the report. Backup: '+str(backup))
