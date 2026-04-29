---
name: skill-creator
description: Framework for creating, evaluating, and improving Claude Code skills. Use when building new skills, running eval loops, or improving skill descriptions based on benchmark results.
license: Complete terms in LICENSE.txt
---

# Skill Creator

A development framework for building and iterating on Claude Code skills using automated evaluation loops.

## Workflow

1. Write a `SKILL.md` with frontmatter: `name`, `description`, `license`
2. Create eval queries in `evals.json` (train/test split)
3. Run `scripts/run_loop.py` to iteratively improve the skill description
4. Review results in the eval viewer (`scripts/generate_report.py`)
5. Package the skill with `scripts/package_skill.py`

## SKILL.md Format

```markdown
---
name: skill-name          # kebab-case, unique
description: One-line description ≤1024 chars — this is what triggers the skill
license: Complete terms in LICENSE.txt
---

# Skill content here...
```

## Key Scripts

- `scripts/run_loop.py` — runs eval + improve loop, picks best description by test score
- `scripts/run_eval.py` — tests skill trigger accuracy via `claude -p` subprocess
- `scripts/improve_description.py` — generates improved descriptions from eval failures
- `scripts/quick_validate.py` — validates SKILL.md frontmatter (kebab-case, ≤1024 chars, no angle brackets)
- `scripts/package_skill.py` — packages skill folder into a `.skill` ZIP archive
- `scripts/aggregate_benchmark.py` — aggregates grading.json files, writes benchmark.json

## Agents

- `agents/grader.md` — grades skill outputs PASS/FAIL with structured JSON
- `agents/comparator.md` — blind A/B comparison of two skill descriptions
- `agents/analyzer.md` — post-hoc analysis of benchmark results

## Reference

- Full schemas: `references/schemas.md`
- Eval viewer: `eval-viewer/viewer.html`
