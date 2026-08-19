import Foundation
import PhotosUI
import SwiftUI

struct CharacterEditorView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    let characterID: UUID

    @State private var draft: CharacterProfile?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showAdvanced = false

    var body: some View {
        ZStack {
            CastmindBackground(accent: CM.orange)
            if var character = draft {
                ScrollView {
                    VStack(spacing: 12) {
                        avatarHeader(character)
                        identity(binding())
                        behavior(binding())
                        memory(binding())
                        voice(binding())
                        generation(binding())
                        destructive(character)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .padding(.bottom, 28)
                }
                .scrollDismissesKeyboard(.interactively)
            } else { ProgressView().tint(CM.orange) }
        }
        .navigationTitle("CHARACTER_CFG")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar") {
                    if var draft {
                        let clean = draft.behaviorPrompt?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        if clean.isEmpty { draft.behaviorPrompt = draft.effectiveBehavior }
                        app.updateCharacter(draft)
                    }
                    dismiss()
                }.fontWeight(.bold)
            }
        }
        .onAppear {
            guard let found = app.library.characters.first(where: { $0.id == characterID }) else { return }
            var copy = found
            if copy.behaviorPrompt?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
                copy.behaviorPrompt = copy.effectiveBehavior
            }
            draft = copy
        }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    app.setAvatar(data: data, for: characterID)
                    draft?.avatarFilename = app.library.characters.first(where: { $0.id == characterID })?.avatarFilename
                }
            }
        }
    }

    private func binding() -> Binding<CharacterProfile> {
        Binding(get: { draft ?? .blank() }, set: { draft = $0 })
    }

    private func avatarHeader(_ character: CharacterProfile) -> some View {
        HStack(spacing: 14) {
            CharacterAvatarView(character: character, size: 92, speaking: app.speaker.isSpeaking && app.activeCharacter.id == character.id, speechPulse: app.speaker.speechPulse)
            VStack(alignment: .leading, spacing: 8) {
                Text(character.name.uppercased()).font(.system(.title2, design: .monospaced).weight(.black))
                Text("ID_\(character.id.uuidString.prefix(8))").font(.caption2.monospaced()).foregroundStyle(CM.textTertiary)
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Text(character.avatarFilename == nil ? "[+] AÑADIR IMAGEN" : "[↻] CAMBIAR IMAGEN")
                        .font(.system(.caption, design: .monospaced).weight(.bold)).foregroundStyle(CM.orange)
                }
            }
            Spacer()
        }
        .padding(12).overlay(Rectangle().stroke(CM.border))
    }

    private func identity(_ c: Binding<CharacterProfile>) -> some View {
        CMCard {
            VStack(alignment: .leading, spacing: 12) {
                CMSectionTitle(title: "Identidad", subtitle: "Solo datos visuales y de llamada")
                field("NOMBRE", c.name)
                field("ETIQUETA", c.subtitle)
                field("WAKE WORD", c.wakeWord)
                HStack(spacing: 8) {
                    ForEach(["FF4B17","D8DAD5","67D49A","FFCC33","FF5C55","58A6FF"], id: \.self) { hex in
                        Button { c.wrappedValue.accentHex = hex } label: {
                            Rectangle().fill(Color(hex: hex)).frame(width: 31, height: 25)
                                .overlay(Rectangle().stroke(c.wrappedValue.accentHex == hex ? Color.white : CM.border, lineWidth: c.wrappedValue.accentHex == hex ? 2 : 1))
                        }
                    }
                }
            }
        }
    }

    private func behavior(_ c: Binding<CharacterProfile>) -> some View {
        CMCard {
            VStack(alignment: .leading, spacing: 10) {
                CMSectionTitle(title: "Comportamiento", subtitle: "Este prompt manda sobre el resto del contexto")
                Text("Escribe aquí todo: identidad, personalidad, objetivos, forma de hablar, relación contigo, manías y reglas.")
                    .font(.caption).foregroundStyle(CM.textSecondary)
                TextEditor(text: Binding(get: { c.wrappedValue.behaviorPrompt ?? "" }, set: { c.wrappedValue.behaviorPrompt = $0 }))
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 260)
                    .padding(8)
                    .background(Color.black.opacity(0.28))
                    .overlay(Rectangle().stroke(CM.strongBorder))
                Text("PRIORIDAD_01 / STRICT_BEHAVIOR").font(.caption2.monospaced().bold()).foregroundStyle(CM.orange)
            }
        }
    }

    private func memory(_ c: Binding<CharacterProfile>) -> some View {
        CMCard {
            VStack(alignment: .leading, spacing: 11) {
                CMSectionTitle(title: "Memoria")
                Toggle("Memoria activa", isOn: c.memory.enabled)
                Toggle("Guardar automáticamente", isOn: c.memory.autoCapture).disabled(!c.wrappedValue.memory.enabled)
                Stepper("Máx. recuerdos en contexto: \(c.wrappedValue.memory.maxPromptMemories)", value: c.memory.maxPromptMemories, in: 2...10)
                NavigationLink { MemoryView(characterID: characterID) } label: {
                    HStack { Text("ABRIR MEMORIA").font(.caption.monospaced().bold()); Spacer(); Text("\(app.library.memories.filter { $0.characterID == characterID }.count)").monospacedDigit() }
                }
            }
        }
    }

    private func voice(_ c: Binding<CharacterProfile>) -> some View {
        CMCard {
            VStack(alignment: .leading, spacing: 11) {
                CMSectionTitle(title: "Voz")
                Toggle("Leer respuestas", isOn: c.voice.autoSpeak)
                Toggle("Hablar mientras genera", isOn: c.voice.speakWhileGenerating).disabled(!c.wrappedValue.voice.autoSpeak)
                Picker("Voz", selection: Binding(get: { c.wrappedValue.voice.voiceIdentifier ?? "__system__" }, set: { c.wrappedValue.voice.voiceIdentifier = $0 == "__system__" ? nil : $0 })) {
                    Text("Sistema iOS").tag("__system__")
                    ForEach(app.speaker.spanishVoices, id: \.identifier) { Text("\($0.name) · \($0.language)").tag($0.identifier) }
                }
                Button("PROBAR VOZ") { app.speaker.preview(settings: c.wrappedValue.voice, locale: app.settings.speechLocale, characterName: c.wrappedValue.name) }
                    .font(.caption.monospaced().bold()).foregroundStyle(CM.orange)
            }
        }
    }

    private func generation(_ c: Binding<CharacterProfile>) -> some View {
        CMCard {
            VStack(alignment: .leading, spacing: 11) {
                CMSectionTitle(title: "Generación", subtitle: "Valores conservadores = más obediencia y estabilidad")
                valueSlider("TEMPERATURA", c.generation.temperature, 0.1...1.0)
                valueSlider("TOP_P", c.generation.topP, 0.6...1.0)
                Stepper("MAX TOKENS: \(c.wrappedValue.generation.maxTokens)", value: c.generation.maxTokens, in: 48...256, step: 16)
                    .font(.caption.monospaced())
                DisclosureGroup("AVANZADO", isExpanded: $showAdvanced) {
                    VStack(alignment: .leading, spacing: 10) {
                        Stepper("CONTEXTO: \(c.wrappedValue.generation.recentContextMessages)", value: c.generation.recentContextMessages, in: 3...10)
                        Text("El modelo es global y compartido para evitar recargas de RAM al cambiar de personaje.")
                            .font(.caption).foregroundStyle(CM.textSecondary)
                    }.padding(.top, 8)
                }
            }
        }
    }

    private func destructive(_ character: CharacterProfile) -> some View {
        HStack {
            Button("DUPLICAR") { _ = app.duplicateCharacter(character.id) }
            Spacer()
            if app.library.characters.count > 1 {
                Button("ELIMINAR", role: .destructive) { app.deleteCharacter(character.id); dismiss() }
            }
        }.font(.caption.monospaced().bold()).padding(12).overlay(Rectangle().stroke(CM.border))
    }

    private func field(_ label: String, _ text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption2.monospaced().bold()).foregroundStyle(CM.textTertiary)
            TextField(label, text: text).textFieldStyle(.plain).padding(9).background(Color.black.opacity(0.22)).overlay(Rectangle().stroke(CM.border))
        }
    }

    private func valueSlider(_ label: String, _ value: Binding<Double>, _ range: ClosedRange<Double>) -> some View {
        VStack(spacing: 5) {
            HStack { Text(label).font(.caption.monospaced()); Spacer(); Text(String(format: "%.2f", value.wrappedValue)).font(.caption.monospacedDigit()) }
            Slider(value: value, in: range).tint(CM.orange)
        }
    }
}
