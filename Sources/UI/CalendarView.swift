import SwiftUI

// MARK: - Time Picker Mode
// Letto da @AppStorage("timePickerMode"): "Apple" usa il wheel nativo,
// "Manuale" usa input numerico (920 → 09:20).

/// View wrapper che mostra il picker di orario in base alla preferenza utente.
/// Se timePickerMode == "Manuale", usa ManualTimeInputField; altrimenti DatePicker wheel.
struct TimePickerField: View {
    let label: String
    @Binding var time: Date
    @AppStorage("timePickerMode") private var timePickerMode: String = "Apple"

    var body: some View {
        if timePickerMode == "Manuale" {
            ManualTimeInputField(label: label, time: $time)
        } else {
            DatePicker(label, selection: $time, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
        }
    }
}

/// Input numerico per l'orario: l'utente digita cifre (es. "920" → 09:20).
/// Validazione in tempo reale: se l'orario non è valido, mostra "Orario non valido".
struct ManualTimeInputField: View {
    let label: String
    @Binding var time: Date
    @State private var inputText: String = ""
    @State private var isInvalid: Bool = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .foregroundStyle(.primary)
                Spacer()
                // Mostra l'orario corrente come riferimento
                Text(time.formatted(.dateTime.hour().minute()))
                    .foregroundStyle(.secondary)
                    .font(.footnote)
            }

            HStack(spacing: 8) {
                TextField("es. 920 → 09:20", text: $inputText)
                    .keyboardType(.numberPad)
                    .focused($isFocused)
                    .onChange(of: inputText) { _, newValue in
                        // Limita a 4 cifre
                        let digits = newValue.filter { $0.isNumber }
                        if digits.count > 4 {
                            inputText = String(digits.prefix(4))
                        } else {
                            inputText = digits
                        }
                        validateAndApply(inputText)
                    }
                    .padding(10)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                if isInvalid && !inputText.isEmpty {
                    Label("Orario non valido", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                        .transition(.opacity.combined(with: .scale))
                }
            }
            .animation(.spring(response: 0.3), value: isInvalid)
        }
        .onAppear {
            // Pre-popola con l'orario corrente
            let cal = Calendar.current
            let h = cal.component(.hour, from: time)
            let m = cal.component(.minute, from: time)
            inputText = String(format: "%02d%02d", h, m)
        }
    }

    private func validateAndApply(_ raw: String) {
        guard !raw.isEmpty else { isInvalid = false; return }

        // Interpreta l'input: "920" → h=9 m=20, "1840" → h=18 m=40
        let padded = raw.count <= 2 ? raw : raw // se solo ore
        let h: Int
        let m: Int

        switch raw.count {
        case 1:
            // Solo una cifra → ora (0..9), minuti 0
            h = Int(raw) ?? -1
            m = 0
        case 2:
            // Due cifre → ora (0..23), minuti 0
            h = Int(raw) ?? -1
            m = 0
        case 3:
            // Tre cifre → prima cifra = ore, ultime due = minuti (es. "920" → 09:20)
            h = Int(String(raw.prefix(1))) ?? -1
            m = Int(String(raw.suffix(2))) ?? -1
        case 4:
            // Quattro cifre → prime due = ore, ultime due = minuti
            h = Int(String(raw.prefix(2))) ?? -1
            m = Int(String(raw.suffix(2))) ?? -1
        default:
            isInvalid = true
            return
        }

        guard h >= 0, h <= 23, m >= 0, m <= 59 else {
            isInvalid = true
            return
        }

        isInvalid = false
        // Aggiorna il binding `time` con il nuovo orario
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: time)
        comps.hour = h
        comps.minute = m
        if let newDate = cal.date(from: comps) {
            time = newDate
        }
    }
}

// MARK: - CalendarView

struct CalendarView: View {
    @StateObject var manager = CalendarManager.shared
    @State private var showingAllReminders = false
    @State private var selectedEvent: BloomEvent?
    @State private var currentMonth = Date()
    // BUG-26 FIX: Usiamo un tipo opzionale per il sheet "aggiungi evento"
    // così .sheet(item:) garantisce che la data sia sempre quella del giorno toccato.
    @State private var addEventForDate: SelectedDate?

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

