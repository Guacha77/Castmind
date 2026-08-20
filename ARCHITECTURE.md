# Castmind V3.3 — Conversation architecture

## Direct chat

1. User message is persisted.
2. Character behavior is compiled into a deterministic, bounded identity core.
3. Relevant memories are selected separately.
4. Recent conversation is converted to structured roles (`user` / `assistant`).
5. MLX `ChatSession` is re-hydrated from that history and receives the current turn as a new user message.
6. The raw draft is held off-screen.
7. `ReplySanitizer` + `ResponseQualityGuard` validate it.
8. A failed draft gets one fresh hidden retry with healthy sampling.
9. Only a validated answer is committed, spoken, bridged to OBS, and allowed into future context.
10. Session/KV/transient Metal cache is cleared after the turn.

## Rooms

Every character sees the same room through its own independent perspective:

- its own previous room messages -> `assistant`;
- human messages -> `user` prefixed `[USUARIO]`;
- other characters -> `user` prefixed `[NOMBRE]`.

Only one character is generated at a time. A malformed/duplicated intervention is never appended to the room, so it cannot contaminate subsequent agents.

This mirrors the important structure in DougDoug's public multi-agent implementation while remaining fully local.

## Models

- FAST: Qwen3 0.6B 4-bit
- BALANCED / default: Qwen3.5 2B 4-bit
- QUALITY: Qwen3 4B 4-bit

Balanced uses 8-bit KV cache for better conversational fidelity. Other modes use 4-bit KV to preserve RAM headroom.

## Sampling

Conversation generation follows Qwen non-thinking guidance as closely as practical on-device:

- temperature around 0.7
- top-p around 0.8
- top-k 20
- min-p 0
- repetition + presence penalties to suppress loops

Long character prompts reduce context/output budgets, not sampling entropy.
