import re

filepath = '/Users/siddwork/Desktop/ChettinadCare-iOS/ChettinadCarePatient/Features/PatientCarePlanView.swift'
with open(filepath, 'r') as f:
    content = f.read()

# Replace the full errorStateView function
content = re.sub(
r'    private func errorStateView\(_ message: String\) -> some View \{\n\s*VStack\(spacing: StitchSpacing\.lg\) \{\n\s*Image\(systemName: "exclamationmark\.triangle\.fill"\)\n\s*\.font\(\.system\(size: 42\)\)\n\s*\.foregroundColor\(\.orange\)\n\s*Text\("Care Plan unavailable"\)\.font\(Typography\.titleMedium\)\n\s*Text\(message\)\.font\(Typography\.bodyLarge\)\.foregroundStyle\(Color\.chettinadTextSecondary\)\.multilineTextAlignment\(\.center\)\n\s*Button\("Try Again"\) \{ Task \{ await viewModel\.fetchTodayCarePlan\(\); await viewModel\.fetchTimeline\(\) \} \}\n\s*\.buttonStyle\(StitchPrimaryButtonStyle\(\)\)\n\s*\}\n\s*\.padding\(32\)\n\s*\}',
'''    private func errorStateView(_ message: String) -> some View {
        StitchErrorState(message: message) {
            Task { await viewModel.fetchTodayCarePlan(); await viewModel.fetchTimeline() }
        }
        .padding(32)
    }''', content)

with open(filepath, 'w') as f:
    f.write(content)
