import re
import os

files_to_process = [
    "ChettinadCareStaff/Features/StaffViews.swift",
    "ChettinadCareStaff/Features/AdminViews.swift",
    "ChettinadCareStaff/Features/DoctorConsultationViews.swift",
    "ChettinadCareStaff/Features/NurseTriageViews.swift",
    "ChettinadCareStaff/Features/PatientCarePlanMonitoringView.swift"
]

base_dir = "/Users/siddwork/Desktop/ChettinadCare-iOS"

def replace_in_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    # Empty States - look for specific "No ..." strings
    empty_strings = [
        "No readings in this period.",
        "No insulin records.",
        "No medication records.",
        "No activity records.",
        "No active care plan tasks.",
        "No active encounters.",
        "No records found."
    ]
    for es in empty_strings:
        content = re.sub(
            r'Text\(\s*"' + re.escape(es) + r'"\s*\)\s*\.?font\(\.[^\)]+\)?\s*\.?foregroundColor\(\.secondary\)(?:\s*\.padding\([^\)]*\))?',
            r'StitchEmptyState(icon: "doc.text", title: "No Records", message: "' + es + '")',
            content
        )
        content = re.sub(
            r'Text\(\s*"' + re.escape(es) + r'"\s*\)\s*\.?foregroundColor\(\.secondary\)(?:\s*\.padding\([^\)]*\))?',
            r'StitchEmptyState(icon: "doc.text", title: "No Records", message: "' + es + '")',
            content
        )

    # Error States
    content = re.sub(
        r'Text\(\s*error\s*\)\.foregroundColor\(\.red\)',
        r'StitchErrorState(message: error)',
        content
    )
    content = re.sub(
        r'Text\(\s*viewModel\.errorMessage\s*\?\?\s*""\s*\)\.foregroundColor\(\.red\)',
        r'StitchErrorState(message: viewModel.errorMessage ?? "An error occurred")',
        content
    )

    # Fonts
    content = re.sub(r'\.font\(\.headline\)', '.font(Typography.titleMedium)', content)
    content = re.sub(r'\.font\(\.subheadline\)', '.font(Typography.bodyLarge)', content)
    
    # Status Badges in StaffViews.swift
    if "private func statusBadge" in content:
        content = re.sub(
            r'private func statusBadge\(_ status: String\) -> some View \{[\s\S]*?return Text\(status\.capitalized\)[\s\S]*?\.cornerRadius\(4\)\n\s*\}',
            r'private func statusBadge(_ status: String) -> some View {\n        StitchStatusChip(status: status)\n    }',
            content
        )
    # Inline status badge replacement in PatientCarePlanMonitoringView
    content = re.sub(
        r'Text\(occurrence\.status\.capitalized\)\s*\.font\(\.caption2\)\.bold\(\)\s*\.padding\(\.horizontal, 6\)\.padding\(\.vertical, 2\)\s*\.background\(statusColor\(occurrence\.status\)\.opacity\(0\.2\)\)\s*\.foregroundColor\(statusColor\(occurrence\.status\)\)\s*\.cornerRadius\(4\)',
        r'StitchStatusChip(status: occurrence.status)',
        content
    )

    # Spacing
    content = re.sub(r'spacing:\s*8\b', 'spacing: StitchSpacing.sm', content)
    content = re.sub(r'spacing:\s*12\b', 'spacing: StitchSpacing.md', content)
    content = re.sub(r'spacing:\s*16\b', 'spacing: StitchSpacing.lg', content)
    
    content = re.sub(r'\.padding\(\s*8\s*\)', '.padding(StitchSpacing.sm)', content)
    content = re.sub(r'\.padding\(\s*16\s*\)', '.padding(StitchSpacing.lg)', content)
    content = re.sub(r'\.padding\(\s*24\s*\)', '.padding(StitchSpacing.xl)', content)

    # Ad-hoc buttons
    content = re.sub(
        r'\.buttonStyle\(\.borderedProminent\)',
        r'.buttonStyle(StitchPrimaryButtonStyle())',
        content
    )
    content = re.sub(
        r'\.buttonStyle\(\.bordered\)',
        r'.buttonStyle(StitchSecondaryButtonStyle())',
        content
    )

    with open(filepath, 'w') as f:
        f.write(content)

for filename in files_to_process:
    filepath = os.path.join(base_dir, filename)
    if os.path.exists(filepath):
        replace_in_file(filepath)
