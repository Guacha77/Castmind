import Foundation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct CharacterLibraryView: View {
    @EnvironmentObject private var app: AppState
    @State private var editingID: UUID?
    @State private var showCreate = false
    @State private var showImporter = false

    var body: some View {
        ZStack {
            CastmindBackground(accent: CM.orange)
            ScrollView {
                LazyVStack(spacing: 0) {
                    header
                    ForEach(Array(app.library.characters.enumerated()), id: \.element.id) { index, character in
                        characterRow(index: index + 1, character: character)
                    }
                    Button { showCreate = true } label: {
                        HStack { Text("+").font(.title2.monospaced().bold()); Text("NEW_CHARACTER").font(.body.monospaced().bold()); Spacer() }
                            .foregroundStyle(CM.orange).padding(16).overlay(Rectangle().stroke(CM.border))
                    }.buttonStyle(.plain)
                }.padding(12)
            }
        }
        .navigationBarHidden(true)
        .sheet(item: Binding(get: { editingID.map(IdentifiedUUID.init) }, set: { editingID = $0?.id })) { value in
            NavigationStack { CharacterEditorView(characterID: value.id) }
        }
        .sheet(isPresented: $showCreate) { NewCharacterSheet() }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json, .data]) { result in if case .success(let url) = result { app.importCharacter(from: url) } }
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack {
                Text("CASTMIND_SYS").font(.system(.title2, design: .monospaced).weight(.black))
                Spacer()
                ModelStatusBadge()
            }.padding(.vertical, 14)
            HStack {
                Text("CHAR_INDEX").font(.caption.monospaced().bold()).foregroundStyle(CM.textSecondary)
                Spacer()
                Button("IMPORT") { showImporter = true }.font(.caption.monospaced().bold()).foregroundStyle(CM.orange)
                Button("NEW [+]") { showCreate = true }.font(.caption.monospaced().bold()).foregroundStyle(CM.orange)
            }.padding(.vertical, 9)
            Rectangle().fill(CM.strongBorder).frame(height: 1)
        }
    }

    private func characterRow(index: Int, character: CharacterProfile) -> some View {
        HStack(spacing: 12) {
            Text(String(format: "%02d", index)).font(.caption.monospacedDigit()).foregroundStyle(CM.textTertiary).frame(width: 24)
            CharacterAvatarView(character: character, size: 72)
            VStack(alignment: .leading, spacing: 5) {
                Text(character.name.uppercased()).font(.system(.headline, design: .monospaced).weight(.black)).foregroundStyle(.white)
                Text(character.subtitle).font(.caption).foregroundStyle(CM.textSecondary).lineLimit(1)
                HStack(spacing: 8) {
                    Circle().fill(character.id == app.library.activeCharacterID ? CM.green : CM.textTertiary).frame(width: 6, height: 6)
                    Text(character.id == app.library.activeCharacterID ? "ACTIVE" : "LOCAL").font(.caption2.monospaced().bold()).foregroundStyle(CM.textSecondary)
                    Text("MEM_\(app.library.memories.filter { $0.characterID == character.id }.count)").font(.caption2.monospaced()).foregroundStyle(CM.textTertiary)
                }
            }
            Spacer()
            Button { editingID = character.id } label: { Image(systemName: "slider.horizontal.3").foregroundStyle(CM.orange).frame(width: 38, height: 38) }
                .buttonStyle(.plain)
        }
        .padding(.vertical, 12).padding(.horizontal, 8)
        .background(character.id == app.library.activeCharacterID ? CM.elevated2 : .clear)
        .overlay(alignment: .bottom) { Rectangle().fill(CM.border).frame(height: 1) }
        .contentShape(Rectangle())
        .onTapGesture { app.selectCharacter(character.id) }
        .contextMenu {
            Button("Hablar") { app.selectCharacter(character.id) }
            Button("Editar") { editingID = character.id }
            Button("Duplicar") { _ = app.duplicateCharacter(character.id) }
        }
    }

}

private struct NewCharacterSheet: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ZStack {
                CastmindBackground(accent: CM.orange)
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(CharacterPreset.allCases) { preset in
                            Button {
                                let id = app.createCharacter(preset: preset)
                                dismiss(); DispatchQueue.main.async { app.selectCharacter(id, openChat: false) }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(preset.title.uppercased()).font(.headline.monospaced().bold()).foregroundStyle(.white)
                                        Text(preset.prompt).font(.caption).foregroundStyle(CM.textSecondary).lineLimit(2)
                                    }
                                    Spacer(); Text("→").font(.title2.monospaced()).foregroundStyle(CM.orange)
                                }.padding(15).overlay(alignment: .bottom) { Rectangle().fill(CM.border).frame(height: 1) }
                            }.buttonStyle(.plain)
                        }
                        Button {
                            let id = app.createCharacter(); dismiss(); DispatchQueue.main.async { app.selectCharacter(id, openChat: false) }
                        } label: { Text("CREATE_BLANK [+]").frame(maxWidth: .infinity) }.buttonStyle(CMPrimaryButtonStyle()).padding(.top, 14)
                    }.padding(12)
                }
            }
            .navigationTitle("NEW_CHARACTER").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { dismiss() } } }
        }
    }
}

private struct IdentifiedUUID: Identifiable { let id: UUID }
