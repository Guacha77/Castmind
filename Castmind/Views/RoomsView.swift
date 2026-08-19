import SwiftUI

struct RoomsView: View {
    @EnvironmentObject private var app: AppState
    @State private var showCreate = false

    var body: some View {
        ZStack {
            CastmindBackground(accent: CM.cyan)
            if app.library.rooms.isEmpty {
                ContentUnavailableView {
                    Label("Crea una sala", systemImage: "person.3.fill")
                } description: {
                    Text("Mete varios personajes en la misma conversación y deja que reaccionen entre ellos.")
                } actions: {
                    Button("Nueva sala") { showCreate = true }.buttonStyle(.borderedProminent).tint(CM.cyan)
                }
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(app.library.rooms) { room in
                            NavigationLink {
                                RoomDetailView(roomID: room.id)
                            } label: {
                                RoomCard(room: room)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle("Salas")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showCreate = true } label: { Image(systemName: "plus") } } }
        .sheet(isPresented: $showCreate) { CreateRoomSheet() }
    }
}

private struct RoomCard: View {
    @EnvironmentObject private var app: AppState
    let room: CharacterRoom

    private var participants: [CharacterProfile] {
        room.participantIDs.compactMap { id in app.library.characters.first(where: { $0.id == id }) }
    }

    var body: some View {
        CMCard {
            HStack(spacing: 14) {
                ZStack {
                    ForEach(Array(participants.prefix(3).enumerated()), id: \.element.id) { index, character in
                        CharacterAvatarView(character: character, size: 50)
                            .offset(x: CGFloat(index) * 25)
                    }
                }
                .frame(width: 100, alignment: .leading)
                VStack(alignment: .leading, spacing: 5) {
                    Text(room.title).font(.headline).foregroundStyle(.white)
                    Text(participants.map(\.name).joined(separator: " · ")).font(.caption).foregroundStyle(CM.textSecondary).lineLimit(1)
                    Text("\(room.messages.count) mensajes").font(.caption2).foregroundStyle(CM.textTertiary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(CM.textTertiary)
            }
        }
    }
}

struct RoomDetailView: View {
    @EnvironmentObject private var app: AppState
    let roomID: UUID
    @State private var text = ""
    @State private var showEdit = false

    private var room: CharacterRoom? { app.library.rooms.first(where: { $0.id == roomID }) }

    var body: some View {
        ZStack {
            CastmindBackground(accent: CM.cyan)
            if let room {
                VStack(spacing: 0) {
                    participantStrip(room)
                    Divider().overlay(CM.border)
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(room.messages) { message in
                                    RoomMessageBubble(message: message)
                                }
                                Color.clear.frame(height: 1).id("room-bottom")
                            }.padding(14)
                        }
                        .onChange(of: room.messages.count) { _, _ in proxy.scrollTo("room-bottom", anchor: .bottom) }
                    }
                    roomComposer
                }
            }
        }
        .navigationTitle(room?.title ?? "Sala")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { Button { showEdit = true } label: { Image(systemName: "slider.horizontal.3") } }
        }
        .sheet(isPresented: $showEdit) { EditRoomSheet(roomID: roomID) }
    }

    private func participantStrip(_ room: CharacterRoom) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(room.participantIDs, id: \.self) { id in
                    if let character = app.library.characters.first(where: { $0.id == id }) {
                        HStack(spacing: 7) {
                            CharacterAvatarView(character: character, size: 34)
                            Text(character.name).font(.caption.weight(.semibold))
                        }
                    }
                }
            }.padding(.horizontal, 14).padding(.vertical, 8)
        }
    }

    private var roomComposer: some View {
        HStack(spacing: 9) {
            TextField("Di algo a la sala…", text: $text, axis: .vertical)
                .lineLimit(1...4)
                .padding(11).background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
            if app.ai.isGenerating {
                Button { app.cancelRoomGeneration() } label: { Image(systemName: "stop.fill").frame(width: 42, height: 42).background(CM.orange, in: Circle()).foregroundStyle(CM.background) }
            } else {
                Button {
                    let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !clean.isEmpty else { return }
                    text = ""
                    app.sendToRoom(clean, roomID: roomID)
                } label: { Image(systemName: "arrow.up").frame(width: 42, height: 42).background(CM.cyan, in: Circle()).foregroundStyle(CM.background) }
            }
        }.padding(12).background(.ultraThinMaterial)
    }
}

private struct RoomMessageBubble: View {
    @EnvironmentObject private var app: AppState
    let message: RoomMessage

    private var character: CharacterProfile? {
        guard let id = message.characterID else { return nil }
        return app.library.characters.first(where: { $0.id == id })
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.characterID == nil { Spacer(minLength: 50) }
            if let character {
                CharacterAvatarView(character: character, size: 30)
            }
            VStack(alignment: .leading, spacing: 4) {
                if let character { Text(character.name).font(.caption2.weight(.bold)).foregroundStyle(Color(hex: character.accentHex)) }
                Text(message.text).padding(.horizontal, 12).padding(.vertical, 9)
                    .background(message.characterID == nil ? CM.purple.opacity(0.82) : CM.elevated2, in: RoundedRectangle(cornerRadius: 16))
            }
            if message.characterID != nil { Spacer(minLength: 35) }
        }
    }
}

private struct CreateRoomSheet: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var title = "Mesa redonda"
    @State private var selected = Set<UUID>()

    var body: some View {
        NavigationStack {
            Form {
                Section("Sala") { TextField("Nombre", text: $title) }
                Section("Personajes") {
                    ForEach(app.library.characters) { character in
                        Button {
                            if selected.contains(character.id) { selected.remove(character.id) } else if selected.count < 4 { selected.insert(character.id) }
                        } label: {
                            HStack {
                                Text(character.name).foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: selected.contains(character.id) ? "checkmark.circle.fill" : "circle").foregroundStyle(selected.contains(character.id) ? CM.cyan : .secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Nueva sala")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Crear") {
                        _ = app.createRoom(title: title.isEmpty ? "Sala" : title, participants: Array(selected))
                        dismiss()
                    }.disabled(selected.isEmpty)
                }
            }
            .onAppear { if selected.isEmpty { selected = Set(app.library.characters.prefix(2).map(\.id)) } }
        }
    }
}

private struct EditRoomSheet: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    let roomID: UUID
    @State private var title = ""
    @State private var selected = Set<UUID>()

    var body: some View {
        NavigationStack {
            Form {
                Section("Sala") { TextField("Nombre", text: $title) }
                Section("Personajes") {
                    ForEach(app.library.characters) { character in
                        Button {
                            if selected.contains(character.id) {
                                selected.remove(character.id)
                            } else if selected.count < 4 {
                                selected.insert(character.id)
                            }
                        } label: {
                            HStack {
                                Text(character.name).foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: selected.contains(character.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selected.contains(character.id) ? CM.cyan : .secondary)
                            }
                        }
                    }
                }
                Section {
                    Button("Eliminar sala", role: .destructive) { app.deleteRoom(roomID); dismiss() }
                }
            }
            .navigationTitle("Editar sala")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        guard var room = app.library.rooms.first(where: { $0.id == roomID }) else { return }
                        room.title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Sala" : title
                        room.participantIDs = Array(selected)
                        app.updateRoom(room)
                        dismiss()
                    }.disabled(selected.isEmpty)
                }
            }
            .onAppear {
                guard let room = app.library.rooms.first(where: { $0.id == roomID }) else { return }
                title = room.title
                selected = Set(room.participantIDs)
            }
        }
    }
}
