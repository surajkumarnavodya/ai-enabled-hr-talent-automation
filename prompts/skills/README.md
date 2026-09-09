# Skills Prompt Index

> Owner: [TENANT_CONFIGURATION_REQUIRED — AI Governance Lead] | Status: Draft

This directory is reserved for skill-specific prompt *fragments* (e.g., few-shot examples, output-format reminders) that are composed into the system prompts under `prompts/system/`. The system prompts themselves are the source of truth for each skill's behavior — see [agent-skill-catalog.md](../../docs/06-ai-agents-rag/agent-skill-catalog.md).

## Convention

- One subdirectory per skill if/when fragment files are added (e.g., `prompts/skills/candidate-matching/few-shot-examples.md`).
- Every fragment file must declare which system prompt(s) it composes into, and carry the same version/ownership header convention as `prompts/system/*.md`.
- Fragments containing example candidate/JD data must use fake/demo data only (Section 7, CLAUDE.md).

## Cross-references

[prompt-management.md](../../docs/06-ai-agents-rag/prompt-management.md) for versioning/approval process. [ai-evaluation-strategy.md](../../docs/06-ai-agents-rag/ai-evaluation-strategy.md) for how fragment changes are tested.

## Change control

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-09-07 | Documentation package generation | Initial creation |
