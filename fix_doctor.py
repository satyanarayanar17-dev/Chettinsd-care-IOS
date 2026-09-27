import re
import os

filepath = "/Users/siddwork/Desktop/ChettinadCare-iOS/ChettinadCareStaff/Features/DoctorConsultationViews.swift"

with open(filepath, 'r') as f:
    content = f.read()

# Replace first card
content = re.sub(
    r'(HStack\s*\{\s*VStack\(alignment: \.leading, spacing: 4\)\s*\{[\s\S]*?Image\(systemName: "person\.text\.rectangle"\)[\s\S]*?\}\s*)\}\s*\.padding\(\)\s*\.background\(Color\(\.secondarySystemBackground\)\)\s*\.cornerRadius\(12\)',
    r'StitchCard {\n                        \1}\n                    }',
    content
)

# Replace second card
content = re.sub(
    r'(VStack\(alignment: \.leading, spacing: StitchSpacing\.sm\)\s*\{\s*Text\("Current Triage"\)[\s\S]*?\}\s*)\}\s*\.padding\(\)\s*\.frame\(maxWidth: \.infinity, alignment: \.leading\)\s*\.background\(Color\(\.secondarySystemBackground\)\)\s*\.cornerRadius\(12\)',
    r'StitchCard {\n                        \1}\n                    }',
    content
)

# Replace Start Consultation button
content = re.sub(
    r'(\}\s*)\.foregroundColor\(\.white\)\s*\.frame\(maxWidth: \.infinity\)\s*\.padding\(\)\s*\.background\(Color\.blue\)\s*\.cornerRadius\(12\)',
    r'\1.buttonStyle(StitchPrimaryButtonStyle())',
    content
)

with open(filepath, 'w') as f:
    f.write(content)
