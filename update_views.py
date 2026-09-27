import re

def update_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    # Cards
    content = re.sub(r'RecordCard \{', 'StitchCard {', content)
    
    # ProgressView
    content = re.sub(r'ProgressView\(\)\n(\s*)\.padding\(\)', r'ProgressView()\n\1.padding(StitchSpacing.xxl)', content)

    # Empty State
    content = re.sub(r'VStack\(spacing: 16\) \{\n\s*Image\(systemName: "calendar"\)\.font\(\.system\(size: 48\)\)\.foregroundColor\(\.secondary\);\n\s*Text\("No upcoming appointments"\)\.font\(\.headline\);\n\s*Text\("Book an appointment with the\\nObstetrics & Gynaecology care team\."\)\.font\(\.subheadline\)\.foregroundColor\(\.secondary\)\.multilineTextAlignment\(\.center\);\n\s*Button\("Request Appointment"\) \{ showingBooking = true \}\.buttonStyle\(\.borderedProminent\)\n\s*\}\.frame\(maxWidth: \.infinity, alignment: \.center\)\.padding\(\.vertical, 40\)\.listRowBackground\(Color\.clear\)',
    '''StitchEmptyState(icon: "calendar", title: "No upcoming appointments", message: "Book an appointment with the\\nObstetrics & Gynaecology care team.", ctaTitle: "Request Appointment") { showingBooking = true }
                        .listRowBackground(Color.clear)''', content)

    # Status Chips
    content = re.sub(r'Text\(apt\.status == "PENDING_CONFIRMATION" \? "Awaiting confirmation" : apt\.status\.replacingOccurrences\(of: "_", with: " "\)\)\.foregroundColor\(colorForStatus\(apt\.status\)\)', r'StitchStatusChip(status: apt.status)', content)
    
    content = re.sub(r'Text\(entry\.status\.replacingOccurrences\(of: "_", with: " "\)\)\n\s*\.font\(\.caption\)\n\s*\.padding\(\.horizontal, 8\)\n\s*\.padding\(\.vertical, 4\)\n\s*\.background\(Color\.blue\.opacity\(0\.1\)\)\n\s*\.foregroundColor\(\.blue\)\n\s*\.cornerRadius\(8\)', r'StitchStatusChip(status: entry.status)', content)

    content = re.sub(r'Text\(lab\.status\)\n\s*\.textStyle\(Typography\.labelSmall, color: \.chettinadSecondary\)\n\s*\.padding\(\.horizontal, 8\)\n\s*\.padding\(\.vertical, 4\)\n\s*\.background\(Color\.surfaceContainerHigh\)\n\s*\.cornerRadius\(8\)', r'StitchStatusChip(status: lab.status)', content)

    # Button styles
    content = re.sub(r'\.buttonStyle\(\.borderedProminent\)', r'.buttonStyle(StitchPrimaryButtonStyle())', content)
    content = re.sub(r'\.buttonStyle\(\.bordered\)', r'.buttonStyle(StitchSecondaryButtonStyle())', content)
    
    # Typography
    content = re.sub(r'\.font\(\.headline\)', r'.font(Typography.titleMedium)', content)
    content = re.sub(r'\.font\(\.subheadline\)', r'.font(Typography.bodyLarge)', content)
    content = re.sub(r'\.font\(\.caption\)', r'.font(Typography.bodyMedium)', content)
    content = re.sub(r'\.font\(\.caption2\)', r'.font(Typography.bodySmall)', content)
    content = re.sub(r'\.font\(\.title2\)', r'.font(Typography.titleLarge)', content)
    content = re.sub(r'\.font\(\.title3\)', r'.font(Typography.titleMedium)', content)
    
    # Text styles
    content = re.sub(r'\.foregroundColor\(\.secondary\)', r'.foregroundStyle(Color.chettinadTextSecondary)', content)
    content = re.sub(r'\.foregroundColor\(\.red\)', r'.foregroundStyle(Color.chettinadError)', content)
    
    # Spacing
    content = re.sub(r'spacing: 24', r'spacing: StitchSpacing.xl', content)
    content = re.sub(r'spacing: 16', r'spacing: StitchSpacing.lg', content)
    content = re.sub(r'spacing: 12', r'spacing: StitchSpacing.md', content)
    content = re.sub(r'spacing: 8', r'spacing: StitchSpacing.sm', content)
    content = re.sub(r'spacing: 4', r'spacing: StitchSpacing.xs', content)
    content = re.sub(r'\.padding\(16\)', r'.padding(StitchSpacing.lg)', content)
    content = re.sub(r'\.padding\(12\)', r'.padding(StitchSpacing.md)', content)
    content = re.sub(r'\.padding\(8\)', r'.padding(StitchSpacing.sm)', content)
    content = re.sub(r'\.padding\(4\)', r'.padding(StitchSpacing.xs)', content)
    content = re.sub(r'\.padding\(\.horizontal, 16\)', r'.padding(.horizontal, StitchSpacing.lg)', content)
    content = re.sub(r'\.padding\(\.vertical, 16\)', r'.padding(.vertical, StitchSpacing.lg)', content)
    content = re.sub(r'\.padding\(\.bottom, 24\)', r'.padding(.bottom, StitchSpacing.xl)', content)
    content = re.sub(r'\.padding\(\.top, 16\)', r'.padding(.top, StitchSpacing.lg)', content)

    # Empty State for Queue
    content = re.sub(r'VStack\(spacing: StitchSpacing\.lg\) \{\n\s*Image\(systemName: "checkmark\.circle\.fill"\)\n\s*\.font\(\.system\(size: 60\)\)\n\s*\.foregroundColor\(\.green\)\n\s*Text\("You\'re not currently in the queue\."\)\n\s*\.font\(Typography\.titleMedium\)\n\s*Text\("Check-in to your appointment at the hospital desk to track your wait time here\."\)\n\s*\.foregroundStyle\(Color\.chettinadTextSecondary\)\n\s*\.multilineTextAlignment\(\.center\)\n\s*\.padding\(\.horizontal\)\n\s*\}\.padding\(\.top, 60\)',
    '''StitchEmptyState(icon: "checkmark.circle.fill", title: "You're not currently in the queue.", message: "Check-in to your appointment at the hospital desk to track your wait time here.")
                            .padding(.top, 60)''', content)

    with open(filepath, 'w') as f:
        f.write(content)

for filepath in [
    '/Users/siddwork/Desktop/ChettinadCare-iOS/ChettinadCarePatient/Features/PatientViews.swift',
    '/Users/siddwork/Desktop/ChettinadCare-iOS/ChettinadCarePatient/Features/PatientCarePlanView.swift',
    '/Users/siddwork/Desktop/ChettinadCare-iOS/ChettinadCarePatient/Features/PatientTrendsView.swift'
]:
    update_file(filepath)
