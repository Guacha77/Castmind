import SwiftUI

struct RoomsView: View {
    @EnvironmentObject private var app: AppState
    @State private var showCreate = false

    var body: some View {
        ZStack {
            CastmindBackground(accent: CM.orange)
            if app.library.rooms.isEmpty {
                VStack(spacing: 14) {
                    Text("ROOM_INDEX_EMPTY").font(.title2.monospaced().bold())
                    Text("Crea una sala para que varios personajes respondan en turnos independientes.").font(.caption).foregroundStyle(CM.textSecondary).multilineTextAlignment(.center)
                    Button("NEW_ROOM [+]") { showCreate = true }.buttonStyle(CMPrimaryButtonStyle()).frame(maxWidth: 260)
                }.padding(28)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        HStack { Text("ROOM_INDEX").font(.caption.monospaced().bold()).foregroundStyle(CM.textSecondary); Spacer(); Button("NEW [+]") { showCreate = true }.font(.caption.monospaced().bold()).foregroundStyle(CM.orange) }
                            .padding(.vertical, 12)
                        ForEach(app.library.rooms) { room in
                            NavigationLink { RoomDetailView(roomID: room.id) } label: { RoomRow(room: room) }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("room.row")
                        }
                    }.padding(12)
                }
            }
        }
        .navigationTitle("SALAS").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showCreate = true } label: { Image(systemName: "plus") } } }
        .sheet(isPresented: $showCreate) { CreateRoomSheet() }
    }
}

private struct RoomRow: View {
    @EnvironmentObject private var app: AppState
    let room: CharacterRoom
    var names: String { room.participantIDs.compactMap { id in app.library.characters.first(where: { $0.id == id })?.name }.joined(separator: " / ") }
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(room.title.uppercased()).font(.headline.monospaced().bold()).foregroundStyle(.white)
                Text(names.uppercased()).font(.caption2.monospaced()).foregroundStyle(CM.textSecondary).lineLimit(1)
            }
            Spacer(); Text("\(room.messages.count)").font(.caption.monospacedDigit()).foregroundStyle(CM.textTertiary); Text("â†’").foregroundStyle(CM.orange)
        }.padding(.vertical, 15).overlay(alignment: .bottom) { Rectangle().fill(CM.border).frame(height: 1) }
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
            CastmindBackground(accent: CM.orange)
            if let room {
                VStack(spacing: 0) {
                    participants(room)
                    Rectangle().fill(CM.border).frame(height: 1)
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(room.messages) { RoomMessageRow(message: $0) }
                                Color.clear.frame(height: 1).id("bottom")
                            }.padding(12)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .scrollDismissesKeyboard(.interactively)
                        .onChange(of: room.messages.count) { _, _ in proxy.scrollTo("bottom", anchor: .bottom) }
                    }
                    Rectangle().fill(CM.border).frame(height: 1)
                }
            }
        }
        .navigationTitle(room?.title.uppercased() ?? "ROOM").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showEdit = true } label: { Image(systemName: "slider.horizontal.3") } } }
        .sheet(isPresented: $showEdit) { EditRoomSheet(roomID: roomID) }
    }

    private func participants(_ room: CharacterRoom) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(room.participantIDs, id: \.self) { id in
                    if let c = app.library.characters.first(where: { $0.id == id }) {
                        HStack(spacing: 6) { CharacterAvatarView(character: c, size: 28); Text(c.name.uppercased()).font(.caption2.monospaced().bold()) }
                    }
                }
            }.padding(.horizontal, 12).padding(.vertical, 8)
        }
    }

    private var roomComposer: some View {
        MessageComposer(
            text: $text,
            placeholder: "ESCRIBE UN MENSAJE...",
            accessibilityPrefix: "room",
            isGenerating: app.ai.isGenerating,
            isListening: app.isRoomListening(roomID),
            listeningText: app.recognizer.transcript,
            canSend: !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            onSend: { sendRoomText() },
            onStop: { app.cancelRoomGeneration() },
            onMicrophone: { Task { await app.toggleRoomMicrophone(roomID: roomID) } }
        )
    }

    private func sendRoomText() {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        text = ""
        app.sendToRoom(clean, roomID: roomID)
    }
}

private struct RoomMessageRow: View {
    @EnvironmentObject private var app: AppState
    let message: RoomMessage
    private var character: CharacterProfile? { guard let id=message.characterID else { return nil }; return app.library.characters.first(where: { $0.id == id }) }
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.characterID == nil { Spacer(minLength: 38) }
            if let c=character { CharacterAvatarView(character: c, size: 28) }
            VStack(alignment: .leading, spacing: 4) {
                Text(message.characterID == nil ? "YOU" : (character?.name.uppercased() ?? "CHAR")).font(.caption2.monospaced().bold()).foregroundStyle(message.characterID == nil ? CM.orange : CM.textSecondary)
                Text(message.text).frame(maxWidth: .infinity, alignment: .leading).padding(10).background(CM.elevated).overlay(Rectangle().stroke(message.characterID == nil ? CM.orange.opacity(0.5) : CM.border))
            }
            if message.characterID != nil { Spacer(minLength: 28) }
        }
    }
}

private struct CreateRoomSheet: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var title="Mesa redonda"
    @State private var selected=Set<UUID>()
    var body: some View {
        NavigationStack { Form {
            Section("Sala") { TextField("Nombre", text: $title) }
            Section("Personajes") { ForEach(app.library.characters) { c in Button { if selected.contains(c.id) { selected.remove(c.id) } else if selected.count < 4 { selected.insert(c.id) } } label: { HStack { Text(c.name); Spacer(); Image(systemName: selected.contains(c.id) ? "checkmark.square.fill" : "square") } } } }
        }.navigationTitle("Nueva sala").toolbar { ToolbarItem(placement:.cancellationAction){Button("Cancelar"){dismiss()}}; ToolbarItem(placement:.confirmationAction){Button("Crear"){ _=app.createRoom(title:title.isEmpty ? "Sala":title, participants:Array(selected)); dismiss() }.disabled(selected.isEmpty)} }.onAppear { if selected.isEmpty { selected=Set(app.library.characters.prefix(2).map(\.id)) } } }
    }
}

private struct EditRoomSheet: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    let roomID: UUID
    @State private var title=""
    @State private var selected=Set<UUID>()
    var body: some View {
        NavigationStack { Form {
            Section("Sala") { TextField("Nombre", text:$title) }
            Section("Personajes") { ForEach(app.library.characters) { c in Button { if selected.contains(c.id){selected.remove(c.id)} else if selected.count<4{selected.insert(c.id)} } label:{HStack{Text(c.name);Spacer();Image(systemName:selected.contains(c.id) ? "checkmark.square.fill":"square")}} } }
            Section { Button("Eliminar sala", role:.destructive){ app.deleteRoom(roomID); dismiss() } }
        }.navigationTitle("Editar sala").toolbar { ToolbarItem(placement:.cancellationAction){Button("Cancelar"){dismiss()}}; ToolbarItem(placement:.confirmationAction){Button("Guardar"){ guard var r=app.library.rooms.first(where:{$0.id==roomID}) else{return}; r.title=title.isEmpty ? "Sala":title; r.participantIDs=Array(selected); app.updateRoom(r); dismiss() }.disabled(selected.isEmpty)} }.onAppear{ guard let r=app.library.rooms.first(where:{$0.id==roomID}) else{return}; title=r.title; selected=Set(r.participantIDs) } }
    }
}

