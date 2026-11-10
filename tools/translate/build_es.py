"""Genera un espejo en español de los datos de StellaBase.

Descarga los mismos endpoints que usa la app, traduce al español los textos
descriptivos con Argos Translate (modelo libre que corre en local, sin API
ni claves) y escribe el resultado en public/es/.
Las traducciones se guardan en cache.json (clave = hash del texto original),
así cada ejecución sólo traduce lo nuevo.

Uso:  pip install argostranslate && python tools/translate/build_es.py
"""

import hashlib
import re
import json
import os
import sys
import time
import urllib.request
from pathlib import Path

import argostranslate.package
import argostranslate.translate

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "public" / "es"
CACHE_FILE = Path(__file__).with_name("cache.json")

GAME_API = "https://api.ennead.cc/stella"
SITE_API = "https://stella.ennead.cc/api"

GAME_LISTS = ["characters", "discs", "banners", "events",
              "news/news", "news/updates", "news/events", "news/notices"]
SITE_PATHS = ["enemies", "emblems", "monolith", "raids", "boss-blitz",
              "trace-hunts", "challenges"]

# Campos que se traducen. Los nombres propios (personajes, discos, objetos) se
# mantienen en inglés para que coincidan con el juego.
TEXT_KEYS = {"description", "shortDescription", "detailDescription", "text",
             "question", "flavor", "clue", "secondChoice", "unlockText"}
NEWS_KEYS = {"title"}  # títulos sólo en noticias

# Marcado del juego que nunca se traduce: etiquetas, parámetros, enlaces, entidades,
# saltos de línea y viñetas. Sólo se traducen los trozos de texto entre ellos.
MARKUP = re.compile(r"(<[^>]+>|&Param\d+&|\{\d+\}|##[^#]+#\d+#|&[a-zA-Z#0-9]+;|[\n\u000b]+|https?://\S+)")

# Glosario aplicado después de traducir, para que los términos del juego sean consistentes.
GLOSSARY = [
    (r"\bDMG\b", "daño"),
    (r"\bATK\b", "ATQ"),
    (r"\bHP\b", "Vida"),
    (r"\b[Ee]xcursionistas?\b", "Trekkers"),
    (r"\b[Ee]ntrenadores\b", "Trekkers"),
    (r"\bAuto Attack\b", "ataque básico"),
    (r"\bLa revista\b", "El cargador"),
    (r"\brevista\b", "cargador"),
    (r"\busted consigue\b", "obtienes"),
    (r"\bUsted consigue\b", "Obtienes"),
    (r"\bUltimate\b", "Definitiva"),
    (r"\bMain Skill\b", "Habilidad principal"),
    (r"\bSupport Skill\b", "Habilidad de apoyo"),
    (r"\bla cargador\b", "el cargador"),
    (r"\b[Aa]taque [Aa]utomático\b", "ataque básico"),
]


def polish(cache: dict):
    """Aplica el glosario también a traducciones antiguas de la caché."""
    for k, v in cache.items():
        for pat, rep_ in GLOSSARY:
            v = re.sub(pat, rep_, v)
        cache[k] = v


def setup_argos():
    """Descarga (una vez) el modelo inglés→español de Argos."""
    argostranslate.package.update_package_index()
    pkg = next(p for p in argostranslate.package.get_available_packages()
               if p.from_code == "en" and p.to_code == "es")
    installed = argostranslate.package.get_installed_packages()
    if not any(p.from_code == "en" and p.to_code == "es" for p in installed):
        argostranslate.package.install_from_path(pkg.download())


SENTENCE = re.compile(r"(?<=[.!?。])\s+(?=[A-Z0-9\"'(\[])")


class BatchEngine:
    """Traducción por lotes con el mismo modelo de Argos (CTranslate2), mucho más rápida en GPU.
    Se activa con TRANSLATE_DEVICE=cuda (o cpu para lotes en CPU)."""

    def __init__(self, device: str):
        import ctranslate2
        import sentencepiece
        pkg = next(p for p in argostranslate.package.get_installed_packages()
                   if p.from_code == "en" and p.to_code == "es")
        base = Path(pkg.package_path)
        self.sp = sentencepiece.SentencePieceProcessor(model_file=str(base / "sentencepiece.model"))
        self.tr = ctranslate2.Translator(str(base / "model"), device=device, compute_type="auto")
        self.memo: dict[str, str] = {}

    def translate_sentences(self, sentences: list[str]):
        todo = sorted({s for s in sentences if s not in self.memo}, key=len)
        for i in range(0, len(todo), 256):
            chunk = todo[i:i + 256]
            toks = self.sp.encode(chunk, out_type=str)
            res = self.tr.translate_batch(toks, max_batch_size=64, beam_size=2)
            for src, r in zip(chunk, res):
                self.memo[src] = self.sp.decode(r.hypotheses[0])


ENGINE: "BatchEngine | None" = None


def _segments(text: str):
    """Trozos traducibles de un texto (entre marcado), partidos en frases."""
    for part in MARKUP.split(text):
        if part and not MARKUP.fullmatch(part) and re.search(r"[A-Za-z]{2}", part):
            yield from (x for x in SENTENCE.split(part.strip()) if x)


