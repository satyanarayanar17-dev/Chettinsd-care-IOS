import re

def fix_cards_in_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()
    
    # 1. Match VStack {...} \n .padding() \n .background(...) \n .cornerRadius(12) \n .padding(.horizontal)
    
    # Actually it's easier to manually do it with regex or sed. Let's just do a string replace since I know the exact code blocks.
    
    with open(filepath, 'w') as f:
        f.write(content)

fix_cards_in_file('/Users/siddwork/Desktop/ChettinadCare-iOS/ChettinadCarePatient/Features/PatientCarePlanView.swift')