                VStack(spacing: 0) {
                    // Month Selector Header
                    HStack {
                        Button { changeMonth(by: -1) } label: {
                            Image(systemName: "chevron.left.circle.fill").font(.title2).foregroundColor(.secondary.opacity(0.5))
                        }
                        Spacer()
                        Text(currentMonth.formatted(.dateTime.month(.wide).year().locale(Locale(identifier: "it_IT"))).capitalized)
                            .font(.title2.bold())
                        Spacer()
                        Button { changeMonth(by: 1) } label: {
                            Image(systemName: "chevron.right.circle.fill").font(.title2).foregroundColor(.secondary.opacity(0.5))
                        }
                    }
                    .padding()
                    .background(Color(uiColor: .systemBackground))

                    ScrollViewReader { proxy in
                        ScrollView {
                            let days = daysInMonth(for: currentMonth)
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                                ForEach(days, id: \.self) { date in
                                    // BUG-26 FIX: Passiamo la data direttamente a DayCardRow.
                                    // Il bottone + dentro imposta `addEventForDate = date`
                                    // che trigghera il sheet(item:) con la data corretta.
                                    DayCardRow(
                                        date: date,
                                        selectedEvent: $selectedEvent,
                                        addEventForDate: $addEventForDate
                                    )
                                    .id(Calendar.current.startOfDay(for: date))
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 12)
                        }
                        .background(Color.clear)
                        .id(currentMonth)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .onAppear {
                            scrollToToday(proxy: proxy)
                        }
                        .onChange(of: currentMonth) { _, _ in
                            scrollToToday(proxy: proxy)
                        }
                    }
                }
            }
            .navigationTitle("Calendario")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showingAllReminders = true } label: {
                        Image(systemName: "bell.fill").foregroundColor(.orange)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        withAnimation { currentMonth = Date() }
                    } label: {
                        Text("Oggi").bold()
                    }
                }
            }
            .sheet(item: $addEventForDate) { item in
                AddEventView(isPresented: Binding(
                    get: { addEventForDate != nil },
                    set: { if !$0 { addEventForDate = nil } }
                ), initialDate: item.date)
            }
            .sheet(item: $selectedEvent) { event in
                EditEventView(event: event)
            }
            .sheet(isPresented: $showingAllReminders) {
                AllRemindersView(isPresented: $showingAllReminders)
            }
        }
    }

    private func scrollToToday(proxy: ScrollViewProxy) {
        let now = Date()
        if Calendar.current.isDate(now, equalTo: currentMonth, toGranularity: .month) {
            let todayId = Calendar.current.startOfDay(for: now)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation { proxy.scrollTo(todayId, anchor: .top) }
            }
        }
    }

    func changeMonth(by value: Int) {
        if let newMonth = Calendar.current.date(byAdding: .month, value: value, to: currentMonth) {
            withAnimation { currentMonth = newMonth }
        }
    }

    func daysInMonth(for date: Date) -> [Date] {
        let calendar = Calendar.current
        guard let range = calendar.range(of: .day, in: .month, for: date),
              let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) else { return [] }
        return range.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth)
        }
    }
}

// BUG-26 FIX: DayCardRow ora usa `addEventForDate` (Binding<Date?>) invece di
// due state separati (selectedAddDate + showingAddEvent) che creavano la race condition.
struct DayCardRow: View {
    let date: Date
    @Binding var selectedEvent: BloomEvent?
    @Binding var addEventForDate: SelectedDate?
    // BUG-17 FIX: @ObservedObject invece di @StateObject per i singleton
    @ObservedObject var manager = CalendarManager.shared

