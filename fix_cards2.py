import re

def process_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    # We can replace the `.background(Color(UIColor.secondarySystemGroupedBackground))` patterns by wrapping the content in `StitchCard {`
    # Let's see PatientCarePlanView.swift
    content = content.replace('''        return VStack {
            HStack {
                Text("Daily Progress")
                    .font(Typography.bodyLarge)
                    .foregroundStyle(Color.chettinadTextSecondary)
                Spacer()
                Text("\(completed) of \(total) completed")
                    .font(Typography.bodyLarge).bold()
            }
            ProgressView(value: percent)
                .tint(.green)
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal)''',
        '''        return StitchCard {
            HStack {
                Text("Daily Progress")
                    .font(Typography.bodyLarge)
                    .foregroundStyle(Color.chettinadTextSecondary)
                Spacer()
                Text("\(completed) of \(total) completed")
                    .font(Typography.bodyLarge).bold()
            }
            ProgressView(value: percent)
                .tint(.green)
        }
        .padding(.horizontal)''')
        
    content = content.replace('''    private func nextActionCard(task: CarePlanOccurrenceDTO) -> some View {
        VStack(alignment: .leading, spacing: StitchSpacing.md) {
            Text("Next Action")
                .font(Typography.bodyMedium).bold()
                .foregroundColor(.blue)
                .textCase(.uppercase)
            
            Text(task.title)
                .font(Typography.titleMedium).bold()
            
            Text(task.instruction)
                .font(Typography.bodyLarge)
                .foregroundStyle(Color.chettinadTextSecondary)
            
            HStack {
                Image(systemName: "clock")
                Text("Due at \(task.due_time)")
            }
            .font(Typography.bodyMedium)
            .foregroundStyle(Color.chettinadTextSecondary)
            
            Button(action: {
                handleTaskAction(task)
            }) {
                Text(actionTitle(for: task))
                    .font(Typography.titleMedium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }''',
        '''    private func nextActionCard(task: CarePlanOccurrenceDTO) -> some View {
        StitchCard {
            Text("Next Action")
                .font(Typography.bodyMedium).bold()
                .foregroundColor(.blue)
                .textCase(.uppercase)
            
            Text(task.title)
                .font(Typography.titleMedium).bold()
            
            Text(task.instruction)
                .font(Typography.bodyLarge)
                .foregroundStyle(Color.chettinadTextSecondary)
            
            HStack {
                Image(systemName: "clock")
                Text("Due at \(task.due_time)")
            }
            .font(Typography.bodyMedium)
            .foregroundStyle(Color.chettinadTextSecondary)
            
            Button(action: {
                handleTaskAction(task)
            }) {
                Text(actionTitle(for: task))
            }
            .buttonStyle(StitchPrimaryButtonStyle())
        }
        .padding(.horizontal)
    }''')
        
    content = content.replace('''        return HStack(spacing: StitchSpacing.lg) {
            ZStack {
                Circle()
                    .fill(isDone ? Color.green : (isMissed ? Color.red.opacity(0.2) : Color.blue.opacity(0.1)))
                    .frame(width: 40, height: 40)
                
                Image(systemName: iconFor(type: occurrence.task_type))
                    .foregroundColor(isDone ? .white : (isMissed ? .red : .blue))
            }
            
            VStack(alignment: .leading, spacing: StitchSpacing.xs) {
                Text(occurrence.title)
                    .font(Typography.titleMedium)
                    .strikethrough(isDone || isSkipped, color: .secondary)
                Text(occurrence.instruction)
                    .font(Typography.bodyLarge)
                    .foregroundStyle(Color.chettinadTextSecondary)
                
                if let val = occurrence.recorded_value {
                    Text("Recorded: \(String(format: "%.1f", val)) \(occurrence.target_unit ?? "")")
                        .font(Typography.bodyMedium).bold()
                        .foregroundColor(.green)
                }
            }
            Spacer()
            
            VStack(alignment: .trailing) {
                Text(occurrence.due_time)
                    .font(Typography.bodyMedium)
                    .foregroundStyle(Color.chettinadTextSecondary)
                
                if isDone {
                    Text("Done")
                        .font(Typography.bodySmall).bold()
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(4)
                } else if isSkipped {
                    Text("Skipped")
                        .font(Typography.bodySmall).bold()
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.gray)
                        .cornerRadius(4)
                } else if isMissed {
                    Text("Missed")
                        .font(Typography.bodySmall).bold()
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.red.opacity(0.2))
                        .foregroundStyle(Color.chettinadError)
                        .cornerRadius(4)
                } else {
                    if occurrence.task_type == .MEDICATION || occurrence.task_type == .INSULIN {
                        Menu("Action") {
                            Button("Mark Taken") { submit(occurrence, status: "TAKEN") }
                            Button("Skip", role: .destructive) { submit(occurrence, status: "SKIPPED") }
                        }
                        .font(Typography.bodyMedium).bold().buttonStyle(StitchPrimaryButtonStyle())
                    } else {
                        Button("Action") { handleTaskAction(occurrence) }
                            .font(Typography.bodyMedium).bold().buttonStyle(StitchPrimaryButtonStyle())
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal)''',
        '''        return StitchCard {
            HStack(spacing: StitchSpacing.lg) {
                ZStack {
                    Circle()
                        .fill(isDone ? Color.green : (isMissed ? Color.red.opacity(0.2) : Color.blue.opacity(0.1)))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: iconFor(type: occurrence.task_type))
                        .foregroundColor(isDone ? .white : (isMissed ? .red : .blue))
                }
                
                VStack(alignment: .leading, spacing: StitchSpacing.xs) {
                    Text(occurrence.title)
                        .font(Typography.titleMedium)
                        .strikethrough(isDone || isSkipped, color: .secondary)
                    Text(occurrence.instruction)
                        .font(Typography.bodyLarge)
                        .foregroundStyle(Color.chettinadTextSecondary)
                    
                    if let val = occurrence.recorded_value {
                        Text("Recorded: \(String(format: "%.1f", val)) \(occurrence.target_unit ?? "")")
                            .font(Typography.bodyMedium).bold()
                            .foregroundColor(.green)
                    }
                }
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text(occurrence.due_time)
                        .font(Typography.bodyMedium)
                        .foregroundStyle(Color.chettinadTextSecondary)
                    
                    if isDone {
                        StitchStatusChip(status: "COMPLETED")
                    } else if isSkipped {
                        StitchStatusChip(status: "SKIPPED")
                    } else if isMissed {
                        StitchStatusChip(status: "MISSED")
                    } else {
                        if occurrence.task_type == .MEDICATION || occurrence.task_type == .INSULIN {
                            Menu("Action") {
                                Button("Mark Taken") { submit(occurrence, status: "TAKEN") }
                                Button("Skip", role: .destructive) { submit(occurrence, status: "SKIPPED") }
                            }
                            .font(Typography.bodyMedium).bold().buttonStyle(StitchPrimaryButtonStyle())
                        } else {
                            Button("Action") { handleTaskAction(occurrence) }
                                .font(Typography.bodyMedium).bold().buttonStyle(StitchPrimaryButtonStyle())
                        }
                    }
                }
            }
        }
        .padding(.horizontal)''')

    content = content.replace('''                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(event.title ?? event.task_type?.rawValue.capitalized ?? "Care Plan update").font(Typography.bodyLarge).bold()
                        Text(event.status.capitalized).font(Typography.bodyMedium).foregroundStyle(Color.chettinadTextSecondary)
                        if let value = event.observation?.components?.first {
                            Text("\(String(format: "%.1f", value.numeric_value)) \(value.unit)").font(Typography.bodyMedium).foregroundColor(.green)
                        }
                    }
                    Spacer()
                    Text(event.occurrence_date).font(Typography.bodySmall).foregroundStyle(Color.chettinadTextSecondary)
                }
                .padding(StitchSpacing.md)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(10)''',
        '''                StitchCard {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(event.title ?? event.task_type?.rawValue.capitalized ?? "Care Plan update").font(Typography.bodyLarge).bold()
                            Text(event.status.capitalized).font(Typography.bodyMedium).foregroundStyle(Color.chettinadTextSecondary)
                            if let value = event.observation?.components?.first {
                                Text("\(String(format: "%.1f", value.numeric_value)) \(value.unit)").font(Typography.bodyMedium).foregroundColor(.green)
                            }
                        }
                        Spacer()
                        Text(event.occurrence_date).font(Typography.bodySmall).foregroundStyle(Color.chettinadTextSecondary)
                    }
                }''')
                
    content = content.replace('''                VStack(alignment: .leading, spacing: 3) {
                    Text(record.record_type.replacingOccurrences(of: "_", with: " ").capitalized).font(Typography.bodyLarge).bold()
                    if record.record_type == "ACTIVITY" { Text("\(record.activity_name ?? "Activity") · \(record.duration_minutes ?? 0) min") }
                    else if record.record_type == "BLOOD_PRESSURE" { Text("\(record.numeric_value ?? 0, specifier: "%.0f")/\(record.secondary_numeric_value ?? 0, specifier: "%.0f") mmHg") }
                    else { Text("\(record.numeric_value ?? 0, specifier: "%.1f") \(record.unit ?? "")") }
                    Text("Patient self-recorded · \(ISODate.display(record.observed_at))").font(Typography.bodyMedium).foregroundStyle(Color.chettinadTextSecondary)
                }.padding(StitchSpacing.md).frame(maxWidth: .infinity, alignment: .leading).background(Color(UIColor.secondarySystemGroupedBackground)).cornerRadius(10)''',
        '''                StitchCard {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(record.record_type.replacingOccurrences(of: "_", with: " ").capitalized).font(Typography.bodyLarge).bold()
                        if record.record_type == "ACTIVITY" { Text("\(record.activity_name ?? "Activity") · \(record.duration_minutes ?? 0) min") }
                        else if record.record_type == "BLOOD_PRESSURE" { Text("\(record.numeric_value ?? 0, specifier: "%.0f")/\(record.secondary_numeric_value ?? 0, specifier: "%.0f") mmHg") }
                        else { Text("\(record.numeric_value ?? 0, specifier: "%.1f") \(record.unit ?? "")") }
                        Text("Patient self-recorded · \(ISODate.display(record.observed_at))").font(Typography.bodyMedium).foregroundStyle(Color.chettinadTextSecondary)
                    }
                }''')

    with open(filepath, 'w') as f:
        f.write(content)

