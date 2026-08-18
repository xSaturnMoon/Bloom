import SwiftUI

// MARK: - Time Picker Field

/// Mostra il selettore orario in base alla preferenza utente:
/// "Apple" → wheel nativo, "Manuale" → stepper visuale con + e –
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
                .frame(maxWidth: .infinity)
        }
    }
}

/// Stepper visuale per l'orario: due colonne Ore / Min con pulsanti + e –.
/// Semplice, immediato, impossibile sbagliare.
struct ManualTimeInputField: View {
    let label: String
    @Binding var time: Date

    private var hour: Int {
        Calendar.current.component(.hour, from: time)
    }
    private var minute: Int {
        Calendar.current.component(.minute, from: time)
    }

    var body: some View {
        VStack(spacing: 12) {
            // Orario corrente grande al centro
            Text(String(format: "%02d:%02d", hour, minute))
                .font(.system(size: 48, weight: .thin, design: .rounded))
                .monospacedDigit()
                .frame(maxWidth: .infinity)

            // Due colonne: Ore | Min
            HStack(spacing: 24) {
                // Ore
                VStack(spacing: 8) {
                    Text("Ore")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    HStack(spacing: 16) {
                        Button { adjustTime(hours: -1) } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)

                        Text("\(hour)")
                            .font(.title3.bold())
                            .monospacedDigit()
                            .frame(width: 32)

                        Button { adjustTime(hours: 1) } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text(":")
                    .font(.title2.bold())
                    .foregroundStyle(.secondary)
                    .padding(.top, 18)

                // Minuti
                VStack(spacing: 8) {
                    Text("Min")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    HStack(spacing: 16) {
                        Button { adjustTime(minutes: -5) } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)

                        Text(String(format: "%02d", minute))
                            .font(.title3.bold())
                            .monospacedDigit()
                            .frame(width: 32)

                        Button { adjustTime(minutes: 5) } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.vertical, 6)

            Text("I minuti variano di 5 in 5")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }

    private func adjustTime(hours: Int = 0, minutes: Int = 0) {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: time)
        let newHour = ((comps.hour ?? 0) + hours + 24) % 24
        let newMinute = ((comps.minute ?? 0) + minutes + 60) % 60
        comps.hour = newHour
        comps.minute = newMinute
        if let newDate = cal.date(from: comps) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            currentMonth = Date()
                            selectedDate = Date()
                        }
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    } label: {
                        Image(systemName: "calendar.badge.clock")
                            .font(.title3)
                            .foregroundColor(.blue)
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
    @State private var offset: CGFloat = 0
    @State private var isOpen = false

    private let deleteWidth: CGFloat = 80

    var body: some View {
        HStack(spacing: 0) {
            // Card principale
            Button(action: {
                if isOpen {
                    closeSwipe()
                } else {
                    onTap()
                }
            }) {
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
            .offset(x: offset)

            // Tasto Elimina fisso a destra
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    offset = -UIScreen.main.bounds.width
                }
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                    manager.deleteEvent(event)
                }
            } label: {
                VStack(spacing: 6) {
                    Image(systemName: "trash.fill")
                        .font(.title3)
                    Text("Elimina")
                        .font(.caption2.bold())
                }
                .foregroundColor(.white)
                .frame(width: deleteWidth)
                .frame(maxHeight: .infinity)
                .background(Color.red)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .offset(x: offset + deleteWidth) // segue la card durante il drag
            .opacity(isOpen ? 1 : 0)
        }
        .gesture(
            DragGesture(minimumDistance: 8, coordinateSpace: .local)
                .onChanged { value in
                    guard value.startLocation.x > 30 else { return } // evita conflitto con nav back
                    let drag = value.translation.width
                    if drag < 0 {
                        // Resistenza naturale: più scorri più rallenta
                        let resistance = isOpen ? drag : drag * 0.7
                        offset = max(resistance, -deleteWidth - 8)
                    } else if isOpen {
                        offset = min(0, -deleteWidth + drag)
                    }
                }
                .onEnded { value in
                    let drag = value.translation.width
                    let velocity = value.predictedEndTranslation.width

                    if drag < -deleteWidth / 2 || velocity < -200 {
                        // Snap aperto
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                            offset = -deleteWidth
                            isOpen = true
                        }
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    } else {
                        // Snap chiuso
                        closeSwipe()
                    }
                }
        )
        .contextMenu {
            Button(role: .destructive) {
                withAnimation { manager.deleteEvent(event) }
            } label: {
                Label("Elimina Impegno", systemImage: "trash")
            }
        }
    }

