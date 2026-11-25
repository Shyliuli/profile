#!/usr/bin/env python3
# AGENT SAFETY: 用户要求创建个人自用的 ask-llm 技能（provider/model 管理与问答）
"""ask-llm: 管理 provider/model 并提问；配置默认 ~/.config/ask-llm/config.yaml。"""
import json, os, re, ssl, sys, urllib.request, yaml

CFG = os.environ.get("ASK_LLM_CONFIG", os.path.expanduser("~/.config/ask-llm/config.yaml"))
EP = {"openai": "/chat/completions", "response": "/responses", "anthropic": "/messages"}
MAX_TOKENS = 96 * 1024  # 现代模型给足输出预算，不再卡在 8k
CTX = ssl.create_default_context()
CTX.set_alpn_protocols(["http/1.1"])


def load():
    if not os.path.exists(CFG):
        return {"providers": {}, "models": {}}
    with open(CFG) as f:
        return yaml.safe_load(f) or {"providers": {}, "models": {}}


def save(c):
    os.makedirs(os.path.dirname(CFG), exist_ok=True)
    with open(CFG, "w") as f:
        yaml.safe_dump(c, f, allow_unicode=True, sort_keys=False)


def url(base, typ, kind):
    b, path = base.rstrip("/"), EP[typ] if kind == "chat" else "/models"
    for s in EP.values():
        if b.endswith(s):
            b = b[:-len(s)]
    return b + path if re.search(r"/v\d+$", b) else b + "/v1" + path


def call(u, p, data=None):
    h = {"Content-Type": "application/json"}
    if p["type"] == "anthropic":
        h.update({"x-api-key": p["apikey"], "anthropic-version": "2023-06-01"})
    else:
        h["Authorization"] = "Bearer " + p["apikey"]
    req = urllib.request.Request(u, json.dumps(data).encode() if data else None, h)
    with urllib.request.urlopen(req, timeout=120, context=CTX) as f:
        return json.load(f)


def main():
    cmd, *a = sys.argv[1:]
    c = load()
    if cmd == "list":
        print(yaml.safe_dump(c, allow_unicode=True, sort_keys=False))
    elif cmd == "provider":
        name, typ, base, key = a
        c["providers"][name] = {"type": typ, "base": base, "apikey": key, "model_list": []}
        save(c)
    elif cmd == "models":
        p = c["providers"][a[0]]
        p["model_list"] = [m["id"] for m in call(url(p["base"], p["type"], "models"), p).get("data", [])]
        save(c)
        print("\n".join(p["model_list"]))
    elif cmd == "model":
        c["models"][a[0]] = {"desc": a[1]}
        save(c)
    elif cmd == "ask":
        prov, mid = a[0].split("/", 1)
        p = c["providers"][prov]
        d = {"model": mid, "messages": [{"role": "user", "content": a[1]}]}
        if p["type"] == "response":
            d["max_output_tokens"] = MAX_TOKENS
        else:
            d["max_tokens"] = MAX_TOKENS
        if len(a) > 2 and a[2] != "off":
            t = a[2]
            if p["type"] == "response":
                d["reasoning"] = {"effort": t}
            elif p["type"] == "anthropic":
                budget = {"low": 1024, "medium": 4096, "high": 8192}[t]
                d["thinking"] = {"type": "enabled", "budget_tokens": budget}
            else:
                d["reasoning_effort"] = t
        r = call(url(p["base"], p["type"], "chat"), p, d)
        if p["type"] == "response":
            print("".join(x.get("text", "") for i in r.get("output", []) for x in i.get("content", [])))
        elif p["type"] == "anthropic":
            print("".join(x.get("text", "") for x in r.get("content", [])))
        else:
            print(r["choices"][0]["message"]["content"])
    else:
        raise SystemExit("用法见 SKILL.md")


if __name__ == "__main__":
    main()