    var body: some View {
        let events = manager.events(for: date)
        let isToday = Calendar.current.isDateInToday(date)

        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(date.formatted(.dateTime.weekday(.wide).locale(Locale(identifier: "it_IT"))).capitalized)
                        .font(.caption.bold())
                        .foregroundColor(isToday ? .blue : .secondary)
                    Text(date.formatted(.dateTime.day().locale(Locale(identifier: "it_IT"))))
                        .font(.title3.bold())
                }
                Spacer()
            }
            .padding(.bottom, 12)

            if events.isEmpty {
                Text("Nessun impegno")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 8) {
                    ForEach(events) { event in
                        SwipeableEventRow(event: event) {
                            selectedEvent = event
                        }
                    }
                }
            }

            HStack {
                Spacer()
                Button {
                    // BUG-26 FIX: Imposta direttamente la data nel binding item.
                    // SwiftUI crea il sheet DOPO questa assegnazione, quindi
                    // AddEventView riceve sempre la data corretta.
                    addEventForDate = SelectedDate(date: date)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .padding(.top, 10)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isToday ? Color.blue : Color.clear, lineWidth: isToday ? 1.5 : 0)
        )
    }
}

struct EventRowView: View {
    let event: BloomEvent
    let onTap: () -> Void
    // BUG-17 FIX: @ObservedObject invece di @StateObject
    @ObservedObject var manager = CalendarManager.shared

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                        .strikethrough(event.isCompleted)
                        .lineLimit(1)
                    Text(event.startTime.formatted(.dateTime.hour().minute()))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()

