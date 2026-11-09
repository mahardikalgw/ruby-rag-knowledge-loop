---
name: rag-knowledge-loop
description: Build and tune an answer-grounded RAG assistant — a staff-approved knowledge corpus, idempotent import and re-embed tasks, fused lexical + vector retrieval, reply guardrails that refuse anything ungrounded, conversation ratings, and scripted test doubles. Use when adding an assistant, improving answer quality, adding a knowledge source, or when an assistant answers something it should have declined.
version: 2.0.0
---

# RAG knowledge loop

**No source, no answer.** Every rule here serves that one sentence. An assistant that invents a plausible
answer is worse than one that says "buat tiket" — the first teaches users to trust it.

The loop is **corpus → import → embed → retrieve → guard → measure → tune**. Each stage has one owner and
one test.

## When to activate

- Adding an assistant or a knowledge-grounded chat surface.
- A bad answer is reported ("it answered a concert question with a leave policy").
- Adding or re-importing a knowledge source.
- Changing a prompt, a threshold, or a retrieval weight.
- Writing tests for anything that calls a model.

## 1. The corpus is curated, not scraped

```jsonc
// db/data/campus_it_support_dataset.json
{
  "records": [
    {
      "source_ref": "kb/email/locked-account",
      "question": "Bagaimana cara membuka akun email yang terkunci?",
      "answer": "Akun terkunci setelah 5 percobaan gagal.",
      "troubleshooting": [
        "Tunggu 15 menit, lalu coba masuk kembali.",
        "Jika masih terkunci, hubungi agen dengan NIM dan unit kerja."
      ],
      "keywords": ["email", "terkunci", "lockout", "kata sandi salah"],
      "internal_diagnosis": "STAFF ONLY — never imported"
    }
  ]
}
```

- **`source_ref` is the idempotency key.** Import upserts on it, so re-running never duplicates.
- **Staff-only fields never enter the public answer.** The importer drops `internal_diagnosis` explicitly;
  it is not "filtered later".
- **A public answer is assembled, not copied:** answer + numbered steps + escalation line + a safety line
  ("never share passwords, OTP or personal data through a ticket"). One shape for every entry means the
  assistant has no first-person offer to imitate.
- **The importer strips dataset filler** (generic lead-ins, generic tails) so the same instruction is
  stated once, in the escalation line.

## 2. Embeddings are an optimisation, never a requirement

```ruby
Ai.embedder                    # Ai::Embedder when a key is configured
AI_LOCAL_EMBEDDINGS=1          # Ai::LocalEmbedder — deterministic hash vectors, no network, no key
# no key, no flag              # Ai::Embedder::Unavailable -> lexical retrieval only
```

- The local hashing embedder sets one bucket per normalised term and L2-normalises. It is functionally a
  sparse lexical vector: it proves the whole chat path end to end, and it is **not** semantic search.
- Because a "nearest neighbour" under hashing is often a hash collision, the retrieval entry point returns
  **no candidates at all** when the lexical path found nothing and the embedder is the local one. Saying
  nothing is more honest than guessing, and the assistant then offers a ticket.
- Re-embed whenever the embedded text changes (keywords, question, answer):

```bash
bin/rails knowledge:import
bin/rails knowledge:reembed_all
```

## 3. Retrieval fuses two signals

```ruby
Knowledge::Retrieval.call(workspace:, phrase:, limit: 6)
```

- **Lexical** (`Knowledge::Search`): weighted terms — question ×3, keywords ×2, answer ×1, floor of 3,
  stop words dropped, and a match needs **at least two** of the visitor's terms with at least one
  *specific* term. One shared generic word ("tiket", "berapa", "waktu") is not a topic.
- **Vector** (`Knowledge::VectorSearch`): cosine distance with a **distance ceiling**, so an unrelated
  phrase returns nothing rather than the closest thing in the corpus.
- **Fusion**: reciprocal rank fusion (rank-based, so no score normalisation) with a lexical weight above
  1.0, plus a rule that the best lexical hit leads regardless of fused score. That rule exists because an
  entry sharing one word appears in *both* lists and outscores the entry whose question is the visitor's
  exact words.

Both paths return the same `Hit` shape, so the caller never knows which one produced a candidate.

## 4. The model chooses; it never decides

The prompt receives three sources and nothing else: the visitor's own messages, the retrieved approved
entries, and the names of the workspace's categories and services. No ticket, no comment, no user row, no
account. A test asserts that against a workspace that has all of them.

The visitor's words and the knowledge block are **quoted data**, wrapped in delimiters, with an
instruction that they are not commands. A prompt-injection pre-filter answers obvious attempts
(`abaikan instruksi`, `ignore previous instructions`) with the fixed offer sentence before the model is
called at all.

## 5. Every rule lives in one reply object

`Assistant::Reply` is the only place a reply is composed:

| Rule | Behaviour |
|---|---|
| An answer needs a citation | No citation → no answer → the offer sentence |
| A clarification is a fixed sentence | Never model prose, so a loop cannot become a rant |
| A refusal names no record | "Masuk untuk melihat tiket Anda" — never an id, never a count |
| A provider failure offers the form | Not an error page; `Ai::Timeout` degrades to the offer |
| The assistant never promises work | `saya bisa buatkan tiket` is rejected and the entry answer stands |
| Vocabulary is canonical | `pending`, `in progress`, `customer` are rewritten to the product's own labels |
| Small talk is not retrieval | A greeting or thanks → a fixed reply, no model call, no citation |

## 6. Measure, then tune

Each answer is a conversation row with `outcome` (`answered`, `offered`, `converted`, `unanswered`) and a
rating. Ratings do **not** auto-create knowledge: an exchange that already rests on an approved entry would
duplicate the curated source, drift from it, and shadow it in retrieval. An administrator adds knowledge.

Tune in this order, and only with evidence from the unanswered list:

1. **Corpus** — is there an approved entry that should answer this? Usually the answer is no.
2. **Keywords** — did the visitor use words the entry does not contain? Add their phrasing.
3. **Lexical weights / floor** — only when the corpus is right and the ranking is wrong.
4. **Threshold** — only when vector hits are visibly unrelated.
5. **Prompt** — last. A prompt fix for a corpus gap is a rule that will not generalise.

## Prohibitions

| Never | Why |
|---|---|
| Answering without a citation | The whole product promise; "no source, no answer" |
| Letting the model see a ticket, user, or comment row | One prompt bug becomes a data breach |
| Auto-learning from rated conversations | Duplicates and shadows the curated corpus |
| A retrieval error surfacing as a 500 | `Ai::Error` degrades to the offer sentence |
| Tuning a prompt to fix a missing entry | The fix does not generalise to the next question |
| A canned answer under `app/` | Production must never answer a real visitor with fake text |
| Lowering the distance ceiling to "get more hits" | Unrelated hits are the failure being prevented |

## Done when

1. Every answer path has a citation, or the offer sentence.
2. A test asserts the prompt contains no ticket, comment, user or account data.
3. A test asserts an injection phrase never reaches the model.
4. An offline install (local embeddings, no key) still answers, and still declines what it cannot source.
5. The import task is idempotent — run twice, same corpus size.

## References

- [references/retrieval.md](references/retrieval.md) — scoring, fusion, thresholds, and the tuning log
- [references/guardrails.md](references/guardrails.md) — reply rules, injection, vocabulary, degradation
- [assets/ai_fake.rb](assets/ai_fake.rb) — the scripted model double for tests
- [assets/local_embedder.rb](assets/local_embedder.rb) — deterministic offline embeddings

