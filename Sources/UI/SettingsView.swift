import SwiftUI
import AudioToolbox

// MARK: - Settings View

struct SettingsView: View {
    @StateObject var auth = AuthManager.shared
    @StateObject var updateManager = UpdateManager.shared
    @State private var showingAuthModal = false
    @State private var showLogoutAlert = false
    @State private var showUpdateSheet = false
    @State private var showUpdateAlert = false
    @State private var updateAlertMessage = "Sei aggiornato! Stai usando l'ultima versione disponibile."
    @State private var isCheckingUpdate = false
    @State private var updateInfo: UpdateInfo?
    @StateObject private var downloader = IPADownloader()

    @AppStorage("theme") private var theme: String = "Sistema"
    @AppStorage("notificationSound") private var notificationSound: String = "Predefinito"
    // Nuova feature: modalità selezione orario
    @AppStorage("timePickerMode") private var timePickerMode: String = "Apple"

    private var appVersion: String {
        if let url = Bundle.main.url(forResource: "version", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let version = json["version"] as? String {
            return version
        }
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    let themes = ["Sistema", "Chiaro", "Scuro"]
    let sounds = ["Predefinito", "Nessuno", "Tri-tone", "Anticipate", "Bloom", "Calypso", "Chime", "Chord", "Descent", "Fanfare", "Glass", "Hero", "Horn", "Ladder", "Minuet", "News Flash", "Noir", "Sherwood Forest", "Spell", "Suspense", "Telegraph", "Tiptoes", "Typewriters", "Update"]
    let timePickerModes = ["Apple", "Manuale"]

    var body: some View {
        NavigationStack {
            Form {
                if let user = auth.currentUser {
                    // Profile Section
                    Section {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color(UIColor.systemGray3))
                                    .frame(width: 50, height: 50)
                                    .overlay(Circle().stroke(Color(UIColor.systemGray5), lineWidth: 1))
                                Text(String(user.email.prefix(1)).uppercased())
                                    .font(.title2.bold())
                                    .foregroundColor(.primary)
                            }
                            Text(user.email)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }

                    // Account Section
                    Section("Account") {
                        NavigationLink(destination: ChangePasswordView()) {
                            Text("Cambia Password")
                        }
                        Button(role: .destructive) {
                            showLogoutAlert = true
                        } label: {
                            Text("Esci").foregroundStyle(.red)
                        }
                    }
                } else {
                    Section {
                        Button {
                            showingAuthModal = true
                        } label: {
                            HStack {
                                Image(systemName: "person.crop.circle.badge.plus").font(.title2)
                                Text("Accedi o Registrati")
                            }
                        }
                    }
                }

                // App Section
                Section("App") {
                    // BUG-20 FIX: Navigazione reale a AppIconView
                    NavigationLink(destination: AppIconView()) {
                        Text("Icona App")
                    }
                    Picker("Tema", selection: $theme) {
                        ForEach(themes, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.menu)

                    HStack {
                        Text("Versione App")
                        Spacer()
                        Text(appVersion).foregroundStyle(.secondary)
                    }
                }

                // Orario Section — NUOVA FEATURE
                Section("Inserimento Orario") {
                    Picker("Modalità orario", selection: $timePickerMode) {
                        ForEach(timePickerModes, id: \.self) { mode in
                            Text(mode).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    if timePickerMode == "Apple" {
                        Label("Ruota verticale come l'app Orologio", systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Label("Digita l'orario con la tastiera (es. 920 → 09:20)", systemImage: "keyboard")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Sound Section
                Section("Notifiche") {
                    Picker("Suono Notifiche", selection: $notificationSound) {
                        ForEach(sounds, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: notificationSound) { _, newValue in
                        previewSound(newValue)
                    }
                }

                // Aggiornamenti Section
                Section("Aggiornamenti") {
                    Button {
                        checkForUpdates()
                    } label: {
                        HStack {
                            Text("Controlla Aggiornamenti").foregroundColor(.primary)
                            Spacer()
                            if isCheckingUpdate {
                                ProgressView()
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(Color(UIColor.tertiaryLabel))
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Impostazioni")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Conferma Uscita", isPresented: $showLogoutAlert) {
                Button("Annulla", role: .cancel) { }
                Button(auth.isSyncing ? "Salvataggio..." : "Esci", role: .destructive) {
                    auth.logout()
                }
                .disabled(auth.isSyncing)
            } message: {
                Text("Prima di uscire, tutti i tuoi dati verranno salvati su Bloom Cloud.")
            }
            .sheet(isPresented: $showUpdateSheet) {
                if let info = updateInfo {
                    VStack(spacing: 24) {
                        Capsule()
                            .fill(Color(UIColor.systemGray4))
                            .frame(width: 40, height: 5)
                            .padding(.top, 16)
                        Text("Bloom").font(.title2.bold())
                        Text("Versione \(info.version)").font(.headline).foregroundColor(.secondary)
                        Text(info.notes).multilineTextAlignment(.center).padding(.horizontal)
                        Spacer()
                        HStack(spacing: 16) {
                            Button("Non ora") { showUpdateSheet = false }
                                .font(.headline).foregroundColor(.primary).frame(maxWidth: .infinity)
                                .padding().background(Color(UIColor.systemGray5)).cornerRadius(12)
                            Button("Installa") {
                                if let url = URL(string: info.url) { downloader.download(from: url) }
                            }
                            .font(.headline).foregroundColor(.white).frame(maxWidth: .infinity)
                            .padding().background(Color.blue).cornerRadius(12)
                            .disabled(downloader.isDownloading)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, downloader.isDownloading || downloader.isFinished ? 8 : 24)
                        Group {
                            if downloader.isDownloading {
                                VStack(spacing: 8) {
                                    ProgressView(value: downloader.progress).progressViewStyle(LinearProgressViewStyle(tint: .blue))
                                    Text("Scaricamento in corso... \(Int(downloader.progress * 100))%").font(.caption).foregroundColor(.secondary)
                                }
                                .padding().background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                            } else if downloader.isFinished {
                                Text("✅ Download completato!").font(.caption.bold()).foregroundColor(.green)
                                    .padding().background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .padding(.horizontal, 24).padding(.bottom, 24)
                    }
                    .presentationDetents([.medium])
                }
            }
            // BUG-14 FIX: Alert mostra il messaggio corretto (aggiornato o errore di rete)
            .alert("Aggiornamenti", isPresented: $showUpdateAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(updateAlertMessage)
            }
            .fullScreenCover(isPresented: $showingAuthModal) {
                AuthView(isPresented: $showingAuthModal, isOptional: true)
            }
        }
    }

    private func previewSound(_ soundName: String) {
        var id: UInt32 = 0
        switch soundName {
        case "Predefinito": id = 1005
        case "Tri-tone": id = 1007
        case "Chime": id = 1008
        case "Glass": id = 1009
        case "Horn": id = 1010
        case "Anticipate": id = 1013
        case "Bloom": id = 1014
        case "Calypso": id = 1015
        case "Minuet": id = 1020
        case "News Flash": id = 1021
        case "Sherwood Forest": id = 1022
        case "Telegraph": id = 1023
        case "Tiptoes": id = 1024
        case "Typewriters": id = 1025
        case "Update": id = 1026
        case "Chord": id = 1300
        case "Descent": id = 1301
        case "Fanfare": id = 1302
        case "Hero": id = 1303
        case "Ladder": id = 1304
        case "Noir": id = 1305
        case "Spell": id = 1306
        case "Suspense": id = 1307
        default: break
        }
        if id != 0 { AudioServicesPlaySystemSound(id) }
    }

    func checkForUpdates() {
        isCheckingUpdate = true
        Task {
            do {
                guard let url = URL(string: "https://raw.githubusercontent.com/xSaturnMoon/Bloom/main/update.json") else { return }
                let (data, _) = try await URLSession.shared.data(from: url)
                let info = try JSONDecoder().decode(UpdateInfo.self, from: data)
                let currentVersion = appVersion

                await MainActor.run {
                    self.isCheckingUpdate = false
                    // BUG-15 FIX: Confronto semantico della versione (non solo !=)
                    if isNewerVersion(info.version, than: currentVersion) {
                        self.updateInfo = info
                        self.showUpdateSheet = true
                    } else {
                        self.updateAlertMessage = "Sei aggiornato! Stai usando la versione \(currentVersion)."
                        self.showUpdateAlert = true
                    }
                }
            } catch {
                // BUG-14 FIX: Mostra l'errore reale, non "sei aggiornato"
                await MainActor.run {
                    self.isCheckingUpdate = false
                    self.updateAlertMessage = "Impossibile controllare gli aggiornamenti. Verifica la connessione internet."
                    self.showUpdateAlert = true
                }
            }
        }
    }

    /// BUG-15 FIX: Confronto semantico della versione (es. "1.2.26" > "1.2.25")
    private func isNewerVersion(_ new: String, than current: String) -> Bool {
        let newParts = new.split(separator: ".").compactMap { Int($0) }
        let currentParts = current.split(separator: ".").compactMap { Int($0) }
        let maxLen = max(newParts.count, currentParts.count)
        for i in 0..<maxLen {
            let n = i < newParts.count ? newParts[i] : 0
            let c = i < currentParts.count ? currentParts[i] : 0
            if n > c { return true }
            if n < c { return false }
        }
        return false
    }
}

// MARK: - App Icon View (BUG-20 FIX)
// Sostituisce il placeholder Text("Icona App") con una vera schermata.

struct AppIconView: View {
    @State private var selectedIcon: String? = nil
    @State private var showError = false

    // Lista delle icone disponibili (nome nil = icona principale)
    // Per aggiungere icone alternate, aggiungile in Assets.xcassets e dichiara CFBundleIcons in Info.plist
    let icons: [(name: String?, label: String, systemImage: String)] = [
        (nil, "Predefinita", "app.fill"),
        ("BloomLight", "Chiara", "sun.max.fill"),
        ("BloomDark", "Scura", "moon.fill")
    ]

    var body: some View {
        Form {
            Section("Seleziona Icona App") {
                ForEach(icons, id: \.label) { icon in
                    Button {
                        changeIcon(to: icon.name)
                    } label: {
                        HStack {
                            Image(systemName: icon.systemImage)
                                .font(.title2)
                                .foregroundColor(.blue)
                                .frame(width: 32)
                            Text(icon.label)
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedIcon == icon.name {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }
            }

            if showError {
                Section {
                    Text("La selezione dell'icona alternativa richiede che le icone siano configurate in Info.plist (CFBundleIcons). Contatta lo sviluppatore.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Icona App")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            selectedIcon = UIApplication.shared.alternateIconName
        }
    }

    private func changeIcon(to name: String?) {
        guard UIApplication.shared.supportsAlternateIcons else {
            showError = true
            return
        }
        UIApplication.shared.setAlternateIconName(name) { error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Icon change error: \(error)")
                    showError = true
                } else {
                    selectedIcon = name
                }
            }
        }
    }
}

// MARK: - UpdateInfo

struct UpdateInfo: Codable {
    let version: String
    let notes: String
    let url: String
}

// MARK: - IPA Downloader (BUG-10 FIX: session invalidation)

class IPADownloader: NSObject, ObservableObject, URLSessionDownloadDelegate {
    @Published var progress: Double = 0
    @Published var isDownloading = false
    @Published var isFinished = false

    // BUG-10 FIX: Mantieni un riferimento alla session per poterla invalidare
    private var session: URLSession?

    func download(from url: URL) {
        DispatchQueue.main.async {
            self.isDownloading = true
            self.progress = 0
            self.isFinished = false
        }

        let config = URLSessionConfiguration.default
        // BUG-10 FIX: salviamo la reference e la invalidiamo alla fine
        let newSession = URLSession(configuration: config, delegate: self, delegateQueue: .main)
        self.session = newSession
        let task = newSession.downloadTask(with: url)
        task.resume()
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if totalBytesExpectedToWrite > 0 {
            DispatchQueue.main.async {
                self.progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            }
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let tempUrl = FileManager.default.temporaryDirectory.appendingPathComponent("Bloom.ipa")
        try? FileManager.default.removeItem(at: tempUrl)
        try? FileManager.default.moveItem(at: location, to: tempUrl)

        DispatchQueue.main.async {
            self.isDownloading = false
            self.isFinished = true

            // BUG-10 FIX: Invalida la sessione dopo il completamento per evitare memory leak
            self.session?.finishTasksAndInvalidate()
            self.session = nil

            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let root = scene.windows.first?.rootViewController {
                let documentPicker = UIDocumentPickerViewController(forExporting: [tempUrl], asCopy: true)
                documentPicker.allowsMultipleSelection = false
                root.present(documentPicker, animated: true)
            }
        }
    }
}

// MARK: - Auth View

struct AuthView: View {
    @Binding var isPresented: Bool
    var isOptional: Bool = true
    @State private var isLogin = true
    @State private var email = ""
    @State private var name = ""
    @State private var password = ""
    @StateObject var auth = AuthManager.shared

    // BUG-25 FIX: Validazione locale prima di abilitare il bottone
    private var isFormValid: Bool {
        if email.isEmpty || password.isEmpty { return false }
        if !isLogin && name.isEmpty { return false }
        // Password minimo 6 caratteri
        if password.count < 6 { return false }
        // Email deve contenere @ e .
        if !email.contains("@") || !email.contains(".") { return false }
        return true
    }

    private var validationMessage: String? {
        if password.count > 0 && password.count < 6 { return "La password deve essere di almeno 6 caratteri." }
        if email.count > 0 && (!email.contains("@") || !email.contains(".")) { return "Inserisci un'email valida." }
        return nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    Image(systemName: "globe")
                        .font(.system(size: 44, weight: .regular))
                        .foregroundColor(.white)
                        .frame(width: 80, height: 80)
                        .background(Color.blue, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .padding(.top, 32)
                    Text("Bloom").font(.system(.title, design: .rounded, weight: .semibold))
                    Text(isLogin ? "Accedi per continuare" : "Crea un nuovo account")
                        .font(.footnote).foregroundStyle(.secondary)
                    Picker("Modalità", selection: $isLogin) {
                        Text("Accedi").tag(true)
                        Text("Registrati").tag(false)
                    }
                    .pickerStyle(.segmented).padding(.horizontal, 32).padding(.top, 12)
                }
                .padding(.bottom, 16)
                .background(Color(UIColor.systemGroupedBackground))

                Form {
                    Section {
                        if !isLogin { TextField("Nome completo", text: $name) }
                        TextField("Email", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                        SecureField("Password", text: $password)
                    } footer: {
                        VStack(alignment: .leading, spacing: 4) {
                            // BUG-25 FIX: Mostra validazione in tempo reale
                            if let msg = validationMessage {
                                Text(msg).foregroundColor(.orange)
                            }
                            if let error = auth.authError {
                                Text(error).foregroundColor(.red)
                            }
                        }
                    }

                    Section {
                        Button {
                            triggerAuth()
                        } label: {
                            if auth.isLoading {
                                ProgressView().frame(maxWidth: .infinity, alignment: .center)
                            } else {
                                Text(isLogin ? "Accedi" : "Crea Account")
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                        }
                        // BUG-25 FIX: Disabilitato finché il form non è valido
                        .disabled(auth.isLoading || !isFormValid)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    }
                }
                .formStyle(.grouped)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isOptional {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Annulla") { isPresented = false }
                    }
                }
            }
            .onChange(of: auth.currentUser) { _, newUser in
                if newUser != nil { isPresented = false }
            }
        }
    }

    private func triggerAuth() {
        auth.authError = nil
        if isLogin {
            auth.login(email: email, password: password)
        } else {
            auth.signUp(email: email, name: name, password: password)
        }
    }
}

// MARK: - Change Password View

struct ChangePasswordView: View {
    @StateObject var auth = AuthManager.shared
    @Environment(\.dismiss) var dismiss

    @State private var oldPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    var body: some View {
        Form {
            Section {
                SecureField("Vecchia Password", text: $oldPassword)
                SecureField("Nuova Password", text: $newPassword)
                SecureField("Conferma Nuova Password", text: $confirmPassword)
            }

            if let error = errorMessage {
                Text(error).foregroundColor(.red).font(.footnote)
            }
            if let success = successMessage {
                Text(success).foregroundColor(.green).font(.footnote)
            }

            Button(action: changePassword) {
                if isLoading { ProgressView() } else { Text("Aggiorna Password") }
            }
            .disabled(isLoading || oldPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty)
        }
        .navigationTitle("Cambia Password")
        .navigationBarTitleDisplayMode(.inline)
    }

    func changePassword() {
        guard newPassword == confirmPassword else {
            errorMessage = "Le nuove password non corrispondono."
            return
        }
        guard newPassword.count >= 6 else {
            errorMessage = "La nuova password deve essere di almeno 6 caratteri."
            return
        }
        isLoading = true
        errorMessage = nil
        successMessage = nil

        Task {
            do {
                try await auth.changePassword(old: oldPassword, new: newPassword)
                await MainActor.run {
                    isLoading = false
                    successMessage = "Password aggiornata con successo! Hai effettuato nuovamente l'accesso automaticamente."
                    oldPassword = ""
                    newPassword = ""
                    confirmPassword = ""
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
