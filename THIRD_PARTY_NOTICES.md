# Third-party notices — Castmind V2

Castmind no incluye servicios de IA de pago ni claves de API. Utiliza componentes open-source y modelos descargados bajo demanda.

## iOS / Swift
- **MLX Swift LM 3.31.4** — MIT — ml-explore/mlx-swift-lm
- **MLX Swift** (dependencia transitiva) — MIT — ml-explore/mlx-swift
- **swift-huggingface 0.9.0** — Apache-2.0 — huggingface/swift-huggingface
- **swift-transformers 1.3.0** — Apache-2.0 — huggingface/swift-transformers

## Modelos configurados
Los pesos no se redistribuyen dentro del IPA; se descargan desde Hugging Face al elegir un perfil.
- `mlx-community/Qwen3-0.6B-4bit` — Apache-2.0
- `mlx-community/Qwen3.5-2B-4bit` — Apache-2.0
- `mlx-community/Qwen3-4B-4bit` — Apache-2.0

## Companion Windows
Las dependencias Python se instalan por `pip` y no se incluyen vendorizadas en este repositorio:
- websockets
- zeroconf
- obsws-python
- pyttsx3

Consulta las licencias de las versiones indicadas en `PC-Companion/requirements.txt` antes de redistribuir un binario empaquetado del companion.

Este archivo es informativo y no sustituye los textos de licencia de cada proyecto upstream.
