import SwiftUI

struct ShoppingView: View {
    @StateObject var manager = ShoppingManager.shared
    @State private var showingAddItem = false
    @State private var showingShare = false
    @State private var showingFriendsLists = false
    @State private var newItemName = ""
    @State private var newItemQty = ""
    @State private var showingClearAllAlert = false
    @State private var showingClearCheckedAlert = false
    
    // Computata per separare gli elementi attivi da quelli completati
    var activeItems: [ShoppingItem] {
        manager.items.filter { !$0.isChecked }
    }
    
    var completedItems: [ShoppingItem] {
        manager.items.filter { $0.isChecked }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemBackground)
                    .ignoresSafeArea()
                
                List {
                    Section {
                        HStack(spacing: 15) {
                            statCard(title: "Da comprare", value: "\(activeItems.count)", icon: "cart.fill", color: .orange)
                            statCard(title: "Completati", value: "\(completedItems.count)", icon: "checkmark.seal.fill", color: .green)
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .padding(.vertical, 10)
                    }
                    .padding(.horizontal)

                    if manager.items.isEmpty {
                        Section {
                            VStack(spacing: 20) {
                                Image(systemName: "cart.badge.plus")
                                    .font(.system(size: 60))
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 50)
                                Text("La tua lista è vuota")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    } else {
                        // SEZIONE ATTIVI
                        if !activeItems.isEmpty {
                            Section {
                                ForEach(activeItems) { item in
                                    ShoppingItemCard(item: item)
                                        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                                        .listRowBackground(Color.clear)
                                        .listRowSeparator(.hidden)
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                withAnimation {
                                                    manager.deleteItem(item)
                                                }
                                            } label: {
                                                Label("Elimina", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                        }
                        
                        // SEZIONE COMPLETATI
                        if !completedItems.isEmpty {
                            Section {
                                HStack {
                                    Text("PRODOTTI PRESI")
                                        .font(.caption.bold())
                                        .foregroundStyle(.secondary)
                                        .padding(.leading, 20)
                                    Spacer()
                                    Rectangle()
                                        .frame(height: 1)
                                        .foregroundStyle(.secondary.opacity(0.2))
                                }
                                .padding(.top, 20)
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                
                                ForEach(completedItems) { item in
                                    ShoppingItemCard(item: item)
                                        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                                        .listRowBackground(Color.clear)
                                        .listRowSeparator(.hidden)
                                        .opacity(0.6) // Effetto sfumato per i completati
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                withAnimation {
                                                    manager.deleteItem(item)
                                                }
                                            } label: {
                                                Label("Elimina", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                        }
                    }
                    
                    Section {
                        Spacer(minLength: 120)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Spesa")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 15) {
                        Button(role: .destructive) {
                            showingClearAllAlert = true
                        } label: {
                            Image(systemName: "trash.fill")
                                .foregroundColor(.red)
                        }
                        
                        Button {
                            showingClearCheckedAlert = true
                        } label: {
                            Image(systemName: "checkmark.circle.badge.xmark.fill")
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 15) {
                        Button {
                            showingFriendsLists.toggle()
                        } label: {
                            Image(systemName: "folder.badge.person.crop")
                        }
                        
                        Button {
                            showingShare.toggle()
                        } label: {
                            Image(systemName: "person.badge.plus")
                        }
                        
                        Button {
                            showingAddItem.toggle()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                        }
                    }
                }
            }
            .alert("Elimina tutto?", isPresented: $showingClearAllAlert) {
                Button("Annulla", role: .cancel) {}
                Button("Elimina Tutto", role: .destructive) {
                    manager.clearAll()
                }
            } message: {
                Text("Sei sicuro/a di voler eliminare tutti i prodotti dalla lista?")
            }
            .alert("Elimina completati?", isPresented: $showingClearCheckedAlert) {
                Button("Annulla", role: .cancel) {}
                Button("Elimina Completati", role: .destructive) {
                    manager.clearChecked()
                }
            } message: {
                Text("Sei sicuro/a di voler eliminare solo i prodotti già completati?")
            }
            .sheet(isPresented: $showingAddItem) {
                AddItemView(isPresented: $showingAddItem)
            }
            .sheet(isPresented: $showingShare) {
                ShareView(isPresented: $showingShare)
            }
            .sheet(isPresented: $showingFriendsLists) {
                FriendsListView(isPresented: $showingFriendsLists)
            }
        }
    }
    
    func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.title2.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct ShoppingItemCard: View {
    var item: ShoppingItem
    @ObservedObject var manager = ShoppingManager.shared
    
    var body: some View {
        HStack(spacing: 15) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                    .strikethrough(item.isChecked)
                    .foregroundStyle(item.isChecked ? .secondary : .primary)
                
                if !item.quantity.isEmpty {
                    Text(item.quantity)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    manager.toggleItem(item)
                }
            } label: {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(item.isChecked ? .green : .secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct AddItemView: View {
    @Binding var isPresented: Bool
    @State private var name = ""
    @State private var qty = ""
    @ObservedObject var manager = ShoppingManager.shared
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Dettagli Prodotto") {
                    TextField("Nome prodotto", text: $name)
                    TextField("Quantità", text: $qty)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Aggiungi Prodotto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annulla") { isPresented = false }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Salva") {
                        manager.addItem(name: name, quantity: qty)
                        isPresented = false
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

// MARK: - ShareView (QR Code nativo)
struct ShareView: View {
    @Binding var isPresented: Bool
    @ObservedObject var manager = ShoppingManager.shared
    @StateObject var auth = AuthManager.shared
    @State private var friendCode = ""
    @State private var friendName = ""
    @State private var showCopied = false

    var displayCode: String {
        auth.currentUser?.friendCode ?? manager.myCode
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 20) {
                        if !displayCode.isEmpty {
                            QRCodeView(content: "bloom://friend/\(displayCode)")
                                .frame(width: 200, height: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                                .padding(.top, 8)
                        }
                        VStack(spacing: 8) {
                            Text(displayCode)
                                .font(.system(size: 22, weight: .bold, design: .monospaced))
                                .tracking(4)
                                .foregroundColor(.primary)
                            
                            if displayCode.count == 6 {
                                Text("Attenzione: questo è un codice locale offline. Se non diventa di 8 caratteri, clicca 'Forza Ricarica'. Errore: \(auth.authError ?? "")")
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                
                                Button("Forza Ricarica Codice") {
                                    Task {
                                        do {
                                            let code = try await SupabaseManager.shared.fetchOrCreateProfile()
                                            await MainActor.run {
                                                auth.currentUser?.friendCode = code
                                                manager.myCode = code
                                                // BUG-19 FIX: Salva su disco il codice aggiornato
                                                // così persiste anche se l'app viene chiusa subito dopo
                                                auth.saveLocalSession(auth.currentUser)
                                            }
                                        } catch {
                                            await MainActor.run {
                                                auth.authError = "Errore Supabase: \(error.localizedDescription)"
                                            }
                                        }
                                    }
                                }
                                .font(.caption.bold())
                                .buttonStyle(.borderedProminent)
                            }
                            
                            Button {
                                UIPasteboard.general.string = displayCode
                                withAnimation { showCopied = true }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    withAnimation { showCopied = false }
                                }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                Label(
                                    showCopied ? "Copiato!" : "Copia Codice",
                                    systemImage: showCopied ? "checkmark.circle.fill" : "doc.on.doc"
                                )
                                .font(.subheadline.bold())
                                .foregroundColor(showCopied ? .green : .blue)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(showCopied ? Color.green.opacity(0.12) : Color.blue.opacity(0.12)))
                            }
                            .animation(.spring(response: 0.3), value: showCopied)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 8)
                        Text("Fai scansionare questo QR all'amico, oppure condividigli il codice.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                Section("Aggiungi Amico") {
                    TextField("Codice Amico (8 caratteri)", text: $friendCode)
                        .autocapitalization(.allCharacters)
                        .onChange(of: friendCode) { _, val in friendCode = String(val.prefix(8)) }
                    TextField("Nome Amico", text: $friendName)
                    Button("Aggiungi") {
                        manager.addFriend(code: friendCode.uppercased(), name: friendName)
                        friendCode = ""
                        friendName = ""
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }
                    .disabled(friendCode.count < 4 || friendName.isEmpty)
                }
            }
            .navigationTitle("Condivisione")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Chiudi") { isPresented = false }
                }
            }
        }
    }
}

struct QRCodeView: View {
    let content: String

    var body: some View {
        if let img = generateQR(from: content) {
            Image(uiImage: img)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.2))
        }
    }

    private func generateQR(from string: String) -> UIImage? {
        guard let data = string.data(using: .utf8) else { return nil }
        let filter = CIFilter(name: "CIQRCodeGenerator")
        filter?.setValue(data, forKey: "inputMessage")
        filter?.setValue("H", forKey: "inputCorrectionLevel")
        guard let ciImage = filter?.outputImage else { return nil }
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

struct FriendsListView: View {
    @Binding var isPresented: Bool
    @ObservedObject var manager = ShoppingManager.shared
    @State private var editingFriend: Friend?
    @State private var newName = ""
    
    var body: some View {
        NavigationStack {
            List {
                if manager.friends.isEmpty {
                    Section {
                        Text("Non hai ancora aggiunto amici.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(manager.friends) { friend in
                        NavigationLink {
                            FriendDetailView(friend: friend)
                        } label: {
                            HStack {
                                Image(systemName: "person.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.title2)
                                
                                VStack(alignment: .leading) {
                                    Text(friend.name)
                                        .font(.headline)
                                    Text(friend.code)
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                manager.removeFriend(friend)
                            } label: {
                                Label("Elimina", systemImage: "trash")
                            }
                            
                            Button {
                                editingFriend = friend
                                newName = friend.name
                            } label: {
                                Label("Rinomina", systemImage: "pencil")
                            }
                            .tint(.orange)
                        }
                    }
                }
            }
            .navigationTitle("Liste Amici")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Chiudi") { isPresented = false }
                }
            }
            .alert("Rinomina Amico", isPresented: Binding(get: { editingFriend != nil }, set: { if !$0 { editingFriend = nil } })) {
                TextField("Nuovo nome", text: $newName)
                Button("Annulla", role: .cancel) { editingFriend = nil }
                Button("Salva") {
                    if var friend = editingFriend, !newName.isEmpty {
                        friend.name = newName
                        manager.updateFriend(friend)
                    }
                    editingFriend = nil
                }
            }
        }
    }
}

struct FriendDetailView: View {
    let friend: Friend
    @ObservedObject var manager = ShoppingManager.shared
    
    var body: some View {
        List {
            if manager.observingItems.isEmpty {
                Text(manager.friendListStatus)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(manager.observingItems) { item in
                    HStack {
                        Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(item.isChecked ? .green : .secondary)
                        Text(item.name)
                        Spacer()
                        Text(item.quantity)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(friend.name)
        .onAppear {
            manager.fetchItemsForFriend(friend)
        }
        .onDisappear {
            manager.observingFriend = nil
            manager.observingItems = []
        }
    }
}
