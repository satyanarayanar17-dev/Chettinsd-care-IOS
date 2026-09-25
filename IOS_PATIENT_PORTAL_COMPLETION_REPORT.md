# Chettinad Care Patient Portal Completion Report

Date: 22 September 2026  
Pilot: Chettinad Hospital — Obstetrics & Gynaecology  
Canonical department prefix: `OBST`  
System of record: canonical PostgreSQL backend

## Status legend

- `PASS`: implemented and verified by the stated automated or inspection evidence.
- `PARTIAL`: implementation exists but an external asset or part of the requested presentation remains.
- `FAIL`: implementation or verification failed.
- `NOT TESTED`: reserved for the user’s physical-device acceptance gate.

## Pilot configuration

**OBST-ONLY PILOT: PASS**  
`OPD_OG_PILOT_ONLY` defaults to `true`. Directory, appointment slots and booking, queues, schedules, Care Plans, dashboards, and staff provisioning apply the server-side pilot restriction. The retained multi-department acceptance suite explicitly sets the flag to `false` only inside its isolated test database.

**NON-OBST DEPARTMENTS REMOVED FROM PILOT UI: PASS**  
Web and native patient booking start at Doctor selection. Admin staff and schedule forms show Obstetrics & Gynaecology as fixed context. Cross-department cards, selectors, and catalogue creation are removed from the active pilot UI.

**NON-OBST PILOT DATA CLEANUP: PASS**  
Nine unreferenced non-OBST department rows were removed from the local pilot dataset after dependent records were checked. The `departments` table, foreign keys, and multi-department schema remain. Twenty-seven historical non-OBST clinician accounts were retained for audit safety, made inactive, and had active refresh access revoked. No clinical history was cascade-deleted.

**ONLY OBST DOCTORS: PASS**  
The active local directory contains Dr. Prabha S. and Dr. Sailatha Ramanujam, both assigned to Obstetrics & Gynaecology. Server-side directory, slots, and booking filters prevent a non-OBST Doctor from entering the pilot workflow.

**ONLY OBST STAFF CREATION: PASS**  
Admin provisioning resolves the current department to Obstetrics & Gynaecology. The backend rejects active staff creation for another department while the pilot flag is enabled.

**OBST APPOINTMENT DIRECTORY: PASS**  
The local dataset has persisted Monday-Saturday schedules for both active OBST Doctors, 09:00-17:00, 15-minute slots, with a 13:00-14:00 break. Live slot retrieval returned persisted availability.

## Patient experience

**PATIENT HOME: PASS**  
The native and web Home screens center on “What do I need to do next?” and show the next appointment, next Care Plan task, appointment booking, report upload, measurement entry, latest prescription, recent upload, reminder, and follow-up context.

**APPOINTMENT BOOKING: PASS**  
Native and web flows use the canonical directory, slot, and appointment endpoints. The patient chooses an OBST Doctor, date, server-returned slot, reason, and confirms the appointment. No Doctor or slot fixtures are embedded in either client.

**SLOT RETRIEVAL: PASS**  
Slots come from `/api/v1/opd/slots` and persisted `practitioner_schedules`. The backend validates Doctor and department against the OBST pilot.

**APPOINTMENT PERSISTENCE: PASS**  
Booking posts to `/api/v1/opd/appointments`, persists to the backend database, and refreshes Upcoming/Past lists. Automated API acceptance passes; the visible physical-device flow remains part of user acceptance.

## Patient documents

**RECORD UPLOAD: PASS**  
Patient-owned multipart upload, metadata persistence, private byte storage, authenticated list, and authenticated preview are implemented. File bytes are not stored in consultation or Care Plan JSON, and filesystem paths/storage keys are not returned to clients.

**PDF: PASS**  
PDF extension, MIME type, size limit, and `%PDF-` magic bytes are validated.

**IMAGE: PASS**  
JPEG and PNG are supported with MIME and magic-byte validation.

**DOCUMENT METADATA: PASS**  
Stored metadata includes patient, type, title, original filename, MIME type, byte size, report date, optional note, optional appointment, uploader, and timestamps.

**APPOINTMENT LINK: PASS**  
A patient can associate a document during upload, attach an already-uploaded document to one of their appointments, change the association, or remove the association. Ownership is validated on every mutation. Doctor, Nurse, and Admin cannot change a patient’s attachment.

**DOCTOR DOCUMENT VISIBILITY: PASS**  
Doctor and Nurse document list/content access uses existing `patientAccess`. Another patient is denied and Admin has no blanket clinical document access. Web and native Staff dossier views show title, type, report date, uploaded date/context, appointment association, and authenticated open/preview.

## Care Plan and patient self-recording

**CARE PLAN: PASS**  
Native Patient, native Staff, and web clients use the implemented Care Plan API and persisted PostgreSQL-compatible model.

