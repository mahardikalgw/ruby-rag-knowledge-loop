# RAG knowledge loop

Build and tune an answer-grounded RAG assistant — a staff-approved knowledge corpus, idempotent import and re-embed tasks, fused lexical + vector retrieval, reply guardrails that refuse anything ungrounded, conversation ratings, and scripted test doubles. Use when adding an assistant, improving answer quality, adding a knowledge source, or when an assistant answers something it should have declined.

One skill, one repository. Part of a twelve-skill pack extracted from a production Rails 8 +
Inertia + React helpdesk monolith — the opinionated layer no public Rails or shadcn skill can know.
Version `2.0.0` tracks the source constitution.

## Install

```jsonc
// skills-lock.json
{
  "version": 1,
  "skills": {
    "rag-knowledge-loop": {
      "source": "mahardikalgw/rag-knowledge-loop",
      "sourceType": "github",
      "skillPath": "SKILL.md"
    }
  }
}
```

Or clone and symlink:

```bash
git clone git@github.com:mahardikalgw/rag-knowledge-loop.git
ln -s "$PWD/rag-knowledge-loop" .claude/skills/rag-knowledge-loop
```

## When to activate

- Adding an assistant or a knowledge-grounded chat surface.
- A bad answer is reported ("it answered a concert question with a leave policy").
- Adding or re-importing a knowledge source.
- Changing a prompt, a threshold, or a retrieval weight.
- Writing tests for anything that calls a model.

## What's inside

```
rag-knowledge-loop/
  SKILL.md
  assets/ai_fake.rb
  assets/local_embedder.rb
  references/guardrails.md
  references/retrieval.md
```

`SKILL.md` is a router (kept under 250 lines) — the depth lives in `references/`, and the
copy-in code lives in `assets/`.

## Validate

```bash
./bin/check-skill
```

Checks frontmatter, the activation section, link resolution, orphaned references, script
executability, leftover placeholders, and — when the source app is checked out next to this
repository — that vendored scripts still match it byte for byte. Runs in CI on every push.

## Related skills

- [`inertia-test-harness`](https://github.com/mahardikalgw/inertia-test-harness) — minitest + inertia helpers, builder objects, and system tests that do not flake
- [`scoped-authorization`](https://github.com/mahardikalgw/scoped-authorization) — scopes, 404-not-403, explicit public opt-outs, isolation by construction
- [`indonesian-product-copy`](https://github.com/mahardikalgw/indonesian-product-copy) — Indonesian copy in two files, server-owned labels, honest placeholders

## Licence

MIT — see [LICENSE](LICENSE).
