import os
import glob
import requests
from llama_cpp import Llama
from duckduckgo_search import DDGS
from dotenv import load_dotenv

load_dotenv()

# ---------- Load model ----------
MODEL_PATH = "/app/models/tinyllama-1.1b-chat-v0.3.Q4_K_M.gguf"
llm = Llama(model_path=MODEL_PATH, n_threads=4)

# ---------- Load text chunks ----------
def load_chunks(folder, query=None):
    texts = []
    for f in glob.glob(f"{folder}/*.txt"):
        try:
            with open(f, "r", encoding="utf-8") as file:
                text = file.read()
                if query is None or any(w.lower() in text.lower() for w in query.split()):
                    texts.append(text)
        except Exception:
            continue
    return texts

# ---------- Wikipedia search ----------
def wiki_search(query, max_results=2):
    if len(query.split()) < 3:
        return ""
    url = "https://en.wikipedia.org/w/api.php"
    params = {
        "action": "query", "list": "search", "srsearch": query,
        "utf8": 1, "format": "json", "srlimit": max_results
    }
    try:
        resp = requests.get(url, params=params, timeout=5)
        resp.raise_for_status()
        results = resp.json().get("query", {}).get("search", [])
        return "\n".join(
            [r["snippet"].replace("<span class=\"searchmatch\">", "").replace("</span>", "")
             for r in results]
        )
    except Exception:
        return ""

# ---------- DuckDuckGo search ----------
def web_search(query, max_results=2):
    if len(query.split()) < 3:
        return ""
    try:
        ddgs = DDGS()
        results = ddgs.text(query, max_results=max_results)
        return "\n".join([f"{r['title']}: {r['body']}" for r in results])
    except Exception:
        return ""

# ---------- Detect code language ----------
def detect_code_language(query):
    q = query.lower()
    if any(k in q for k in ["python", "py"]): return "Python"
    if any(k in q for k in ["c#", "csharp"]): return "C#"
    if "lua" in q: return "Lua"
    return None

# ---------- Main AI query ----------
def query_ai(prompt, robotic_mode=False):
    short_prompt = len(prompt.split()) <= 3

    # System prompt
    if robotic_mode:
        system_prompt = "Answer short, precise, strictly factual."
        temperature = 0.05
    elif short_prompt:
        system_prompt = "Answer briefly and directly."
        temperature = 0.2
    else:
        system_prompt = (
            "Answer clearly and directly. "
            "Do not repeat yourself. "
            "Keep responses concise."
        )
        temperature = 0.5

    # Local code chunks
    lang = detect_code_language(prompt)
    code_context = "\n".join(load_chunks(f"/app/ai_data/code_chunks/{lang}", query=prompt) if lang else [])

    # GCSE chunks
    gcse_context = "\n".join(load_chunks("/app/ai_data/gcse_chunks", query=prompt))

    # External search if needed
    use_external = len(prompt.split()) > 2 and not code_context and not gcse_context
    wiki_info = wiki_search(prompt) if use_external else ""
    web_info = web_search(prompt) if use_external and not wiki_info else ""

    # Combine context
    full_context = system_prompt
    for label, text in [
        ("CODE", code_context),
        ("GCSE", gcse_context),
        ("WIKIPEDIA", wiki_info),
        ("WEB", web_info),
    ]:
        if text:
            full_context += f"\n=== {label} ===\n{text}\n"

    # Truncate
    MAX_CONTEXT_LENGTH = 2000
    if len(full_context) > MAX_CONTEXT_LENGTH:
        full_context = system_prompt + full_context[-MAX_CONTEXT_LENGTH:]

    # Generate
    prompt_text = f"{full_context}\n{prompt}\nAnswer:"
    response = llm(
        prompt_text,
        max_tokens=256,
        temperature=temperature,
        stop=["\n\n", "In the context", "The word"]
    )
    answer = response["choices"][0]["text"].strip()

    return answer