def translate_text(text: str) -> str:
    if ENGINE is not None:
        out = []
        for part in MARKUP.split(text):
            if not part or MARKUP.fullmatch(part) or not re.search(r"[A-Za-z]{2}", part):
                out.append(part)
                continue
            lead = part[: len(part) - len(part.lstrip())]
            trail = part[len(part.rstrip()):]
            es = " ".join(ENGINE.memo.get(x, x) for x in SENTENCE.split(part.strip()) if x)
            out.append(lead + es + trail)
        result = "".join(out)
        for pat, rep_ in GLOSSARY:
            result = re.sub(pat, rep_, result)
        return result
    return _translate_text_argos(text)


def _translate_text_argos(text: str) -> str:
    parts = MARKUP.split(text)
    out = []
    for part in parts:
        if not part or MARKUP.fullmatch(part) or not re.search(r"[A-Za-z]{2}", part):
            out.append(part)
            continue
        lead = part[: len(part) - len(part.lstrip())]
        trail = part[len(part.rstrip()):]
        es = argostranslate.translate.translate(part.strip(), "en", "es")
        out.append(lead + es + trail)
    result = "".join(out)
    for pat, rep in GLOSSARY:
        result = re.sub(pat, rep, result)
    return result


def fetch(url: str):
    req = urllib.request.Request(url, headers={"User-Agent": "stella-trekkers-translator"})
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.loads(r.read().decode("utf-8"))
        except Exception as e:  # noqa: BLE001 - red inestable, reintentar
            if attempt == 3:
                raise
            print(f"  reintento {url}: {e}", file=sys.stderr)
            time.sleep(3 * (attempt + 1))


def key_of(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()[:24]


def collect(node, keys, out: set):
    if isinstance(node, dict):
        for k, v in node.items():
            if k in keys and isinstance(v, str) and v.strip():
                out.add(v)
            else:
                collect(v, keys, out)
    elif isinstance(node, list):
        for v in node:
            collect(v, keys, out)


def apply(node, keys, cache):
    if isinstance(node, dict):
        return {k: (cache.get(key_of(v), v) if k in keys and isinstance(v, str) else apply(v, keys, cache))
                for k, v in node.items()}
    if isinstance(node, list):
        return [apply(v, keys, cache) for v in node]
    return node


def translate_missing(texts: set, cache: dict):
    missing = sorted(t for t in texts if key_of(t) not in cache)
    print(f"Textos: {len(texts)} · nuevos por traducir: {len(missing)}")
    if ENGINE is not None and missing:
        sentences = [x for t in missing for x in _segments(t)]
        print(f"Traduciendo {len(sentences)} frases por lotes…")
        t0 = time.time()
        ENGINE.translate_sentences(sentences)
        print(f"Frases traducidas en {time.time() - t0:.0f} s")
    # Presupuesto de tiempo: al agotarse se publica lo que haya y la siguiente ejecución continúa.
    deadline = time.time() + float(os.environ.get("MAX_MINUTES", "270")) * 60
    for i, src in enumerate(missing, 1):
        if time.time() > deadline:
            print(f"Tiempo agotado: quedan {len(missing) - i + 1} textos para la próxima ejecución")
            break
        try:
            cache[key_of(src)] = translate_text(src)
        except Exception as e:  # noqa: BLE001 - si falla uno, queda en inglés
            print(f"  sin traducir: {src[:60]!r} ({e})", file=sys.stderr)
        if i % 50 == 0:
            print(f"  {i}/{len(missing)}")
            CACHE_FILE.write_text(json.dumps(cache, ensure_ascii=False, indent=0), encoding="utf-8")
    CACHE_FILE.write_text(json.dumps(cache, ensure_ascii=False, indent=0), encoding="utf-8")


def write(rel: str, data):
    path = OUT / f"{rel}.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")


def main():
    cache = json.loads(CACHE_FILE.read_text(encoding="utf-8")) if CACHE_FILE.exists() else {}
    setup_argos()
    global ENGINE
    device = os.environ.get("TRANSLATE_DEVICE", "").strip()
    if device:
        ENGINE = BatchEngine(device)
        print(f"Motor por lotes en {device}")

    docs: dict[str, tuple[object, set]] = {}
    for p in GAME_LISTS:
        keys = TEXT_KEYS | NEWS_KEYS if p.startswith("news/") else TEXT_KEYS
        docs[f"stella/{p}"] = (fetch(f"{GAME_API}/{p}?lang=EN"), keys)
    for c in docs["stella/characters"][0]:
        docs[f"stella/character/{c['id']}"] = (fetch(f"{GAME_API}/character/{c['id']}?lang=EN"), TEXT_KEYS)
    for d in docs["stella/discs"][0]:
        docs[f"stella/disc/{d['id']}"] = (fetch(f"{GAME_API}/disc/{d['id']}?lang=EN"), TEXT_KEYS)
    for p in SITE_PATHS:
        docs[f"site/{p}"] = (fetch(f"{SITE_API}/{p}"), TEXT_KEYS)

    texts: set = set()
    for data, keys in docs.values():
        collect(data, keys, texts)
    translate_missing(texts, cache)
    polish(cache)
    CACHE_FILE.write_text(json.dumps(cache, ensure_ascii=False, indent=0), encoding="utf-8")

    for rel, (data, keys) in docs.items():
        write(rel, apply(data, keys, cache))
    write("meta", {"generatedAt": int(time.time()), "documents": len(docs)})
    print(f"Listo: {len(docs)} documentos en {OUT}")


if __name__ == "__main__":
    main()
