# Castmind V3.3.0 — Validation report

## Completed locally

- All Swift sources parse with `swiftc -frontend -parse -swift-version 5`.
- Pure-Swift conversation tests pass:
  - detects the observed `¿Lo... ¿Lo...` collapse;
  - detects repeated room answers;
  - detects meta statements about following a role/prompt;
  - accepts a normal conversational Spanish response;
  - deterministic persona compilation returns identical identity text for different user queries;
  - a synthetic 368k-character behavior prompt compiles below the per-model budget;
  - legacy V3.2 generation defaults are lifted to healthy Qwen sampling;
  - BALANCED maps to Qwen3.5 2B and QUALITY maps to Qwen3 4B.
- Static invariants verified:
  - MLX `ChatSession` receives structured `history`;
  - direct/room transcripts are not embedded in the system prompt;
  - room history maps own speech to assistant and other speakers to tagged user messages;
  - TopK=20, MinP=0 and presence/repetition penalties are configured;
  - low-temperature V3.2 repair settings are gone;
  - raw generation is not streamed into the visible chat/TTS before validation.
- `project.yml`, Info.plist and workflow structured syntax validated.
- Workflow/version updated to 3.3.0 build 330.

## Source/API verification

The pinned MLX Swift LM 3.31.4 API was checked against its source for:
- `ChatSession(... history: [Chat.Message] ...)` prompt re-hydration;
- `GenerateParameters.topK`, `minP`, `presencePenalty`, `frequencyPenalty`, repetition settings;
- Qwen3 0.6B, Qwen3.5 2B and Qwen3 4B registry constants.

## Remaining device validation

This container has no Xcode/iOS SDK and cannot run Metal/MLX on an iPhone. GitHub Actions is therefore the final SwiftUI/MLX typecheck+link/build gate, and the physical iPhone is the final quality/memory test.
