import PhotosUI
import SwiftUI

struct CharacterEditorView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    let characterID: UUID

    @State private var draft: CharacterProfile?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showAdvanced = false
    @State private var useOwnModel = false

    var body: some View {
        ZStack {
            CastmindBackground(accent: Color(hex: draft?.accentHex ?? "9C6BFF"))
            if var character = draft {
                ScrollView {
                    VStack(spacing: 18) {
                        identityHeader(character: character)
                        identityCard(character: binding())
                        personalityCard(character: binding())
                        voiceCard(character: binding())
                        memoryCard(character: binding())
                        relationshipCard(character: binding())
                        generationCard(character: binding())
                        emotionCard(character: binding())
                        dangerCard(character: character)
                    }
                    .padding(16)
                    .padding(.bottom, 34)
                }
                .scrollDismissesKeyboard(.interactively)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Editar personaje")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar") {
                    if let draft { app.updateCharacter(draft) }
                    dismiss()
                }.fontWeight(.semibold)
            }
        }
        .onAppear {
            if let found = app.library.characters.first(where: { $0.id == characterID }) {
                draft = found
                useOwnModel = found.preferredModel != nil
            }
        }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    app.setAvatar(data: data, for: characterID)
                    if let updated = app.library.characters.first(where: { $0.id == characterID }) {
                        draft?.avatarFilename = updated.avatarFilename
                    }
                }
            }
        }
    }

    private func binding() -> Binding<CharacterProfile> {
        Binding(
            get: { draft ?? CharacterProfile.blank() },
            set: { draft = $0 }
        )
    }

    private func identityHeader(character: CharacterProfile) -> some View {
        VStack(spacing: 10) {
            CharacterAvatarView(character: character, size: 132, speaking: app.speaker.isSpeaking && app.activeCharacter.id == character.id, listening: false, speechPulse: app.speaker.speechPulse)
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Label(character.avatarFilename == nil ? "Añadir imagen" : "Cambiar imagen", systemImage: "photo")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Color(hex: character.accentHex))
            }
        }
    }

    private func identityCard(character: Binding<CharacterProfile>) -> some View {
        CMCard {
            VStack(alignment: .leading, spacing: 14) {
                CMSectionTitle(title: "Identidad", subtitle: "Lo que define cómo aparece y cómo lo llamas")
                labeledField("Nombre", text: character.name)
                labeledField("Subtítulo", text: character.subtitle)
                labeledField("Rol", text: character.role)
                labeledField("Wake word", text: character.wakeWord)
                VStack(alignment: .leading, spacing: 8) {
                    Text("COLOR").font(.caption2.weight(.black)).foregroundStyle(CM.textTertiary)
                    HStack(spacing: 10) {
                        ForEach(["9C6BFF", "62D8FF", "62E6A8", "FFAA5C", "FF657D", "F178FF"], id: \.self) { hex in
                            Button { character.wrappedValue.accentHex = hex } label: {
                                Circle().fill(Color(hex: hex)).frame(width: 30, height: 30)
                                    .overlay(Circle().stroke(Color.white, lineWidth: character.wrappedValue.accentHex == hex ? 2 : 0))
                            }
                        }
                    }
                }
            }
        }
    }

    private func personalityCard(character: Binding<CharacterProfile>) -> some View {
        CMCard {
            VStack(alignment: .leading, spacing: 14) {
                CMSectionTitle(title: "Personalidad", subtitle: "El prompt del personaje se puede editar por completo")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(CharacterPreset.allCases) { preset in
                            Button(preset.title) { character.wrappedValue.personality = preset.prompt; character.wrappedValue.subtitle = preset.title }
                                .buttonStyle(.bordered).tint(Color(hex: character.wrappedValue.accentHex))
                        }
                    }
                }
                textEditor("Personalidad", text: character.personality, minHeight: 150)
                textEditor("Forma de hablar", text: character.speakingStyle, minHeight: 95)
                textEditor("Límites", text: character.boundaries, minHeight: 90)
                labeledField("Saludo inicial", text: character.greeting)
            }
        }
    }

    private func voiceCard(character: Binding<CharacterProfile>) -> some View {
        CMCard {
            VStack(alignment: .leading, spacing: 13) {
                CMSectionTitle(title: "Voz", subtitle: "TTS del iPhone, sin APIs")
                Toggle("Leer respuestas en alto", isOn: character.voice.autoSpeak)
                Toggle("Hablar mientras genera", isOn: character.voice.speakWhileGenerating)
                    .disabled(!character.wrappedValue.voice.autoSpeak)
                Picker("Voz", selection: Binding(
                    get: { character.wrappedValue.voice.voiceIdentifier ?? "__system__" },
                    set: { character.wrappedValue.voice.voiceIdentifier = $0 == "__system__" ? nil : $0 }
                )) {
                    Text("Automática de iOS").tag("__system__")
                    ForEach(app.speaker.spanishVoices, id: \.identifier) { voice in
                        Text("\(voice.name) · \(voice.language)").tag(voice.identifier)
                    }
                }
                .pickerStyle(.menu)
                slider("Velocidad", value: character.voice.rate, range: 0.35...0.62, format: "%.2f")
                slider("Tono", value: character.voice.pitch, range: 0.70...1.25, format: "%.2f")
                Button {
                    app.speaker.preview(settings: character.wrappedValue.voice, locale: app.settings.speechLocale, characterName: character.wrappedValue.name)
                } label: { Label("Probar voz", systemImage: "speaker.wave.2.fill") }
                    .buttonStyle(.borderedProminent).tint(Color(hex: character.wrappedValue.accentHex))
            }
        }
    }

    private func memoryCard(character: Binding<CharacterProfile>) -> some View {
        CMCard {
            VStack(alignment: .leading, spacing: 13) {
                CMSectionTitle(title: "Memoria", subtitle: "Es completamente independiente para este personaje")
                Toggle("Memoria activa", isOn: character.memory.enabled)
                Toggle("Guardar recuerdos automáticamente", isOn: character.memory.autoCapture)
                    .disabled(!character.wrappedValue.memory.enabled)
                Toggle("Olvido inteligente", isOn: character.memory.allowDecay)
                    .disabled(!character.wrappedValue.memory.enabled)
                Stepper("Recuerdos por respuesta: \(character.wrappedValue.memory.maxPromptMemories)", value: character.memory.maxPromptMemories, in: 3...18)
                    .disabled(!character.wrappedValue.memory.enabled)
                NavigationLink {
                    MemoryView(characterID: characterID)
                } label: {
                    HStack { Label("Gestionar recuerdos", systemImage: "brain.head.profile"); Spacer(); Text("\(app.library.memories.filter { $0.characterID == characterID }.count)").foregroundStyle(CM.textSecondary) }
                }
            }
        }
    }


    private func relationshipCard(character: Binding<CharacterProfile>) -> some View {
        CMCard {
            VStack(alignment: .leading, spacing: 13) {
                CMSectionTitle(title: "Relaciones", subtitle: "Opiniones persistentes sobre viewers, amigos u otros personajes")
                NavigationLink {
                    RelationshipsView(characterID: characterID)
                } label: {
                    HStack {
                        Label("Gestionar relaciones", systemImage: "person.2.wave.2")
                        Spacer()
                        Text("\(character.wrappedValue.relationships.count)").foregroundStyle(CM.textSecondary)
                    }
                }
            }
        }
    }

    private func generationCard(character: Binding<CharacterProfile>) -> some View {
        CMCard {
            VStack(alignment: .leading, spacing: 13) {
                CMSectionTitle(title: "Generación", subtitle: "Los parámetros se guardan solo para este personaje")
                slider("Creatividad", value: character.generation.temperature, range: 0.1...1.15, format: "%.2f")
                Stepper("Longitud máxima: \(character.wrappedValue.generation.maxTokens) tokens", value: character.generation.maxTokens, in: 48...512, step: 16)
                DisclosureGroup("Avanzado", isExpanded: $showAdvanced) {
                    VStack(spacing: 13) {
                        slider("Top P", value: character.generation.topP, range: 0.60...1.0, format: "%.2f")
                        Stepper("Contexto reciente: \(character.wrappedValue.generation.recentContextMessages)", value: character.generation.recentContextMessages, in: 4...16)
                        Toggle("Usar modelo propio", isOn: $useOwnModel)
                            .onChange(of: useOwnModel) { _, enabled in
                                if enabled && character.wrappedValue.preferredModel == nil { character.wrappedValue.preferredModel = app.settings.modelChoice }
                                if !enabled { character.wrappedValue.preferredModel = nil }
                            }
                        if useOwnModel {
                            Picker("Modelo", selection: Binding(
                                get: { character.wrappedValue.preferredModel ?? app.settings.modelChoice },
                                set: { character.wrappedValue.preferredModel = $0 }
                            )) {
                                ForEach(LocalModelChoice.allCases) { Text($0.title).tag($0) }
                            }.pickerStyle(.menu)
                        }
                    }.padding(.top, 10)
                }
            }
        }
    }

    private func emotionCard(character: Binding<CharacterProfile>) -> some View {
        CMCard {
            VStack(alignment: .leading, spacing: 13) {
                CMSectionTitle(title: "Estado", subtitle: "Evoluciona con la conversación; también puedes corregirlo manualmente")
                slider("Ira", value: character.emotion.anger, range: 0...100, format: "%.0f")
                slider("Confianza", value: character.emotion.trust, range: 0...100, format: "%.0f")
                slider("Energía", value: character.emotion.energy, range: 0...100, format: "%.0f")
                slider("Humor", value: character.emotion.mood, range: 0...100, format: "%.0f")
                slider("Estrés", value: character.emotion.stress, range: 0...100, format: "%.0f")
                slider("Entusiasmo", value: character.emotion.excitement, range: 0...100, format: "%.0f")
                slider("Afecto", value: character.emotion.affection, range: 0...100, format: "%.0f")
            }
        }
    }

    private func dangerCard(character: CharacterProfile) -> some View {
        CMCard {
            VStack(spacing: 10) {
                Button(role: .destructive) {
                    _ = app.duplicateCharacter(character.id)
                } label: { Label("Duplicar personaje", systemImage: "plus.square.on.square").frame(maxWidth: .infinity) }
                .buttonStyle(.bordered)
                if app.library.characters.count > 1 {
                    Button(role: .destructive) {
                        app.deleteCharacter(character.id)
                        dismiss()
                    } label: { Label("Eliminar personaje", systemImage: "trash").frame(maxWidth: .infinity) }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private func labeledField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased()).font(.caption2.weight(.black)).foregroundStyle(CM.textTertiary)
            TextField(label, text: text).textFieldStyle(.plain).padding(11).background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 13))
        }
    }

    private func textEditor(_ label: String, text: Binding<String>, minHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased()).font(.caption2.weight(.black)).foregroundStyle(CM.textTertiary)
            TextEditor(text: text)
                .scrollContentBackground(.hidden)
                .frame(minHeight: minHeight)
                .padding(8)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 13))
        }
    }

    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, format: String) -> some View {
        VStack(spacing: 6) {
            HStack { Text(title).font(.subheadline); Spacer(); Text(String(format: format, value.wrappedValue)).font(.caption.monospacedDigit()).foregroundStyle(CM.textSecondary) }
            Slider(value: value, in: range).tint(Color(hex: draft?.accentHex ?? "9C6BFF"))
        }
    }
}
