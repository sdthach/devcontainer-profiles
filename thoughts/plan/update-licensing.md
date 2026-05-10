# Apache 2.0 Transition Plan

Date: 2026-05-09
Branch: feature/update-licensing

## Goal

Align the repository's public-facing licensing metadata and documentation with Apache License 2.0 before publishing the repo, and record whether any additional attribution files are actually required.

## Status

Completed on 2026-05-09 for the repo-declared licensing surfaces. The root license file, public README, and planning docs now consistently reference Apache License 2.0.

Items 3, 4 and 5 below have now been verified.

## Current State

- The root `LICENSE` file already contains Apache License 2.0 text.
- `README.md` now declares the repo license as Apache License 2.0.
- `thoughts/plan/requirements.md` now matches the Apache 2.0 decision.
- There is no `NOTICE` file in the repo today by current choice.
- No evidence yet that Apache-specific per-file headers are required for this repo.

## Working Assumption

This was mostly a consistency cleanup, not a legal-structure change. The remaining useful check is an audit for any copied third-party material that may carry separate attribution or notice obligations.

## Files Already Identified

- `LICENSE`
- `README.md`
- `thoughts/plan/requirements.md`

## Plan

### 1. Align the repo's declared license everywhere it matters

- Update `README.md` so the public License section says Apache 2.0.
- Search the repo for stale license references and update any text that describes the current repo license.
- Keep historical notes only if they are clearly framed as history; otherwise rewrite them to match the current Apache decision.

### 2. Decide whether a `NOTICE` file is necessary

- Default to no `NOTICE` file unless there is upstream material that requires carried-forward notices, or you want to publish attribution text intentionally.
- If a `NOTICE` file is added, keep it informational only and consistent with Apache 2.0.
- Record the decision in the repo so future edits do not re-open the question.

### 3. Audit copied or third-party material

- Confirm the root `LICENSE` text remains the standard Apache 2.0 text.
- Review scripts, templates, docs, and config snippets for copied upstream content that may require attribution or preserved notices.
- Preserve any required third-party notices instead of assuming the root license covers them.

### 4. Optional clarity improvements

- Decide whether to add a small copyright/ownership note in docs or a `NOTICE` file.
- Decide whether to add SPDX headers to selected scripts or templates. This is optional for Apache 2.0 and should only be done if you want clearer downstream reuse signals.

### 5. Validate before merging

- Run a targeted search to confirm there are no stale license references outside intentionally historical text.
- Review the diff to ensure the branch only changes licensing language and any related attribution files.
- Re-read the public README license section after edits to ensure it matches the root `LICENSE` file.

## Verification Results

### Item 3. Audit copied or third-party material

- Verified that the root `LICENSE` file contains standard Apache License 2.0 text.
- Searched `scripts/`, `templates/`, `config/`, and `dotfiles/` for attribution markers such as `NOTICE`, `SPDX`, `Copyright`, `Copied from`, `Derived from`, and upstream-source comments.
- Read the highest-risk files with external URLs or reusable config content: `scripts/install-fonts.sh`, `scripts/install-tmux-plugins.sh`, `templates/pre-commit-base.yaml`, and `.pre-commit-config.yaml`.
- Result: current references are dependency or download URLs, not embedded third-party source blocks. No carried-forward third-party notice text surfaced in the reviewed repo content.

### Item 4. Optional clarity improvements

- Decision: do not add a `NOTICE` file at this time.
- Decision: do not add SPDX headers or per-file Apache headers at this time.
- Rationale: for the current repo content, the root `LICENSE` file and public `README.md` license section are sufficient, and no reviewed files surfaced separate attribution obligations.

### Item 5. Validate before merging

- Verified that stale MIT references are gone from the repo.
- Verified that the public `README.md` license section matches the Apache 2.0 root `LICENSE` file.
- Verified that the branch diff is not fully limited to licensing work because `.vscode/settings.json` contains unrelated UI color changes.
- Remaining action: keep the unrelated `.vscode/settings.json` change out of the licensing commit or split the work before merging.

## Suggested Checks

```bash
rg -n 'Apache-2\.0|Apache 2\.0|Apache License|NOTICE' .
git diff -- LICENSE README.md thoughts/plan
```

## Exit Criteria

- The root `LICENSE` file is Apache 2.0.
- The public `README.md` license section matches Apache 2.0.
- Stale license references are removed or explicitly preserved as historical context.
- A conscious `NOTICE` decision has been made.
- Any required third-party attribution or notice obligations are preserved.