process_file('/Users/siddwork/Desktop/ChettinadCare-iOS/ChettinadCarePatient/Features/PatientCarePlanView.swift')

def process_trends(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    content = content.replace('''                Chart(glucoseData) { item in
                    LineMark(
                        x: .value("Date", item.date),
                        y: .value("Level", item.value)
                    )
                    .symbol(Circle())
                    .interpolationMethod(.monotone)
                }
                .frame(height: 200)
                .padding()
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal)''',
        '''                StitchCard {
                    Chart(glucoseData) { item in
                        LineMark(
                            x: .value("Date", item.date),
                            y: .value("Level", item.value)
                        )
                        .symbol(Circle())
                        .interpolationMethod(.monotone)
                    }
                    .frame(height: 200)
                }
                .padding(.horizontal)''')

    content = content.replace('''                // Table
                VStack(spacing: 0) {
                    ForEach(glucoseData.reversed().prefix(5)) { item in
                        HStack {
                            Text(item.date, format: .dateTime.month().day().hour().minute())
                                .font(Typography.bodyLarge)
                            Spacer()
                            Text("\(String(format: "%.1f", item.value)) mg/dL")
                                .font(Typography.bodyLarge).bold()
                        }
                        .padding()
                        Divider()
                    }
                }
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal)''',
        '''                // Table
                StitchCard {
                    VStack(spacing: 0) {
                        ForEach(glucoseData.reversed().prefix(5)) { item in
                            HStack {
                                Text(item.date, format: .dateTime.month().day().hour().minute())
                                    .font(Typography.bodyLarge)
                                Spacer()
                                Text("\(String(format: "%.1f", item.value)) mg/dL")
                                    .font(Typography.bodyLarge).bold()
                            }
                            .padding(.vertical, StitchSpacing.sm)
                            if item.id != glucoseData.reversed().prefix(5).last?.id {
                                Divider()
                            }
                        }
                    }
                }
                .padding(.horizontal)''')
                
    content = content.replace('''                VStack(spacing: 0) {
                    ForEach(insulinRecords.prefix(5)) { record in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(record.title ?? "Insulin").font(Typography.bodyLarge).bold()
                                Text(formatDate(record.recorded_at)).font(Typography.bodyMedium).foregroundStyle(Color.chettinadTextSecondary)
                            }
                            Spacer()
                            statusBadge(record.status)
                        }
                        .padding()
                        Divider()
                    }
                }
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal)''',
        '''                StitchCard {
                    VStack(spacing: 0) {
                        ForEach(insulinRecords.prefix(5)) { record in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(record.title ?? "Insulin").font(Typography.bodyLarge).bold()
                                    Text(formatDate(record.recorded_at)).font(Typography.bodyMedium).foregroundStyle(Color.chettinadTextSecondary)
                                }
                                Spacer()
                                StitchStatusChip(status: record.status)
                            }
                            .padding(.vertical, StitchSpacing.sm)
                            if record.id != insulinRecords.prefix(5).last?.id {
                                Divider()
                            }
                        }
                    }
                }
                .padding(.horizontal)''')

    content = content.replace('''                VStack(spacing: 0) {
                    ForEach(medicationRecords.prefix(5)) { record in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(record.title ?? "Medication").font(Typography.bodyLarge).bold()
                                Text(formatDate(record.recorded_at)).font(Typography.bodyMedium).foregroundStyle(Color.chettinadTextSecondary)
                            }
                            Spacer()
                            statusBadge(record.status)
                        }
                        .padding()
                        Divider()
                    }
                }
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal)''',
        '''                StitchCard {
                    VStack(spacing: 0) {
                        ForEach(medicationRecords.prefix(5)) { record in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(record.title ?? "Medication").font(Typography.bodyLarge).bold()
                                    Text(formatDate(record.recorded_at)).font(Typography.bodyMedium).foregroundStyle(Color.chettinadTextSecondary)
                                }
                                Spacer()
                                StitchStatusChip(status: record.status)
                            }
                            .padding(.vertical, StitchSpacing.sm)
                            if record.id != medicationRecords.prefix(5).last?.id {
                                Divider()
                            }
                        }
                    }
                }
                .padding(.horizontal)''')

    content = content.replace('''                VStack(spacing: 0) {
                    // Combine and sort
                    let combined: [(title: String, date: String, status: String?, mins: Int?)] = (
                        activityRecords.map { ($0.title ?? "Activity", $0.recorded_at, $0.status, nil) } +
                        selfActivityRecords.map { ($0.activity_name ?? "Activity", $0.observed_at, "RECORDED", $0.duration_minutes) }
                    ).sorted { sortDate($0.date) > sortDate($1.date) }
                    
                    ForEach(Array(combined.prefix(5).enumerated()), id: \.offset) { _, item in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(item.title).font(Typography.bodyLarge).bold()
                                Text(formatDate(item.date)).font(Typography.bodyMedium).foregroundStyle(Color.chettinadTextSecondary)
                            }
                            Spacer()
                            if let status = item.status {
                                if status == "RECORDED", let mins = item.mins {
                                    Text("\(mins) min").font(Typography.bodyMedium).bold().padding(StitchSpacing.xs).background(Color.blue.opacity(0.2)).foregroundColor(.blue).cornerRadius(4)
                                } else {
                                    statusBadge(status)
                                }
                            }
                        }
                        .padding()
                        Divider()
                    }
                }
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal)''',
        '''                StitchCard {
                    VStack(spacing: 0) {
                        // Combine and sort
                        let combined: [(title: String, date: String, status: String?, mins: Int?)] = (
                            activityRecords.map { ($0.title ?? "Activity", $0.recorded_at, $0.status, nil) } +
                            selfActivityRecords.map { ($0.activity_name ?? "Activity", $0.observed_at, "RECORDED", $0.duration_minutes) }
                        ).sorted { sortDate($0.date) > sortDate($1.date) }
                        
                        ForEach(Array(combined.prefix(5).enumerated()), id: \.offset) { index, item in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(item.title).font(Typography.bodyLarge).bold()
                                    Text(formatDate(item.date)).font(Typography.bodyMedium).foregroundStyle(Color.chettinadTextSecondary)
                                }
                                Spacer()
                                if let status = item.status {
                                    if status == "RECORDED", let mins = item.mins {
                                        Text("\(mins) min").font(Typography.bodyMedium).bold().padding(StitchSpacing.xs).background(Color.blue.opacity(0.2)).foregroundColor(.blue).cornerRadius(4)
                                    } else {
                                        StitchStatusChip(status: status)
                                    }
                                }
                            }
                            .padding(.vertical, StitchSpacing.sm)
                            if index != combined.prefix(5).count - 1 {
                                Divider()
                            }
                        }
                    }
                }
                .padding(.horizontal)''')
                
    content = content.replace('''    private func statusBadge(_ status: String) -> some View {
        let color: Color
        switch status.uppercased() {
        case "COMPLETED", "TAKEN": color = .green
        case "MISSED": color = .red
        case "SKIPPED": color = .gray
        default: color = .blue
        }
        return Text(status.capitalized)
            .font(Typography.bodySmall).bold()
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(4)
    }''', '')

    with open(filepath, 'w') as f:
        f.write(content)

process_trends('/Users/siddwork/Desktop/ChettinadCare-iOS/ChettinadCarePatient/Features/PatientTrendsView.swift')

