filepath = '/Users/siddwork/Desktop/ChettinadCare-iOS/ChettinadCarePatient/Features/PatientViews.swift'
with open(filepath, 'r') as f:
    content = f.read()

import re
content = re.sub(r'struct RecordCard<Content: View>: View \{\n\s*let content: Content\n\s*init\(@ViewBuilder content: \(\) -> Content\) \{\n\s*self\.content = content\(\)\n\s*\}\n\s*var body: some View \{\n\s*content\n\s*\.frame\(maxWidth: \.infinity, alignment: \.leading\)\n\s*\.padding\(StitchSpacing\.lg\)\n\s*\.background\(Color\.surfaceContainerLowest\)\n\s*\.cornerRadius\(12\)\n\s*\.shadow\(color: Color\.black\.opacity\(0\.05\), radius: 2, x: 0, y: 1\)\n\s*\}\n\}\n\n', '', content)

with open(filepath, 'w') as f:
    f.write(content)
