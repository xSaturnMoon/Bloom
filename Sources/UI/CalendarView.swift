import SwiftUI

// MARK: - Time Picker Field

/// Mostra il selettore orario in base alla preferenza utente:
/// "Apple" → wheel nativo, "Manuale" → digitazione rapida con tastierino numerico (Ore : Minuti)
struct TimePickerField: View {
    let label: String
    @Binding var time: Date
    var isNewEvent: Bool = false
    @AppStorage("timePickerMode") private var timePickerMode: String = "Apple"

    var body: some View {
        if timePickerMode == "Manuale" {
            ManualTimeInputField(label: label, time: $time, isNewEvent: isNewEvent)
        } else {
            DatePicker(label, selection: $time, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
        }
    }
}

/// Inserimento orario manuale scrivendo direttamente con la tastiera numerica:
/// Due caselle grandi e pulite [ ORE ] : [ MINUTI ].
struct ManualTimeInputField: View {
    let label: String
    @Binding var time: Date
    var isNewEvent: Bool = false

    @State private var hourText: String = ""
    @State private var minuteText: String = ""
    @State private var hourHasBeenEdited = false
    @State private var minuteHasBeenEdited = false
    @FocusState private var focusedField: TimeField?

    enum TimeField: Hashable {
        case hour
        case minute
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Spacer()

                // ORE BOX
                VStack(spacing: 4) {
                    TextField("00", text: $hourText)
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .hour)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 36, weight: .semibold, design: .rounded))
                        .frame(width: 82, height: 60)
                        .background(Color(uiColor: .tertiarySystemFill))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(focusedField == .hour ? Color.blue : Color.clear, lineWidth: 2)
                        )
                        .onChange(of: focusedField) { _, newField in
                            if newField == .hour {
                                hourHasBeenEdited = false
                            } else if newField == .minute {
                                minuteHasBeenEdited = false
                            }
                        }
                        .onChange(of: hourText) { _, newValue in
                            handleHourChange(newValue)
                        }

                    Text("Ore")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }

                Text(":")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 20)

                // MINUTI BOX
                VStack(spacing: 4) {
                    TextField("00", text: $minuteText)
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .minute)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 36, weight: .semibold, design: .rounded))
                        .frame(width: 82, height: 60)
                        .background(Color(uiColor: .tertiarySystemFill))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(focusedField == .minute ? Color.blue : Color.clear, lineWidth: 2)
                        )
                        .onChange(of: minuteText) { _, newValue in
                            handleMinuteChange(newValue)
                        }

                    Text("Minuti")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.vertical, 6)
        }
        .onAppear {
            if !isNewEvent {
                syncFromDate()
            }
        }
    }

    private func syncFromDate() {
        let cal = Calendar.current
        let h = cal.component(.hour, from: time)
        let m = cal.component(.minute, from: time)
        hourText = String(format: "%02d", h)
        minuteText = String(format: "%02d", m)
    }

    private func handleHourChange(_ raw: String) {
        var digits = raw.filter { $0.isNumber }

        // Se non è stato ancora modificato durante questa sessione di focus e l'utente ha digitato una cifra,
        // sovrascrive il testo precedente direttamente!
        if !hourHasBeenEdited && digits.count > 1 {
            if let lastDigit = digits.last {
                digits = String(lastDigit)
            }
        }
        hourHasBeenEdited = true

        if digits.count > 2 {
            digits = String(digits.prefix(2))
        }

        if hourText != digits {
            hourText = digits
        }

        if let h = Int(digits) {
            let validH = min(h, 23)
            updateTime(hour: validH, minute: Int(minuteText) ?? 0)

            // Auto-focus al campo minuti se l'utente ha inserito 2 cifre o un numero da 3 a 9
            if digits.count == 2 || (digits.count == 1 && h >= 3) {
                minuteHasBeenEdited = false
                focusedField = .minute
            }
        }
    }

    private func handleMinuteChange(_ raw: String) {
        var digits = raw.filter { $0.isNumber }

        // Sovrascrive il testo precedente alla prima cifra digitata
        if !minuteHasBeenEdited && digits.count > 1 {
            if let lastDigit = digits.last {
                digits = String(lastDigit)
            }
        }
        minuteHasBeenEdited = true

        if digits.count > 2 {
            digits = String(digits.prefix(2))
        }

        if minuteText != digits {
            minuteText = digits
        }

        if let m = Int(digits) {
            let validM = min(m, 59)
            updateTime(hour: Int(hourText) ?? 0, minute: validM)
        }
    }

    private func updateTime(hour: Int, minute: Int) {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: time)
        comps.hour = min(max(hour, 0), 23)
        comps.minute = min(max(minute, 0), 59)
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

                List {
                    // SEZIONE 1: Mese con Frecce e Griglia Calendario
                    Section {
                        VStack(spacing: 14) {
                            HStack {
                                Button { changeMonth(by: -1) } label: {
                                    Image(systemName: "chevron.left.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.secondary.opacity(0.6))
                                }
                                .buttonStyle(.plain)

                                Spacer()

                                Text(currentMonth.formatted(.dateTime.month(.wide).year().locale(Locale(identifier: "it_IT"))).capitalized)
                                    .font(.title2.bold())

                                Spacer()

                                Button { changeMonth(by: 1) } label: {
                                    Image(systemName: "chevron.right.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.secondary.opacity(0.6))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 4)

                            CalendarMonthGrid(
                                currentMonth: currentMonth,
                                selectedDate: $selectedDate,
                                manager: manager
                            )
                        }
                        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }

                    // SEZIONE 2: Intestazione Agenda Giorno
                    Section {
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

                            Button {
                                showingAddEvent = true
                            } label: {
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
                            .buttonStyle(.plain)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }

                    // SEZIONE 3: Lista Impegni o Empty State
                    let events = manager.events(for: selectedDate)
                    if events.isEmpty {
                        Section {
                            VStack(spacing: 12) {
                                Image(systemName: "calendar.badge.clock")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.secondary.opacity(0.7))
                                    .padding(.top, 20)

                                Text("Nessun impegno in programma")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                Button {
                                    showingAddEvent = true
                                } label: {
                                    Text("+ Aggiungi Impegno")
                                        .font(.subheadline.bold())
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.blue.opacity(0.12))
                                        .foregroundColor(.blue)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                                .padding(.bottom, 20)
                            }
                            .frame(maxWidth: .infinity)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                    } else {
                        Section {
                            ForEach(events) { event in
                                AppleEventCard(event: event) {
                                    selectedEvent = event
                                }
                                .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        withAnimation {
                                            manager.deleteEvent(event)
                                        }
                                    } label: {
                                        Label("Elimina", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }

                    Section {
                        Spacer(minLength: 100)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
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
                withAnimation { manager.deleteEvent(event) }
            } label: {
                Label("Elimina Impegno", systemImage: "trash")
            }
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
                    TimePickerField(label: "Orario", time: $startTime, isNewEvent: false)
                }

                Section("Promemoria") {
                    Toggle("🔔 Avvisami con notifica", isOn: $reminderEnabled)

                    if reminderEnabled {
                        TimePickerField(label: "Orario Notifica", time: $reminderTime, isNewEvent: false)
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
                    TimePickerField(label: "Orario", time: $startTime, isNewEvent: true)
                }

                Section("Promemoria") {
                    Toggle("🔔 Avvisami con notifica", isOn: $reminderEnabled)

                    if reminderEnabled {
                        TimePickerField(label: "Orario Notifica", time: $reminderTime, isNewEvent: true)
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
