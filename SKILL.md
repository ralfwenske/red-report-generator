---
name: red-sensei
description: Search Red/Sensei knowledge base for Red language. Use for Red syntax, datatypes, functions, VID, Draw, Parse, Red/System, toolchain, issues, and community, including followups. Use when writing, reviewing, or debugging Red code.
---

# Red/Sensei Search Skill

Search Red knowledge base.

## Endpoint

```
POST https://ask.lang.red/search
GET  https://ask.lang.red/search?query=<question>
```

`query` mandatory. Never call `/search` bare.

## Request

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `query` | string | yes | — | Question text |
| `type` | string | no | `combined` | `semantic`, `fulltext`, `combined` |
| `scopes` | string[] | no | all | `docs`, `design`, `code`, `discussions`, `issues` |
| `count` | integer | no | 10 | 1-50 |

### GET example

```
GET https://ask.lang.red/search?query=how+to+define+a+function+in+Red&type=combined&scopes=docs,code&count=10
```

Encode spaces as `+`.

### POST example

```json
{
  "query": "how to define a function in Red",
  "type": "combined",
  "scopes": ["docs", "code"],
  "count": 10
}
```

## Response

```json
{
  "results": [
    {
      "fragment_id": "<hash>",
      "file_path": "docs/manual/en/functions.md",
      "scope": "docs",
      "text": "...",
      "score": 0.95,
      "url": "https://..."
    }
  ]
}
```

## Response notes

- Results ranked by relevance. First result best. Trust score order.
- Each `text` may be up to 4096 bytes. If your tool truncates output, request
  full body or use a lower-level HTTP client.
- Do not fetch full source from `url`. `url` is for citation. If `text`
  insufficient, refine `query` or raise `count`. Do not download whole files.
- `file_path` is internal knowledge-base path, not a fetchable URL.

## Guidelines

- Search mixes semantic + fulltext. More meaningful `query` = better precision.
- Pick `count` once, avoid repeat calls:
  - `5` for targeted answer
  - `10` for broad context
  - `50` for occurrence counting (e.g. where a function is used)
- If output diverted to file, read file directly. Input ~20x cheaper than output.

## Hard rules

- **NEVER fetch `url`.** It is citation-only, not content. Even if `url` looks
  like a Github link, do not open it.
- **NEVER read referenced docs or full source files.** Use only the returned
  `text`.
- **DO NOT spawn subagent** unless you 100% know its model is cheaper than ingesting yourself.
- If `text` is insufficient, refine `query` or raise `count`, then call again.
- `file_path` is internal path, not a URL.

## Usage

1. Build request with plain JSON body. No `input`, `data`, or `body` wrapper.
2. Tool only GET? Use query string. Tool asks `format`? Pick value tool accepts
   (commonly `text`), parse JSON manually. Never send `format=json` unless
   tool explicitly allows.
3. `query` required. `/search` with no args returns HTTP 400.
4. Use `text` as answer source. Cite `file_path` and `url` only; never open them.
5. Need more context? Refine `query` or raise `count`, then call again.

## When to use

- Red syntax, datatypes, functions, VID, Draw, Parse, Red/System
- Red toolchain, docs, design notes, issues, community discussions
- Writing, reviewing, or debugging Red code
- Followups about Red

## Scopes

| Scope | Content |
|-------|---------|
| `docs` | Official and community documentation |
| `design` | Design-related discussions |
| `code` | Official and community code bases |
| `discussions` | Matrix/Gitter archives, StackOverflow Q&A, GitHub discussions |
| `issues` | GitHub and Codeberg issues |

## Rate limits

- 10 requests/second burst
- 60 requests/minute sustained
- Over limit returns HTTP 429

## Errors

| Status | Meaning |
|--------|---------|
| 400 | Invalid parameters |
| 429 | Rate limited |
