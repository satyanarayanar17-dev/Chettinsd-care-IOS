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

def process_file(filepath):
    with open(filepath, 'r') as f:
        lines = f.readlines()
        
    # We want to replace `VStack(spacing: 0) {` or `VStack(...) {` when it is followed somewhere down by `.background(...) \n .cornerRadius(12)`
    # This is a bit tricky. Let's just use a state machine.
    
    # Actually, a simpler regex over the whole content is possible if we use recursive matching or we just use `swift-format`? No.
    # Let's do it by doing it manually via SED for specific cases or we can write a simple parser.
    content = "".join(lines)
    
    # Let's find all occurrences of `.background(Color(UIColor.secondarySystemGroupedBackground))` and `.cornerRadius(12)`
    # We can use regex to find `VStack(...) { ... } .background(...) .cornerRadius(...)`
    # But because of nesting, it's easier to find the `.background(...)` and `.cornerRadius(...)` and remove them, and wrap the VStack.
    pass

for filename in files_to_process:
    filepath = os.path.join(base_dir, filename)
    if os.path.exists(filepath):
        process_file(filepath)
