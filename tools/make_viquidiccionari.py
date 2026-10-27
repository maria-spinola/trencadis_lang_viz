# Exports the Catalan words of the Viquidiccionari and their definitions to
# language_viz/data/viquidiccionari_ca.tsv, so the
# sketch can look words up with no internet (CatalanLLM.pde: localDefinition). Run once in a while;
# the sketch only reads the file.
#   curl -L -o cawiktionary.xml.bz2 https://dumps.wikimedia.org/cawiktionary/latest/cawiktionary-latest-pages-articles.xml.bz2
#   python3 tools/make_viquidiccionari.py cawiktionary.xml.bz2
# The definitions are cleaned as the sketch cleans the ones it reads online (lookupDefinition): up to
# 3 per word, templates and links removed. One line per word:
#   word <tab> definition
#   word <tab> @base     an inflected form without its own: the sketch gives "(forma de base) " + base's
#   word <tab> >target   a redirect: the target's
# (forms and redirects point to their word instead of copying its text: ten times smaller)
# Data: Viquidiccionari (https://ca.wiktionary.org), CC BY-SA 4.0.
import bz2, os, re, sys
import xml.etree.ElementTree as ET

CA = re.compile(r"\{\{-ca-\}\}(.*?)(\n== \{\{-|\Z)", re.S)
FORM = re.compile(r"\{\{(?:forma-[a-z]+\|ca|ca-forma-conj)\|([^|}]+)")

def clean(l):
    d = re.sub(r"^#+", "", l).strip()
    d = re.sub(r"\{\{[^}]*\}\}", "", d)                      # templates (region marks…)
    d = re.sub(r"\[\[(?:[^|\]]*\|)?([^\]]*)\]\]", r"\1", d)   # [[link|text]] → text
    d = re.sub(r"''+", "", d)
    return re.sub(r"\s+", " ", d).strip()

defs, lemmas, redirects = {}, {}, {}
src = sys.argv[1]
for ev, el in ET.iterparse(bz2.open(src), events=("end",)):
    if not el.tag.endswith("}page"):
        continue
    ns = el.find("{*}ns")
    if ns is None or ns.text != "0":
        el.clear(); continue
    title = el.find("{*}title").text
    red = el.find("{*}redirect")
    text = el.find("{*}revision/{*}text").text or ""
    if red is not None:
        redirects[title] = red.get("title")
    else:
        m = CA.search(text)
        if m:
            ds = []
            for l in m.group(1).split("\n"):
                if not l.startswith("#") or l.startswith("#:") or l.startswith("#*"):
                    continue
                d = clean(l)
                if d and len(ds) < 3:
                    ds.append(d)
            if ds:
                defs[title] = " / ".join(ds)
            else:
                fm = FORM.search(m.group(1))
                if fm:
                    lemmas[title] = fm.group(1).strip()
    el.clear()

out = dict(defs)
for w, lemma in lemmas.items():   # inflected forms: their base word's definition
    if lemma in defs:
        out[w] = "@" + lemma
for w, target in redirects.items():
    if w not in out and target in out and not out[target].startswith(">"):
        out[w] = ">" + target

path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "language_viz", "data", "viquidiccionari_ca.tsv")
with open(path, "w", encoding="utf-8") as f:
    for w in sorted(out):
        f.write(w.replace("\t", " ") + "\t" + out[w].replace("\t", " ").replace("\n", " ") + "\n")
print(len(out), "Catalan words (", len(defs), "with definitions,", len(out) - len(defs), "forms / redirects ) →", os.path.normpath(path))
