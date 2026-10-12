# Exports the Catalan word frequencies of wordfreq to language_viz/data/catalan_freq.tsv
# (one line per word: word <tab> zipf × 100). Run once; the sketch only reads the file.
#   python3 -m venv venv && venv/bin/pip install wordfreq
#   venv/bin/python tools/make_catalan_freq.py
# Data: wordfreq (https://github.com/rspeer/wordfreq), CC BY-SA 4.0.
import os
import wordfreq

out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "language_viz", "data", "catalan_freq.tsv")
words = wordfreq.get_frequency_dict("ca", "large")
with open(out, "w", encoding="utf-8") as f:
    for w in words:
        f.write(f"{w}\t{round(wordfreq.zipf_frequency(w, 'ca') * 100)}\n")
print(len(words), "words →", os.path.normpath(out))
