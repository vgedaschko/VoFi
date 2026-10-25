import re, sys
out = open('out.md', encoding='utf-8').read().splitlines()
keys = [(r'^## Beispiel \(a\)', 'a'), (r'^### \(a3\)', 'a3'), (r'^## Beispiel \(d\)', 'd'),
        (r'^## Beispiel \(b\)', None), (r'^### \(b1\)', 'b1'), (r'^### \(b2\)', 'b2'),
        (r'^## Beispiel \(c\)', None), (r'^### \(c1\)', 'c1'), (r'^### \(c2\)', 'c2'),
        (r'^## Beispiel \(e\)', 'e'), (r'^## Test \(f\)', 'f')]
chunks, cur = {}, None
for line in out:
    hit = None
    for pat, k in keys:
        if re.match(pat, line):
            hit = (k,)
            break
    if hit is not None:
        cur = hit[0]
        if cur:
            chunks[cur] = []
        continue
    if cur:
        chunks[cur].append(line)
tpl = open('template_01.md', encoding='utf-8').read()
for k, v in chunks.items():
    body = "\n".join(v).strip("\n")
    body = body.replace("**Kennzahlen ", "**Kennzahlen Beispiel ")
    ph = "{{" + k + "}}"
    assert ph in tpl, ph
    tpl = tpl.replace(ph, body)
script = open('vofi_ref.py', encoding='utf-8').read().rstrip("\n")
tpl = tpl.replace("{{SCRIPT}}", script)
assert "{{" not in tpl, re.findall(r"\{\{\w+\}\}", tpl)
open(sys.argv[1], 'w', encoding='utf-8').write(tpl)
print("written", len(tpl))