**DOCTOR-ASSIGNED TASKS: PASS**  
Doctor remains authoritative for medication, insulin, monitoring prescriptions, prescribed activities, and material Care Plan changes. Patient may record completion or skipped state but cannot create or alter treatment instructions. Nurse access remains read/support-only under backend policy.

**SELF-RECORDED GLUCOSE: PASS**  
Patient entry supports Fasting, Before breakfast, After breakfast, Before lunch, After lunch, Before dinner, Post dinner, Bedtime, and Random. Numeric value, unit, timestamp, and optional note are persisted without clinical interpretation.

**SELF-RECORDED ACTIVITY: PASS**  
Patient can persist an activity name, duration, observed time, and optional note without consumer-fitness scoring.

**PROVENANCE DISTINCTION: PASS**  
Self-entered observations are persisted as `PATIENT_SELF_RECORDED` and displayed as “Patient self-recorded.” They are visually and contractually separate from Doctor-assigned Care Plan tasks.

## Web roles

**WEB PATIENT: PASS**  
Home, OBST appointment booking, Upcoming/Past lists, document upload/preview/appointment attachment, Care Plan, self-recording, and record history are connected to canonical endpoints.

**WEB DOCTOR: PASS**  
OBST command center, assigned queue, patient dossier, Care Plan, patient measurements/activity, uploaded records, consultation, and follow-up appointment workflow are retained and connected. The empty queue state uses the requested OBST wording.

**WEB NURSE: PASS**  
OBST triage, authorized patient access, Care Plan adherence visibility, patient observations, and uploaded records are connected. Nurse cannot author Doctor-authoritative treatment instructions.

**WEB ADMIN: PASS**  
Admin can provision and manage active OBST staff and schedules without cross-department pilot controls. Admin has no Care Plan or uploaded clinical-document access.

## Branding and design

**LOGO: PARTIAL — OFFICIAL LOGO ASSET REQUIRED**  
No approved Chettinad institutional logo asset exists in the supplied web or iOS repositories. Named asset slots are present. A neutral `LOGO` placeholder is shown and no logo was invented.

**BRANDING: PARTIAL**  
Patient iOS, Staff iOS, and web share institutional colors, typography, cards, spacing, navigation, loading/error states, and clinical empty states. Final institutional branding remains dependent on the official logo asset.

## Physical-device readiness

**PATIENT PHYSICAL BUILD: PASS**  
`ChettinadCarePatient` compiles for `generic/platform=iOS` arm64 with `CODE_SIGN_STYLE=Automatic`. The verification build disabled signing because no Apple Development Team is stored in the project. Signed installation and physical UI behavior are `NOT TESTED`.

**STAFF PHYSICAL BUILD: PASS**  
`ChettinadCareStaff` compiles for `generic/platform=iOS` arm64 with `CODE_SIGN_STYLE=Automatic`. Doctor, Nurse, and Admin role login/routing compile in the Staff target. Signed installation and physical UI behavior are `NOT TESTED`.

**PHYSICAL DEVICE BACKEND CONNECTIVITY: NOT TESTED**  
Both packaged Debug apps contain `CC_API_BASE_URL = http://Sids-MacBook-Pro.local:3001`, a local-network usage description, and local HTTP transport configuration. The local backend listens on port 3001 and reports ready. Actual mDNS/Wi-Fi reachability from “iPhone (2)” must be confirmed by the user.

## Data and test evidence

**POSTGRESQL: PASS**  
Migration `015_patient_documents_and_self_records` and the patient portal acceptance suite pass against an isolated PostgreSQL database. The test proves patient self-record persistence, PDF upload, private content access, attach/detach persistence, Doctor/Nurse authorized visibility, other-patient denial, and Admin denial. The isolated database was dropped after the run.

**MOCK CLINICAL DATA: PASS**  
No fake queue patients, appointments, readings, or clinician activity were added to make the UI look populated. Automated test fixtures are created only in isolated temporary databases. Historical non-OBST local accounts remain inactive and cannot enter pilot workflows.

### Automated verification

| Verification | Result |
| --- | --- |
| `npm run test:patient-portal` on SQLite | PASS |
| Isolated PostgreSQL patient portal suite | PASS |
| `npm run test:care-plan` | PASS |
| Isolated PostgreSQL `npm run test:og-pilot` | PASS |
| `npm run test:opd` retained multi-department architecture | PASS — 9 acceptance groups |
| Backend TypeScript typecheck | PASS |
| Web production build | PASS — chunk-size advisory only |
| Patient generic iOS hardware build | PASS |
| Staff generic iOS hardware build | PASS |
| Live local `/api/v1/health` | PASS — ready, migration 015, clean integrity |
| Simulator UI acceptance | NOT TESTED — intentionally excluded |
| Physical iPhone UI acceptance | NOT TESTED — assigned to user |

## Files modified

Principal completion files are listed below. Existing Care Plan work in the same working trees is preserved.

### Backend and web

