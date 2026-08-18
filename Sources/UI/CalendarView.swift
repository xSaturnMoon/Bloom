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

// MARK: - CalendarView (Apple Style + Bloom Elegance)

struct CalendarView: View {
    @StateObject var manager = CalendarManager.shared
    @State private var showingAllReminders = false
    @State private var selectedEvent: BloomEvent?
    @State private var currentMonth = Date()
    @State private var selectedDate = Date()
    @State private var showingAddEvent = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Selettore Mese con Frecce
                        HStack {
                            Button { changeMonth(by: -1) } label: {
                                Image(systemName: "chevron.left.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.secondary.opacity(0.6))
                            }
                            
                            Spacer()
                            
                            Text(currentMonth.formatted(.dateTime.month(.wide).year().locale(Locale(identifier: "it_IT"))).capitalized)
                                .font(.title2.bold())
                            
                            Spacer()
                            
                            Button { changeMonth(by: 1) } label: {
                                Image(systemName: "chevron.right.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.secondary.opacity(0.6))
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.top, 4)

                        // Griglia Calendario Mese (Apple Style a 7 Colonne)
                        CalendarMonthGrid(
                            currentMonth: currentMonth,
                            selectedDate: $selectedDate,
                            manager: manager
                        )
                        .gesture(
                            DragGesture(minimumDistance: 40)
                                .onEnded { value in
                                    if value.translation.width < -50 {
                                        changeMonth(by: 1)
                                    } else if value.translation.width > 50 {
                                        changeMonth(by: -1)
                                    }
                                }
                        )

                        // Sezione Impegni del Giorno Selezionato (Agenda)
                        DayAgendaSection(
                            selectedDate: selectedDate,
                            manager: manager,
                            onAddEvent: {
                                showingAddEvent = true
                            },
                            onSelectEvent: { event in
                                selectedEvent = event
                            }
                        )

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
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
                    HStack(spacing: 14) {
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                currentMonth = Date()
                                selectedDate = Date()
                            }
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        } label: {
                            Text("Oggi").bold()
                        }
                        
                        Button {
                            showingAddEvent = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddEvent) {
                AddEventView(isPresented: $showingAddEvent, initialDate: selectedDate)
            }
            .sheet(item: $selectedEvent) { event in
                EditEventView(event: event)
            }
            .sheet(isPresented: $showingAllReminders) {
                AllRemindersView(isPresented: $showingAllReminders)
            }
        }
    }

    func changeMonth(by value: Int) {
        if let newMonth = Calendar.current.date(byAdding: .month, value: value, to: currentMonth) {
            withAnimation(.easeInOut(duration: 0.22)) {
                currentMonth = newMonth
                let cal = Calendar.current
                if !cal.isDate(selectedDate, equalTo: newMonth, toGranularity: .month) {
                    if let firstDay = cal.date(from: cal.dateComponents([.year, .month], from: newMonth)) {
                        selectedDate = firstDay
                    }
                }
            }
        }
    }
}

// MARK: - CalendarMonthGrid

struct CalendarDaySlot: Identifiable {
    let id = UUID()
    let date: Date?
}

struct CalendarMonthGrid: View {
    let currentMonth: Date
    @Binding var selectedDate: Date
    @ObservedObject var manager: CalendarManager

    let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    let weekdays = ["L", "M", "M", "G", "V", "S", "D"]

