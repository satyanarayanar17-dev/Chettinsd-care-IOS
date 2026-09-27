import re

filepath = '/Users/siddwork/Desktop/ChettinadCare-iOS/ChettinadCarePatient/Features/PatientTrendsView.swift'
with open(filepath, 'r') as f:
    content = f.read()

content = re.sub(r'Text\(error\)\n\s*\.foregroundColor\(\.chettinadError\)\n\s*\.padding\(\)',
'''StitchErrorState(message: error) {
                            Task { await viewModel.fetchTimeline() }
                        }''', content)

with open(filepath, 'w') as f:
    f.write(content)
