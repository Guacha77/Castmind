import SwiftUI

struct ConversationListView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    let characterID: UUID
    @State private var search = ""

    private var threads: [ConversationThread] {
        app.library.conversations
            .filter { $0.characterID == characterID }
            .filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) || $0.messages.contains(where: { $0.text.localizedCaseInsensitiveContains(search) }) }
            .sorted { a, b in
                if a.isPinned != b.isPinned { return a.isPinned && !b.isPinned }
                return a.updatedAt > b.updatedAt
            }
    }

    var body: some View {
        ZStack {
            CastmindBackground(accent: Color(hex: app.activeCharacter.accentHex))
            List {
                ForEach(threads) { thread in
                    Button {
                        app.selectConversation(thread.id)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(thread.title).font(.headline).foregroundStyle(.white).lineLimit(1)
                                Spacer()
                                if thread.id == app.library.activeConversationID { Circle().fill(CM.green).frame(width: 7, height: 7) }
                            }
                            Text(thread.messages.last?.text ?? "Sin mensajes")
                                .font(.caption).foregroundStyle(CM.textSecondary).lineLimit(2)
                            Text(thread.updatedAt.formatted(date: .abbreviated, time: .shortened)).font(.caption2).foregroundStyle(CM.textTertiary)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                    .swipeActions {
                        Button(role: .destructive) { app.deleteConversation(thread.id) } label: { Label("Eliminar", systemImage: "trash") }
                        Button { app.togglePinnedConversation(thread.id) } label: { Label(thread.isPinned ? "Soltar" : "Fijar", systemImage: thread.isPinned ? "pin.slash" : "pin") }
                            .tint(CM.purple)
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Conversaciones")
        .searchable(text: $search, prompt: "Buscar")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { dismiss() } }
            ToolbarItem(placement: .topBarTrailing) {
                Button { app.newConversation(for: characterID); dismiss() } label: { Image(systemName: "plus") }
            }
        }
    }
}