    var body: some View {
        VStack(spacing: 10) {
            // Intestazione Giorni della Settimana
            HStack {
                ForEach(0..<7, id: \.self) { idx in
                    Text(weekdays[idx])
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 4)

            // Griglia Giorni Mese
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(daysInMonthGrid(for: currentMonth)) { slot in
                    if let date = slot.date {
                        let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                        let isToday = Calendar.current.isDateInToday(date)
                        let hasEvents = manager.hasEvents(on: date)

                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                selectedDate = date
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            VStack(spacing: 3) {
                                Text("\(Calendar.current.component(.day, from: date))")
                                    .font(.system(size: 16, weight: isSelected || isToday ? .bold : .medium, design: .rounded))
                                    .foregroundColor(isSelected ? .white : (isToday ? .blue : .primary))

                                // Pallino indicatore impegni
                                Circle()
                                    .fill(hasEvents ? (isSelected ? .white : Color.orange) : Color.clear)
                                    .frame(width: 5, height: 5)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(
                                isSelected ?
                                Color.blue :
                                (isToday ? Color.blue.opacity(0.12) : Color.clear)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    } else {
                        // Spazio vuoto
                        Color.clear
                            .frame(height: 42)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private func daysInMonthGrid(for date: Date) -> [CalendarDaySlot] {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2 // Lunedì
        cal.locale = Locale(identifier: "it_IT")

        guard let monthInterval = cal.dateInterval(of: .month, for: date) else { return [] }
        let firstOfMonth = monthInterval.start

        let weekdayOfFirst = cal.component(.weekday, from: firstOfMonth)
        let leadingSpaces = (weekdayOfFirst - cal.firstWeekday + 7) % 7

        var slots: [CalendarDaySlot] = []
        for _ in 0..<leadingSpaces {
            slots.append(CalendarDaySlot(date: nil))
        }

        guard let range = cal.range(of: .day, in: .month, for: date) else { return slots }
        for day in range {
            if let dayDate = cal.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                slots.append(CalendarDaySlot(date: dayDate))
            }
        }
        return slots
    }
}

// MARK: - DayAgendaSection

struct DayAgendaSection: View {
    let selectedDate: Date
    @ObservedObject var manager: CalendarManager
    let onAddEvent: () -> Void
    let onSelectEvent: (BloomEvent) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Intestazione Data Selezionata
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedDate.formatted(.dateTime.weekday(.wide).locale(Locale(identifier: "it_IT"))).uppercased())
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    HStack(spacing: 6) {
                        Text(selectedDate.formatted(.dateTime.day().month(.wide).locale(Locale(identifier: "it_IT"))).capitalized)
                            .font(.title3.bold())

                        if Calendar.current.isDateInToday(selectedDate) {
                            Text("Oggi")
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.15))
                                .foregroundColor(.blue)
                                .clipShape(Capsule())
                        }
                    }
                }

                Spacer()

                Button(action: onAddEvent) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Impegno")
                    }
                    .font(.subheadline.bold())
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.12))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 4)

            let events = manager.events(for: selectedDate)

            if events.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary.opacity(0.7))
                        .padding(.top, 20)

                    Text("Nessun impegno in programma")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button(action: onAddEvent) {
                        Text("+ Aggiungi Impegno")
                            .font(.subheadline.bold())
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.12))
                            .foregroundColor(.blue)
                            .clipShape(Capsule())
                    }
                    .padding(.bottom, 20)
                }
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(events) { event in
                        AppleEventCard(event: event) {
                            onSelectEvent(event)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - AppleEventCard

struct AppleEventCard: View {
    let event: BloomEvent
    let onTap: () -> Void
    @ObservedObject var manager = CalendarManager.shared

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Orario
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.startTime.formatted(.dateTime.hour().minute()))
                        .font(.headline)
                        .foregroundColor(.primary)

                    if event.hasEndTime, let endTime = event.endTime {
                        Text(endTime.formatted(.dateTime.hour().minute()))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 55, alignment: .leading)

                // Barra colorata verticale
                Rectangle()
                    .fill(event.isCompleted ? Color.green : Color.blue)
                    .frame(width: 3.5, height: 38)
                    .clipShape(Capsule())

                // Titolo & Notifica
                VStack(alignment: .leading, spacing: 3) {
                    Text(event.title)
                        .font(.body.weight(.medium))
                        .foregroundColor(event.isCompleted ? .secondary : .primary)
                        .strikethrough(event.isCompleted)
                        .lineLimit(2)

                    if !event.reminders.isEmpty || event.reminderId != nil {
                        HStack(spacing: 4) {
                            Image(systemName: "bell.fill")
                                .font(.caption2)
                                .foregroundColor(.orange)
                            Text("Promemoria")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                // Cerchietto completamento
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        manager.toggleComplete(event)
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Image(systemName: event.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(event.isCompleted ? .green : .secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                withAnimation {
                    manager.deleteEvent(event)
                }
            } label: {
                Label("Elimina Impegno", systemImage: "trash")
            }
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
    @State private var reminderEnabled = false

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
                    TextField("Esempio: Visita medica, Riunione...", text: $title)
                }
                Section("Quando (\(initialDate.formatted(.dateTime.day().month(.wide).locale(Locale(identifier: "it_IT")))))") {
                    TimePickerField(label: "Orario", time: $startTime)
                }
                Section("Notifiche") {
                    Toggle("Attiva Promemoria", isOn: $reminderEnabled)
                }
            }
            .navigationTitle("Aggiungi Impegno")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Annulla") { isPresented = false } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Salva") {
                        CalendarManager.shared.addEvent(
                            title: title,
                            date: initialDate,
                            startTime: startTime,
                            endTime: nil,
                            hasEndTime: false,
                            reminderEnabled: reminderEnabled,
                            reminderTime: reminderEnabled ? startTime : nil
                        )
                        isPresented = false
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
