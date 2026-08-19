import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct CharacterLibraryView: View {
    @EnvironmentObject private var app: AppState
    @State private var editingCharacterID: UUID?
    @State private var showNewCharacter = false
    @State private var showImporter = false

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ZStack {
            CastmindBackground(accent: Color(hex: app.activeCharacter.accentHex))
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(app.library.characters) { character in
                            CharacterCard(character: character, active: character.id == app.library.activeCharacterID)
                                .onTapGesture { app.selectCharacter(character.id) }
                                .contextMenu {
                                    Button("Hablar", systemImage: "bubble.left.fill") { app.selectCharacter(character.id) }
                                    Button("Editar", systemImage: "slider.horizontal.3") { editingCharacterID = character.id }
                                    Button("Duplicar", systemImage: "plus.square.on.square") { _ = app.duplicateCharacter(character.id) }
                                    if app.library.characters.count > 1 {
                                        Button("Eliminar", systemImage: "trash", role: .destructive) { app.deleteCharacter(character.id) }
                                    }
                                }
                        }
                        Button { showNewCharacter = true } label: { NewCharacterCard() }.buttonStyle(.plain)
                    }
                    quickStats
                }
                .padding(16)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("Castmind")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { ModelStatusBadge() }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { showImporter = true } label: { Image(systemName: "square.and.arrow.down") }
                Button { showNewCharacter = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(item: Binding(
            get: { editingCharacterID.map { IdentifiedUUID(id: $0) } },
            set: { editingCharacterID = $0?.id }
        )) { wrapped in
            NavigationStack { CharacterEditorView(characterID: wrapped.id) }
        }
        .sheet(isPresented: $showNewCharacter) {
            NewCharacterSheet()
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first { app.importCharacter(from: url) }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tus personajes").font(.system(size: 31, weight: .bold, design: .rounded))
            Text("Cada uno tiene su propia identidad, voz, memoria y parámetros. El cerebro local se comparte.")
                .font(.subheadline).foregroundStyle(CM.textSecondary)
        }
    }

    private var quickStats: some View {
        CMCard {
            HStack {
                stat("Personajes", "\(app.library.characters.count)", "person.2.fill")
                Divider().overlay(CM.border)
                stat("Mensajes", "\(app.library.stats.totalUserMessages)", "bubble.left.fill")
                Divider().overlay(CM.border)
                stat("Recuerdos", "\(app.library.memories.count)", "brain.head.profile")
            }
        }
    }

    private func stat(_ title: String, _ value: String, _ icon: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon).foregroundStyle(CM.purple)
            Text(value).font(.headline.monospacedDigit())
            Text(title).font(.caption2).foregroundStyle(CM.textSecondary)
        }.frame(maxWidth: .infinity)
    }
}

private struct CharacterCard: View {
    @EnvironmentObject private var app: AppState
    let character: CharacterProfile
    let active: Bool

    var body: some View {
        let accent = Color(hex: character.accentHex)
        VStack(spacing: 12) {
            CharacterAvatarView(character: character, size: 92, speaking: active && app.speaker.isSpeaking, listening: active && app.recognizer.isListening, speechPulse: app.speaker.speechPulse, audioLevel: app.recognizer.audioLevel)
            VStack(spacing: 3) {
                Text(character.name).font(.headline).lineLimit(1)
                Text(character.subtitle).font(.caption).foregroundStyle(CM.textSecondary).lineLimit(1)
            }
            HStack(spacing: 5) {
                Circle().fill(active ? CM.green : CM.textTertiary).frame(width: 6, height: 6)
                Text(active ? "ACTIVO" : "LOCAL").font(.caption2.weight(.black)).tracking(0.7).foregroundStyle(active ? CM.green : CM.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(CM.elevated.opacity(0.88))
                .overlay(RoundedRectangle(cornerRadius: 26).stroke(active ? accent.opacity(0.58) : CM.border, lineWidth: active ? 1.5 : 1))
        )
    }
}

private struct NewCharacterCard: View {
    var body: some View {
        VStack(spacing: 12) {
            Circle().fill(Color.white.opacity(0.055)).frame(width: 92, height: 92).overlay(Image(systemName: "plus").font(.title.weight(.medium)).foregroundStyle(CM.textSecondary))
            VStack(spacing: 3) {
                Text("Nuevo").font(.headline)
                Text("Crear personaje").font(.caption).foregroundStyle(CM.textSecondary)
            }
            Text(" ").font(.caption2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(RoundedRectangle(cornerRadius: 26).fill(CM.elevated.opacity(0.55)).overlay(RoundedRectangle(cornerRadius: 26).stroke(style: StrokeStyle(lineWidth: 1, dash: [6])).foregroundStyle(CM.border)))
    }
}

private struct NewCharacterSheet: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                CastmindBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Empieza con una personalidad").font(.title2.bold())
                        Text("Después podrás editar absolutamente todo.").foregroundStyle(CM.textSecondary)
                        ForEach(CharacterPreset.allCases) { preset in
                            Button {
                                let id = app.createCharacter(preset: preset)
                                dismiss()
                                DispatchQueue.main.async { app.selectCharacter(id, openChat: false) }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(preset.title).font(.headline)
                                        Text(preset.prompt).font(.caption).foregroundStyle(CM.textSecondary).lineLimit(2)
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.right").foregroundStyle(CM.textSecondary)
                                }
                                .padding(16).background(CM.elevated, in: RoundedRectangle(cornerRadius: 18))
                            }.buttonStyle(.plain)
                        }
                        Button {
                            _ = app.createCharacter()
                            dismiss()
                        } label: { Label("Crear desde cero", systemImage: "plus").frame(maxWidth: .infinity) }
                            .buttonStyle(CMPrimaryButtonStyle())
                    }.padding(18)
                }
            }
            .navigationTitle("Nuevo personaje")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { dismiss() } } }
        }
    }
}

private struct IdentifiedUUID: Identifiable { let id: UUID }