    private func closeSwipe() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            offset = 0
            isOpen = false
        }
    }
}

// MARK: - EditEventView

struct EditEventView: View {
    @Environment(\.dismiss) var dismiss
    @State var event: BloomEvent
    @State private var title: String
    @State private var date: Date
    @State private var startTime: Date
    @State private var reminderEnabled: Bool
    @State private var reminderTime: Date

    init(event: BloomEvent) {
        self._event = State(initialValue: event)
        self._title = State(initialValue: event.title)
        self._date = State(initialValue: event.date)
        self._startTime = State(initialValue: event.startTime)

        let hasReminder = !event.reminders.isEmpty || event.reminderId != nil
        self._reminderEnabled = State(initialValue: hasReminder)
        
        let initialReminderTime = event.reminders.first?.time ?? event.reminderTime ?? event.startTime
        self._reminderTime = State(initialValue: initialReminderTime)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Cosa") {
                    TextField("Titolo impegno", text: $title)
                        .font(.body)
                }

                Section("Quando") {
                    DatePicker("Giorno", selection: $date, displayedComponents: .date)
                    TimePickerField(label: "Orario", time: $startTime)
                }

                Section("Promemoria") {
                    Toggle("🔔 Avvisami con notifica", isOn: $reminderEnabled)

                    if reminderEnabled {
                        TimePickerField(label: "Orario Notifica", time: $reminderTime)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        CalendarManager.shared.deleteEvent(event)
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Label("Elimina Impegno", systemImage: "trash")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Modifica Impegno")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annulla") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Salva") {
                        saveChanges()
                    }
                    .bold()
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func saveChanges() {
        event.title = title.trimmingCharacters(in: .whitespaces)
        event.date = date
        event.startTime = startTime

        if reminderEnabled {
            event.reminderTime = reminderTime
            let id = event.reminders.first?.notificationId ?? event.reminderId ?? UUID().uuidString
            event.reminderId = id
            event.reminders = [EventReminder(time: reminderTime, notificationId: id)]
        } else {
            event.reminderTime = nil
            event.reminderId = nil
            event.reminders = []
        }

        CalendarManager.shared.updateEvent(event)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismiss()
    }
}

// MARK: - AllRemindersView

struct AllRemindersView: View {
    @Binding var isPresented: Bool
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

// MARK: - AddEventView

struct AddEventView: View {
    @Binding var isPresented: Bool
    let initialDate: Date
    @State private var title = ""
    @State private var date: Date
    @State private var startTime: Date
    @State private var reminderEnabled = false
    @State private var reminderTime: Date

    init(isPresented: Binding<Bool>, initialDate: Date) {
        self._isPresented = isPresented
        self.initialDate = initialDate
        self._date = State(initialValue: initialDate)

        let now = Date()
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: initialDate)
        let nowComps = cal.dateComponents([.hour, .minute], from: now)
        comps.hour = nowComps.hour
        comps.minute = nowComps.minute

        let start = cal.date(from: comps) ?? initialDate
        self._startTime = State(initialValue: start)
        self._reminderTime = State(initialValue: start)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Cosa devi fare?") {
                    TextField("Esempio: Visita medica, Dentista, Spesa...", text: $title)
                        .font(.body)
                }

                Section("Quando") {
                    DatePicker("Giorno", selection: $date, displayedComponents: .date)
                    TimePickerField(label: "Orario", time: $startTime)
                }

                Section("Promemoria") {
                    Toggle("🔔 Avvisami con notifica", isOn: $reminderEnabled)

                    if reminderEnabled {
                        TimePickerField(label: "Orario Notifica", time: $reminderTime)
                    }
                }
            }
            .navigationTitle("Nuovo Impegno")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annulla") { isPresented = false }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Salva") {
                        saveAndDismiss()
                    }
                    .bold()
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func saveAndDismiss() {
        let cleanTitle = title.trimmingCharacters(in: .whitespaces)
        guard !cleanTitle.isEmpty else { return }

        CalendarManager.shared.addEvent(
            title: cleanTitle,
            date: date,
            startTime: startTime,
            endTime: nil,
            hasEndTime: false,
            reminderEnabled: reminderEnabled,
            reminderTime: reminderEnabled ? reminderTime : nil
        )
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        isPresented = false
    }
}
