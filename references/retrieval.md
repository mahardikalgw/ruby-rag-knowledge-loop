# Retrieval: scoring, fusion, thresholds, tuning log

## Lexical scoring

```ruby
QUESTION_WEIGHT = 3   # the question is the best signal: it is the shortest, most specific text
KEYWORD_WEIGHT  = 2   # curated phrasings the visitor actually types
ANSWER_WEIGHT   = 1   # everything else in the body
FLOOR           = 3   # below this, an answer would be a guess dressed as a citation
MIN_TERM_LENGTH = 3
MIN_MATCHED_TERMS = 2 # one shared word is not a topic
```

Pipeline:

1. **Tokenise** — downcase, strip punctuation, split, drop stop words, drop terms under 3 characters.
2. **Match** — for each entry, count which of the visitor's terms appear in question / keywords / answer.
3. **Two gates**, both required:
   - `matched.size >= 2`
   - at least one matched term is in the entry's **question or keywords** (not merely the answer)
4. **Score** — sum the weights of the matched fields.
5. **Order** — score desc, then `approved_at` desc, then `id` desc. Deterministic: two equally relevant
   entries resolve the same way on every request.

### Why the gates, not just a score

`"kapan waktu yang tepat"` and `"berapa harga tiket konser"` both matched a leave-policy entry through
words that appear everywhere (`waktu`, `tiket`, `berapa`). A score alone cannot separate them; a
requirement for **two** matches, one of them specific, can. Keep a `GENERIC_TERMS` list and treat a term in
it as non-specific.

## Vector search

```ruby
workspace.knowledge_entries
         .active
         .where.not(embedding: nil)
         .nearest_neighbors(:embedding, vector, distance: "cosine", threshold: threshold)
         .first(limit)
```

- `threshold` is a **distance ceiling** (default 0.5, configurable). A hit must be closer than it. The
  ceiling is the mechanism that turns "best guess" into "nothing found".
- `rescue Ai::Error` returns `[]`. A provider outage degrades; it never raises into the request.
- Entries without an embedding are skipped, so a half-embedded corpus still answers lexically.

## Fusion

```ruby
CANDIDATES     = 6     # more than the old top-3, so a near-duplicate wording in 6th can still win
RRF_K          = 60    # rank-fusion constant; higher flattens the ranks
LEXICAL_WEIGHT = 1.2   # an exact term match should outrank a fuzzy neighbour
```

```ruby
score(entry) = Σ over each list: weight / (RRF_K + rank + 1)
```

Reciprocal rank fusion needs no score normalisation — it only uses ranks, so a cosine distance and a
keyword count can be combined at all.

### The lexical-leader rule

After fusing, the best lexically-scored entry is moved to the front. Without it, an entry that shares one
word appears in **both** lists, collects a weak contribution from each, and beats the entry whose question
is the visitor's exact words — which appears in only one list. That is how `"kamu bisa eskalasi ke teknisi
gak?"` once handed the chooser a camera entry first.

## The locally-embedded case

```ruby
return [] if lexical.empty? && hash_embedder?
```

With the hashing embedder a nearest neighbour is a hash collision as often as a meaning. When not a single
entry shares a term with the visitor's words, the vector hits are noise; returning them produces confident
answers to unrelated questions. An empty result is honest, and the assistant offers a ticket.

## Thresholds to start from

| Corpus size | Embedder | Notes |
|---|---|---|
| < 50 entries | lexical only | Vector adds noise at this size; the floor is enough |
| 50–200 | lexical + vector | Revisit the ceiling with real misses, not with intuition |
| 200+ | lexical + vector, tune weights | At this size the ranked candidates matter more than the truth |

Revisit retrieval architecture when the corpus passes ~200 entries, when deflection stays under 40% for
two months, or when the unanswered list is dominated by questions the words themselves explain.

## The tuning log

Keep one line per bad answer. This is the highest-value document in a RAG project, because it is the only
record of *why* a weight or a gate exists.

| Symptom | Cause | Fix |
|---|---|---|
| A greeting got a wall of policy text | `kasih` matched a leave-policy entry | small-talk classification **before** retrieval |
| A concert question got a leave policy | one generic term matched | `MIN_MATCHED_TERMS = 2` + generic-term gate |
| A remark about speed got a backup answer | vector-only hit under hashing | return `[]` when lexical is empty and the embedder is local |
| `"kamu bisa eskalasi ke teknisi gak?"` chose a camera entry | the one-word-sharing entry appeared in both lists | lexical weight 1.2 + lexical-leader promotion |
| A follow-up ("terus gimana?") answered from a new topic | each turn retrieved independently | topic carried from the previous citation; a pure continuation answers from it |
| The assistant offered to make the ticket itself | model copied a first-person offer | `TICKET_PROMISE` pattern rejects the text; the entry answer stands |
| Model output used "pending", "in progress", "customer" | no vocabulary rule | `Assistant::Vocabulary` names the canonical labels and rejects synonyms |
| Two rated conversations became duplicate knowledge | auto-learning was on | removed; ratings record, administrators curate |

Reading this table is the shortest path from "the assistant said something odd" to the rule that governs
it — and the fastest way to avoid re-learning a fix that already exists.
