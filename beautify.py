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

for filename in files_to_process:
    filepath = os.path.join(base_dir, filename)
    if not os.path.exists(filepath):
        print(f"File not found: {filepath}")
        continue
        
    with open(filepath, 'r') as f:
        content = f.read()

    # 1. Replace empty states
    # Text("No active encounters.").foregroundColor(.secondary)
    # -> StitchEmptyState(icon: "doc", title: "No Records", message: "No active encounters.")
    content = re.sub(
        r'Text\(\s*"([^"]+)"\s*\)\s*\.?font\(\.[^\)]+\)?\s*\.?foregroundColor\(\.secondary\)',
        r'StitchEmptyState(icon: "doc.text", title: "No Records", message: "\1")',
        content
    )
    content = re.sub(
        r'Text\(\s*"([^"]+)"\s*\)\s*\.foregroundColor\(\.secondary\)',
        r'StitchEmptyState(icon: "doc.text", title: "No Records", message: "\1")',
        content
    )

    # 2. Error states
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

    # 3. Ad-hoc primary buttons
    # Button(...) { ... }.frame(maxWidth: .infinity).padding().background(...).foregroundColor(...).cornerRadius(...)
    # Actually, let's just replace `.buttonStyle(.borderedProminent)` with `.buttonStyle(StitchPrimaryButtonStyle())` if it exists.
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

    # Clean up standard button modifiers
    # This is trickier. Let's look for known patterns.

    # 4. Spacing
    content = re.sub(r'spacing:\s*8\b', 'spacing: StitchSpacing.sm', content)
    content = re.sub(r'spacing:\s*12\b', 'spacing: StitchSpacing.md', content)
    content = re.sub(r'spacing:\s*16\b', 'spacing: StitchSpacing.lg', content)
    content = re.sub(r'spacing:\s*24\b', 'spacing: StitchSpacing.xl', content)
    
    content = re.sub(r'\.padding\(\s*8\s*\)', '.padding(StitchSpacing.sm)', content)
    content = re.sub(r'\.padding\(\s*16\s*\)', '.padding(StitchSpacing.lg)', content)
    content = re.sub(r'\.padding\(\s*24\s*\)', '.padding(StitchSpacing.xl)', content)
    
    # 5. Fonts
    content = re.sub(r'\.font\(\.headline\)', '.font(Typography.titleMedium)', content)
    content = re.sub(r'\.font\(\.subheadline\)', '.font(Typography.bodyLarge)', content)
    content = re.sub(r'\.font\(\.caption\)', '.font(Typography.labelSmall)', content)
    content = re.sub(r'\.font\(\.caption2\)', '.font(Typography.labelSmall)', content)
    content = re.sub(r'\.font\(\.body\)', '.font(Typography.bodyMedium)', content)

    # 6. Status Chips
    # Replace standard Text("...").font(.caption).bold().padding(...).background(...).foregroundColor(...).cornerRadius(...)
    # Or specifically where we saw `statusBadge(status)`
    if "private func statusBadge" in content:
        # replace the entire function implementation with a wrapper to StitchStatusChip
        content = re.sub(
            r'private func statusBadge\(_ status: String\) -> some View \{[\s\S]*?return Text\(status\.capitalized\)[\s\S]*?\.cornerRadius\(4\)\n\s*\}',
            r'private func statusBadge(_ status: String) -> some View {\n        StitchStatusChip(status: status)\n    }',
            content
        )

    # Let's save it.
    with open(filepath, 'w') as f:
        f.write(content)
    
    print(f"Processed {filename}")

