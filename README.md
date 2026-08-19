# Castmind

Castmind is a native SwiftUI iOS app prepared for local on-device LLM inference with MLX Swift LM and Qwen.

The repository is intended to be built from Windows through GitHub Actions on macOS:

Windows -> GitHub -> GitHub Actions macOS -> unsigned IPA -> AltStore.

## Build

Run the `Build unsigned IPA` workflow manually from GitHub Actions. It generates a `Castmind-unsigned-ipa` artifact containing `Castmind-unsigned.ipa` and `Castmind-unsigned.ipa.sha256`.

## Local model

The app uses `mlx-community/Qwen3-1.7B-4bit` through MLX Swift LM. The model is not bundled in the repository or IPA; it is downloaded on demand from inside the app.
