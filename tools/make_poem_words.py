# Analyses every word of the poem with the same prompt and cloud model as the visitors' words
# (each word with its verse as context) and writes language_viz/data/poem_words.json.
# raresa from wordfreq. Needs the Ollama key in language_viz/data/ollama_key.txt.
#   python3 -m venv venv && venv/bin/pip install wordfreq && venv/bin/python tools/make_poem_words.py
# Afterwards a few word classes were fixed by hand (i → 8, a / de / en / amb / del / des de → 5).
import json, os, re, sys, time, urllib.request
import wordfreq
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "language_viz")
P = open(os.path.join(ROOT, 'prompts', 'catala_art_system_prompt.md'), encoding='utf-8').read()
t = [l.strip() for l in open(os.path.join(ROOT, 'data', 'ollama_key.txt'), encoding='utf-8') if l.strip() and not l.strip().startswith('#')][0]
if '=' in t: t = t.split('=', 1)[1]
KEY = re.sub(r"[\"';\s]", "", t)
# (shown on the floor, word analysed)
POEM = [
 [("Diversos","diversos"),("són","són"),("els homes","homes"),("i","i"),("diverses","diverses"),("les parles","parles")],
 [("i","i"),("han convingut","convingut"),("molts noms","noms"),("a","a"),("un sol amor","amor")],
 [("La vella","vella"),("i","i"),("fràgil","fràgil"),("plata","plata"),("esdevé","esdevé"),("tarda","tarda")],
 [("parada","parada"),("en","en"),("la claror","claror"),("damunt","damunt"),("els camps","camps")],
 [("La terra","terra"),("amb","amb"),("paranys","paranys"),("de","de"),("mil","mil"),("fines","fines"),("orelles","orelles")],
 [("ha captivat","captivat"),("els ocells","ocells"),("de","de"),("les cançons","cançons"),("de","de"),("l’aire","aire")],
 [("Sí","sí"),("comprèn-la","comprendre"),("i","i"),("fes-la","fer"),("teva","teva"),("també","també")],
 [("des de","des"),("les oliveres","oliveres")],
 [("l’alta","alta"),("i","i"),("senzilla","senzilla"),("veritat","veritat"),("de","de"),("la presa","presa"),("veu","veu"),("del","del"),("vent","vent")],
 [("Diverses","diverses"),("són","són"),("les parles","parles"),("i","i"),("diversos","diversos"),("els homes","homes")],
 [("i","i"),("convindran","convindran"),("molts noms","noms"),("a","a"),("un sol amor","amor")],
]
ZIPF = [5.0, 4.5, 4.0, 3.5, 3.0, 2.5]
def raresa(w):
    z = wordfreq.zipf_frequency(w, 'ca')
    for i, c in enumerate(ZIPF):
        if z >= c: return i + 1, z
    return 7, z
cache = {}
def analyse(head, verse):
    key = head + "|" + verse
    if key in cache: return cache[key]
    user = head + "\nAnalitza-la amb el sentit que té en aquest vers d'un poema de Salvador Espriu: «" + verse + "»"
    body = {"model": "gemma4:31b", "stream": False, "options": {"temperature": 0},
            "messages": [{"role": "system", "content": P}, {"role": "user", "content": user}]}
    for attempt in range(3):
        try:
            r = json.load(urllib.request.urlopen(urllib.request.Request("https://ollama.com/api/chat", json.dumps(body).encode(),
                  {"Content-Type": "application/json", "Authorization": "Bearer " + KEY}), timeout=120))
            c = re.sub(r"^```(json)?|```$", "", r["message"]["content"].strip()).strip()
            o = json.loads(c); break
        except Exception as e:
            print("retry", head, e, file=sys.stderr); time.sleep(2)
    cache[key] = o
    return o
words = []
TEXT = ["Diversos són els homes i diverses les parles,","i han convingut molts noms a un sol amor.","La vella i fràgil plata esdevé tarda","parada en la claror damunt els camps.","La terra, amb paranys de mil fines orelles,","ha captivat els ocells de les cançons de l’aire.","Sí, comprèn-la i fes-la teva, també,","des de les oliveres,","l’alta i senzilla veritat de la presa veu del vent:","«Diverses són les parles i diversos els homes,","i convindran molts noms a un sol amor.»"]
for li, line in enumerate(POEM):
    for shown, head in line:
        o = analyse(head, TEXT[li])
        ra, z = raresa(head)
        rec = {"word": shown, "line": li + 1}
        for k in ["emotion","emotion_label","color_hex","word_class","abstraction","agency","organic","phenomena_class","time_duration","culturalitat"]:
            rec[k] = o[k]
        rec["raresa"] = ra
        words.append(rec)
        print(f"{shown:14s} {head:11s} cat={o.get('es_catala')} {o['emotion_label']:9s} cls={o['word_class']} ph={o['phenomena_class']} cu={o['culturalitat']} ra={ra} z={z:.2f} ", file=sys.stderr)
out = {"poem": "Diversos són els homes i diverses les parles", "author": "Salvador Espriu",
       "text": "\n".join(TEXT),
       "words": words}
json.dump(out, open(os.path.join(ROOT, 'data', 'poem_words.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
print(len(words), "words", file=sys.stderr)
