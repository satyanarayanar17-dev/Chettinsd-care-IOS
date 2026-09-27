import re

filepath = '/Users/siddwork/Desktop/ChettinadCare-iOS/ChettinadCarePatient/Features/PatientViews.swift'
with open(filepath, 'r') as f:
    content = f.read()

content = re.sub(
r'Text\("Your uploaded reports, scans and PDFs will appear here\."\)\.font\(Typography\.bodyLarge\)\.foregroundStyle\(Color\.chettinadTextSecondary\)',
r'StitchEmptyState(icon: "doc.text", title: "No Documents", message: "Your uploaded reports, scans and PDFs will appear here.")',
content)

with open(filepath, 'w') as f:
    f.write(content)