                if !event.reminders.isEmpty || event.reminderId != nil {
                    Image(systemName: "bell.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }

                Button {
                    withAnimation { manager.toggleComplete(event) }
                } label: {
                    Image(systemName: event.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(event.isCompleted ? .green : .secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(10)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

struct SwipeableEventRow: View {
    let event: BloomEvent
    let onTap: () -> Void
    // BUG-17 FIX: @ObservedObject
    @ObservedObject var manager = CalendarManager.shared
    @State private var offset: CGFloat = 0
    // BUG-09 FIX: Flag per prevenire la doppia eliminazione
    @State private var isDeleted = false

    var body: some View {
        ZStack(alignment: .trailing) {
            Button {
                guard !isDeleted else { return } // BUG-09 FIX
                isDeleted = true
                withAnimation { manager.deleteEvent(event) }
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.white)
                    .frame(width: 60)
                    .frame(maxHeight: .infinity)
                    .background(Color.red)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            EventRowView(event: event, onTap: onTap)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .offset(x: offset)
                .gesture(
                    DragGesture()
                        .onChanged { gesture in
                            if gesture.translation.width < 0 {
                                offset = gesture.translation.width
                            }
                        }
                        .onEnded { gesture in
                            withAnimation {
                                if offset < -50 {
                                    if gesture.translation.width < -100 {
                                        guard !isDeleted else { return } // BUG-09 FIX
                                        isDeleted = true
                                        manager.deleteEvent(event)
                                    } else {
                                        offset = -70
                                    }
                                } else {
                                    offset = 0
                                }
                            }
                        }
                )
        }
    }
}

struct EditEventView: View {
    @Environment(\.dismiss) var dismiss
    @State var event: BloomEvent
    @State private var title: String
    @State private var date: Date
    @State private var startTime: Date
    @State private var newReminderTime: Date
    @State private var isAddingReminder: Bool = false
    @State private var reminders: [EventReminder]

    init(event: BloomEvent) {
        self._event = State(initialValue: event)
        self._title = State(initialValue: event.title)
        self._date = State(initialValue: event.date)
        self._startTime = State(initialValue: event.startTime)
        self._newReminderTime = State(initialValue: event.startTime)

        var existingReminders = event.reminders
        if existingReminders.isEmpty, let rt = event.reminderTime, let rid = event.reminderId {
            existingReminders.append(EventReminder(time: rt, notificationId: rid))
        }
        self._reminders = State(initialValue: existingReminders)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Cosa") {
                    TextField("Titolo", text: $title)
                }
                Section("Quando") {
                    DatePicker("Giorno", selection: $date, displayedComponents: .date)
                    // Feature: usa TimePickerField per rispettare la preferenza utente
                    TimePickerField(label: "Orario", time: $startTime)
                }
                Section("Notifiche") {
                    Toggle("Aggiungi Promemoria", isOn: $isAddingReminder)

                    if isAddingReminder {
                        TimePickerField(label: "Orario Promemoria", time: $newReminderTime)
                        Button("Salva Promemoria") {
                            // BUG-11 FIX: ID assegnato subito, non stringa vuota
                            let newReminder = EventReminder(time: newReminderTime, notificationId: UUID().uuidString)
                            reminders.append(newReminder)
                            isAddingReminder = false
                        }
                    }
                }

                if !reminders.isEmpty {
                    Section("Promemoria Programmati") {
                        ForEach(reminders) { reminder in
                            HStack {
                                Text(reminder.time.formatted(.dateTime.hour().minute()))
                                Spacer()
                                Button(role: .destructive) {
                                    reminders.removeAll(where: { $0.id == reminder.id })
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Section {
                    Button(role: .destructive) {
                        CalendarManager.shared.deleteEvent(event)
                        dismiss()
                    } label: {
                        Text("Elimina Impegno").frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Modifica Impegno")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Salva") {
                        event.title = title
                        event.date = date
                        event.startTime = startTime
                        event.reminders = reminders
                        CalendarManager.shared.updateEvent(event)
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

struct AllRemindersView: View {
    @Binding var isPresented: Bool
    // BUG-17 FIX: @ObservedObject
    @ObservedObject var manager = CalendarManager.shared

    var body: some View {
        NavigationStack {
            List {
                let futureReminders = manager.events.filter { (!$0.reminders.isEmpty || $0.reminderId != nil) && $0.date >= Calendar.current.startOfDay(for: Date()) }
                    .sorted(by: { $0.date < $1.date })

                if futureReminders.isEmpty {
                    ContentUnavailableView("Nessun Promemoria", systemImage: "bell.slash", description: Text("Tutti i tuoi promemoria appariranno qui."))
                } else {
                    ForEach(futureReminders) { event in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(event.title).font(.headline)
                                Text("\(event.date.formatted(.dateTime.day().month().locale(Locale(identifier: "it_IT"))))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                if !event.reminders.isEmpty {
                                    ForEach(event.reminders) { reminder in
                                        Label(reminder.time.formatted(.dateTime.hour().minute()), systemImage: "clock")
                                            .font(.caption2.bold())
                                            .foregroundColor(.orange)
                                    }
                                } else if let rt = event.reminderTime {
                                    Label(rt.formatted(.dateTime.hour().minute()), systemImage: "clock")
                                        .font(.caption2.bold())
                                        .foregroundColor(.orange)
                                } else if event.reminderId != nil {
                                    Label(event.startTime.formatted(.dateTime.hour().minute()), systemImage: "clock")
                                        .font(.caption2.bold())
                                        .foregroundColor(.orange)
                                }
                            }
                            Spacer()
                            Image(systemName: "bell.fill").foregroundColor(.orange)
                        }
                    }
                }
            }
            .navigationTitle("Promemoria Attivi")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Chiudi") { isPresented = false }
                }
            }
        }
    }
}

struct AddEventView: View {
    @Binding var isPresented: Bool
    let initialDate: Date
    @State private var title = ""
    @State private var startTime: Date

    init(isPresented: Binding<Bool>, initialDate: Date) {
        self._isPresented = isPresented
        self.initialDate = initialDate

        let now = Date()
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: initialDate)
        let nowComps = cal.dateComponents([.hour, .minute], from: now)
        comps.hour = nowComps.hour
        comps.minute = nowComps.minute

        self._startTime = State(initialValue: cal.date(from: comps) ?? initialDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Cosa") {
                    TextField("Esempio: Visita medica", text: $title)
                }
                Section("Quando (\(initialDate.formatted(.dateTime.day().month(.wide).locale(Locale(identifier: "it_IT")))))") {
                    // Feature: usa TimePickerField per rispettare la preferenza utente
                    TimePickerField(label: "Orario", time: $startTime)
                }
            }
            .navigationTitle("Aggiungi Impegno")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Annulla") { isPresented = false } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Salva") {
                        CalendarManager.shared.addEvent(title: title, date: initialDate, startTime: startTime, endTime: nil, hasEndTime: false, reminderEnabled: false)
                        isPresented = false
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

// MARK: - Selected Date Wrapper per sheet(item:)
struct SelectedDate: Identifiable {
    let date: Date
    var id: Date { date }
}