- `backend/migrations/015_patient_documents_and_self_records.js`
- `backend/migrations/index.js`
- `backend/database.js`
- `backend/config.js`
- `backend/server.js`
- `backend/lib/patientDocumentStorage.js`
- `backend/routes/patient_documents.js`
- `backend/routes/patient_self_records.js`
- `backend/opd/patient-portal.test.cjs`
- `backend/opd/og-pilot.test.cjs`
- `backend/opd/acceptance.cjs`
- `backend/package.json`
- `backend/package-lock.json`
- `.gitignore`
- `src/opd/App.tsx`
- `src/opd/admin.tsx`
- `src/opd/booking.tsx`
- `src/opd/carePlan.tsx`
- `src/opd/i18n.tsx`
- `src/opd/operations.tsx`
- `src/opd/records.tsx`
- `src/opd/styles.css`
- `src/opd/ui.tsx`
- `src/opd/workspace.tsx`

### Native iOS

- `project.yml`
- `ChettinadCarePatient/Info.plist`
- `ChettinadCareStaff/Info.plist`
- `ChettinadCare-iOS.xcodeproj/project.pbxproj`
- `ChettinadCore/Models/OPDModels.swift`
- `ChettinadCore/Networking/APIClient.swift`
- `ChettinadCore/Networking/EnvironmentConfig.swift`
- `ChettinadCore/Networking/PatientPortalEndpoints.swift`
- `ChettinadCore/DesignSystem/StitchComponents.swift`
- `ChettinadCarePatient/Features/MainTabView.swift`
- `ChettinadCarePatient/Features/PatientViewModel.swift`
- `ChettinadCarePatient/Features/PatientViews.swift`
- `ChettinadCarePatient/Features/PatientCarePlanView.swift`
- `ChettinadCarePatient/Features/CarePlanViewModel.swift`
- `ChettinadCarePatient/Features/SelfRecordSheet.swift`
- `ChettinadCareStaff/Features/StaffMainView.swift`
- `ChettinadCareStaff/Features/StaffLoginView.swift`
- `ChettinadCareStaff/Features/SideTabsView.swift`
- `ChettinadCareStaff/Features/PatientCarePlanMonitoringView.swift`
- related existing Doctor, Nurse, Admin, design-system, and test files shown by Git status

No Android repository was modified. No commit, push, reset, or simulator UI run was performed.

## Remaining blockers

1. `OFFICIAL LOGO ASSET REQUIRED`: supply the approved logo in the named iOS/web asset slots.
2. Select the organization’s Apple Development Team in Xcode so automatic signing can install both apps on “iPhone (2)”.
3. Run the requested physical Patient-to-Staff workflow and report any visible or device-network defects with screenshots.
4. Replace the local `.local:3001` development endpoint with the hosted API when production infrastructure is available.

## User physical acceptance sequence

1. Patient login, Home, and OBST-only navigation.
2. Book an appointment using a returned Doctor/date/slot and confirm it persists under Upcoming.
3. Upload a PDF and an image; attach, change, and remove an appointment association; reopen both files.
4. View Doctor-assigned Care Plan tasks, record completion/skipped state, add glucose, and add activity.
5. Relaunch the Patient app and confirm persistence.
6. Sign in to Staff as Doctor and Nurse; verify the same appointment, documents, Care Plan, readings, and activity.
7. Verify Doctor consultation close/follow-up can schedule the next appointment.

PATIENT PORTAL READY FOR USER PHYSICAL ACCEPTANCE: YES

FINAL COMPLETION PASS

CODE IMPLEMENTATION: PASS
OBST PILOT: PASS
PATIENT FRONTEND: PASS
APPOINTMENT BOOKING: PASS
RECORDS: PASS
CARE PLAN: PASS
SELF RECORDING: PASS
STAFF VISIBILITY: PASS
WEB CONSISTENCY: PASS
POSTGRESQL: PASS
PHYSICAL DEVICE BUILD PREPARATION: PASS
SIGNING CONFIGURATION: PARTIAL
LOCAL NETWORK CONFIGURATION: PASS
OFFICIAL LOGO: PARTIAL

USER PHYSICAL ACCEPTANCE: NOT TESTED
PATIENT INSTALL: NOT TESTED
PATIENT LOGIN: NOT TESTED
APPOINTMENT FLOW: NOT TESTED
DOCUMENT FLOW: NOT TESTED
CARE PLAN FLOW: NOT TESTED
SELF-RECORD FLOW: NOT TESTED
RELAUNCH PERSISTENCE: NOT TESTED
STAFF INSTALL: NOT TESTED
STAFF CROSS-VISIBILITY: NOT TESTED

REMAINING BLOCKERS:
1. OFFICIAL LOGO ASSET REQUIRED: supply the approved logo in the named iOS/web asset slots.
2. Select the organization’s Apple Development Team in Xcode so automatic signing can install both apps on “iPhone (2)”.
3. Run the requested physical Patient-to-Staff workflow and report any visible or device-network defects with screenshots.
4. Replace the local `.local:3001` development endpoint with the hosted API when production infrastructure is available.
