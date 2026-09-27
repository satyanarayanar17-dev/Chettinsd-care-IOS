# Chettinad Care: Web vs iOS Parity Audit

SOURCE REVISION: Phase 4 Complete (Sep 2026)

## WEB vs IOS FEATURE MATRIX

### PATIENT IOS

- **HOME:** `PASS`. Completely rewritten to match the required "What do I need to do next?" hierarchy (Next Appointment, Today's Care Plan, Quick Actions, Recent).
- **PROFILE:** `PARTIAL`. Profile displays identity, but missing detailed notification settings.
- **APPOINTMENTS:** `PASS`. Appointment request flow exists and defaults to PENDING_CONFIRMATION.
- **RECORDS:** `PARTIAL`. Upload flow with metadata exists and matches Web behavior. However, adding pre-visit records explicitly from the Appointment detail simply redirects to the main Records tab.
- **CURRENT MEDICATIONS (Patient Reported):** `MISSING`. Missing across both Web and iOS (no backend endpoint exists for patients to self-report medications separate from clinical prescriptions).
- **CARE PLAN:** `PASS`. Daily tasks list is correctly displayed.
- **GLUCOSE:** `PASS`. Self-record entry for glucose with contextual tags.
- **GLUCOSE HISTORY:** `PASS`. Available via PatientTrendsView charts and lists.
- **MEDICATION HISTORY:** `PASS`. Available via PatientTrendsView.
- **INSULIN ADHERENCE:** `PASS`. Available via PatientTrendsView.
- **ACTIVITY:** `PASS`. Activity tracking implemented.
- **LOCAL NOTIFICATIONS:** `PASS`. `UNUserNotificationCenter` scheduling is properly implemented during `fetchTodayCarePlan` via `NotificationManager`.

### NURSE IOS

- **DASHBOARD:** `PARTIAL`. Queue exists but does not explicitly group into "Awaiting Check-in", "Awaiting Triage", "Ready for Doctor".
- **APPOINTMENT REQUESTS:** `PASS`. Shows pending appointments and allows confirmation.
- **PATIENT SEARCH:** `PASS`. Handled within the appointment/check-in flow.
- **NEW PATIENT:** `PASS`. Create Patient sheet exists.
- **RETURNING PATIENT:** `PASS`. Can check in existing patient.
- **CHECK-IN:** `PASS`.
- **TRIAGE:** `PARTIAL`. Triage form captures vitals, but submitting triage automatically advances to `WAITING_DOCTOR` without an explicit "Send to Doctor" button.
- **DOCTOR ASSIGNMENT:** `PASS`. (Implicitly handled if the appointment was already booked to a doctor).
- **SEND TO DOCTOR:** `PASS`. Triggers automatically when triage is submitted (Queue status changes to WAITING_DOCTOR).
- **CARE PLAN VISIBILITY:** `PASS`. Nurse triage screen shows `PatientCarePlanMonitoringView` with adherence and recent timeline.
- **PROFILE:** `PASS`. Staff profile exists.

### DOCTOR IOS

- **APPOINTMENT REQUESTS:** `PASS`. Queue shows pending.
- **TODAY:** `PASS`. Handled in Queue.
- **UPCOMING:** `PASS`. Handled in Queue.
- **WAITING:** `PASS`. Handled in Queue.
- **DOSSIER:** `PARTIAL`. DoctorConsultationView shows basic patient data and current triage vitals.
- **RECORDS:** `PASS`. Patient-uploaded documents are now visible in the main Dossier view and Historical Records view.
- **MEDICATIONS:** `PARTIAL`. Shows historical clinical prescriptions, but no "Patient Reported Medications".
- **CARE PLAN:** `PASS`. Doctor and Nurse can view `PatientCarePlanMonitoringView` inside the Triage / Dossier views, and Doctor can edit tasks via `DoctorCarePlanView`.
- **MEASUREMENT TRENDS:** `PASS`. Added `StaffPatientTrendsView` and linked it from `DoctorCarePlanView` allowing Staff to view adherence and charts.
- **CONSULTATION:** `PASS`. Forms exist for notes, diagnoses, prescriptions, and labs.
- **FOLLOW-UP:** `MISSING`. No specific follow-up scheduling from the consultation completion.

### WEB / IOS DATA PARITY:
- **OBST PILOT:** `PASS`. Handled via default OBST department.
- **DIABETES / CHRONIC MONITORING SUPPORT:** `PASS` (Care Plan data model is highly extensible).
- **AUTH:** `PASS`. Refresh token logic implemented correctly.
- **RBAC:** `PASS`. Patient vs Staff roles correctly enforced.
- **POSTGRESQL:** `PASS`. SQLite local equivalent used for demonstration/development.
- **DEMO ENVIRONMENT:** `PASS`. Node seeded demo environment matches expected test scenarios.

### REMAINING BLOCKERS / ACTION ITEMS:
1. **Physical Device Acceptance**: To be verified by user on iPhone (2) `00008130-0002103622F2001C`.
