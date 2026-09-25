# iOS Care Plan Final Audit

Audit date: 2026-09-22 (Asia/Kolkata)  
Native project: `/Users/siddwork/Desktop/ChettinadCare-iOS`  
Backend project: `/Users/siddwork/Desktop/chettinad-care-frontend/backend`  
Simulator: iPhone 18 Pro, iOS 27.0, `6452510D-6534-415E-AC1B-9DFE324B30CD`

## Final status

The code, contracts, builds, installed applications, unit tests, backend RBAC, refresh behavior, optimistic locking, and PostgreSQL persistence have been verified. The user elected to perform the remaining live Patient and Staff UI workflow manually. Native UI acceptance and the native same-database proof therefore remain incomplete, so the final verdict is `NO`.

| Required result | Status | Evidence |
|---|---|---|
| BACKEND POSTGRESQL | PASS | `/api/v1/health` reported `db: postgres`, `db_status: ok`, integrity `clean`. |
| 14/14 MIGRATIONS | PASS | Health reported 14 applied, 14 expected, latest `014_care_plans`, up to date. |
| PATIENT BUILD | PASS | XcodeBuildMCP `build_sim` succeeded for `ChettinadCarePatient` on the specified simulator. |
| STAFF BUILD | PASS | XcodeBuildMCP `build_sim` succeeded for `ChettinadCareStaff` on the specified simulator. |
| PATIENT INSTALL | PASS | Final Patient bundle installed successfully. |
| STAFF INSTALL | PASS | Final Staff bundle installed successfully. |
| BOTH APPS COEXIST | PASS | `simctl listapps` showed `com.chettinadcare.patient` and `com.chettinadcare.staff` installed simultaneously. |
| SESSION | PARTIAL | Real `/opd/session` returned authoritative `patient_id: ios-patient` and numeric `must_change_password: 0`; native decoding passed. Full live UI session check is deferred to the user. |
| TOKEN REFRESH | PASS | Real refresh rotated the access token, the refreshed token retrieved all six tasks, revoked-token replay returned 401, and iOS tests cover single-flight, structured 401 retry, one retry only, and failed-refresh clearing. |
| LOGOUT | PARTIAL | Real backend logout returned 200 and refresh afterward returned 401 `REFRESH_REVOKED`; native code calls backend logout and clears Keychain/cookies. The live logout button was not exercised. |
| SESSION RESTORE | NOT TESTED | The user will perform terminate/relaunch verification during the live run. |
| CARE PLAN TODAY | PARTIAL | Actual flat Today payload decoded, compiled, and was exercised through the real PostgreSQL API. Native screen execution is deferred to the user. |
| NEXT ACTION | PARTIAL | Native view selects the first `DUE` or `UPCOMING` task from backend data; visual/live selection is deferred. |
| GLUCOSE | PARTIAL | Three real PostgreSQL observations were persisted and returned, including notes and units. Native sheet execution is deferred. |
| ACTIVITY | PARTIAL | `Morning Walk` persisted as `COMPLETED` and was visible to Doctor/Nurse APIs. Native tap/reload is deferred. |
| MEDICATION | PARTIAL | Prescription-linked task persisted `TAKEN`; `SKIPPED` was accepted and then restored to `TAKEN`. UI is read-only for drug/dose/frequency. Native menu execution is deferred. |
| INSULIN | PARTIAL | Prescription-linked 4-unit task persisted `TAKEN`; `SKIPPED` was accepted and restored. No dose calculation or glucose interpretation exists. Native menu execution is deferred. |
| TIMELINE | PARTIAL | Real timeline returned all six persisted task rows; Patient and Staff views consume that endpoint. Native timeline rendering is deferred. |
| DOCTOR VISIBILITY | PARTIAL | Real Doctor API retrieved six tasks and the native dossier embeds the read-only monitoring view. Live Staff navigation is deferred. |
| NURSE VISIBILITY | PARTIAL | Real Nurse API retrieved six persisted results, direct Nurse mutation returned 403, and the native Nurse path is read-only. Live navigation is deferred. |
| ADMIN ISOLATION | PASS | No Admin Care Plan route exists in native Admin UI and direct Admin adherence read returned 403. |
| 409 STALE_STATE | PARTIAL | Real stale write returned HTTP 409 `STALE_STATE`; iOS handles it with a safe message and refetches Today and timeline. Live conflict display is deferred. |
| CORE TESTS | PASS | 11 executed: 10 passed, 0 failed, 1 skipped. |
| PATIENT TESTS | PASS | 12 executed by Patient scheme: 11 passed, 0 failed, 1 skipped. |
| STAFF TESTS | PASS | 16 executed by Staff scheme: 15 passed, 0 failed, 1 skipped. |
| NETWORKING TESTS | PASS | Refresh and error-contract tests passed, including raw/structured 401 handling and retry behavior. |
| CARE PLAN TESTS | PASS | Flat Today DTO, task DTO, and PostgreSQL numeric observation decoding tests passed. |
| SAME POSTGRESQL PROOF | PARTIAL | The same PostgreSQL patient/task/response rows were retrieved by Patient, Doctor, and Nurse API identities. The writes were made through the canonical API verification script, not the Patient iOS UI, so the required native proof remains open. |
| MOCK CLINICAL DATA REMAINING | PASS | No hardcoded runtime Care Plan values, medication names, insulin doses, patient IDs, task rows, or timeline rows were found. Synthetic values exist only in test/acceptance fixtures outside production UI flow. |
| RUNTIME CRASHES | PARTIAL | No crash occurred during build/test or the initial Patient launch. The full live Care Plan workflow is deferred. |
| SWIFT WARNINGS | PASS | No Swift compiler warnings remained. Xcode emitted one informational App Intents metadata warning per app because neither target links AppIntents. |
| VISUAL QA | PARTIAL | Login launch showed correct safe-area layout without clipping. Care Plan hierarchy and states were code-audited; live Care Plan, keyboard, sheet, timeline, and Staff visual checks are deferred. |
| FILES MODIFIED BY CODEX | PASS | Listed below. No backend source was changed. |
| FAILED TESTS | PASS | Zero failed tests in Core, Patient, and Staff schemes. |
| REMAINING BLOCKERS | PARTIAL | User-run native workflow, session restore, live Staff visibility, live stale-state presentation, and full visual QA remain. |

## Backend gate

Final health checks returned:

```text
db = postgres
db_status = ok
ready = true
migrations = 14/14
latest = 014_care_plans
integrity = clean
```

Acceptance used an isolated PostgreSQL database on the existing local backend process. No backend source, migration, React, or Android file was modified.

## Pre-edit iOS diff inspection

The required pre-edit `git status --short`, `git diff --stat`, and `git diff` were captured before corrections. Antigravity's Care Plan work was preserved. Relevant changes found were:

- Core: new `CarePlanModels.swift` and `CarePlanEndpoints.swift`; changes to `OPDModels`, `APIClient`, `APIError`, `EnvironmentConfig`, session/authentication behavior, and design-system resources.
- Patient: new `CarePlanViewModel.swift` and `PatientCarePlanView.swift`; Care Plan added to `MainTabView`; session-backed patient record loading; login and app-state changes.
- Staff: new `PatientCarePlanMonitoringView.swift`; Doctor dossier integration; Nurse triage integration; staff navigation/session changes.
- Tests: new Care Plan decoding coverage and changes to Core integration, PostgreSQL proof, Staff contract, and refresh tests.
- Project: Patient, Staff, and Core schemes remain usable; Care Plan sources are included by the Xcode project generated from `project.yml`.
- Other Antigravity work remains in the working tree, including unrelated Admin/design changes, scratch patch scripts, logs, and the earlier `IOS_CARE_PLAN_ACCEPTANCE_REPORT.md`. None was reset or discarded.

## Contract audit and corrections

The original native Today model expected a nested `task/current_status/existing_response` shape. The canonical backend returns a flat occurrence DTO. That mismatch would have caused real Today decoding to fail even though the original fixture mirrored the incorrect native model.

The corrected native contract now matches these actual fields:

```text
id, task_id, plan_id, series_id, revision,
task_type, title, description, instruction,
target_metric, observation_type, timing_relation, target_unit,
occurrence_date, due_date, due_time, scheduled_for,
status, response_status, completed_at, recorded_at,
recorded_value, patient_note, __v,
observation, medication_source
```

Canonical native task types are exactly:

```text
MEASUREMENT
ACTIVITY
MEDICATION
INSULIN
```

No Care Plan code uses `READING`. Patient mutations send:

- `RECORDED` for measurement.
- `COMPLETED` for activity.
- `TAKEN` or `SKIPPED` for medication and insulin.

PostgreSQL `NUMERIC` values may arrive as JSON strings. Observation components and flat `recorded_value` now decode either a JSON number or numeric string without changing the stored clinical meaning.

## Patient session and authentication

The real session response was:

```json
{
  "id": "ios-patient-user",
  "name": "Synthetic iOS Patient",
  "role": "PATIENT",
  "department": null,
  "patient_id": "ios-patient",
  "must_change_password": 0
}
```

`UserSession` uses `FlexibleBool`, so numeric and Boolean representations decode. `CarePlanViewModel` requests `/api/v1/opd/session` and uses its `patient_id`; it does not derive or hardcode a patient identifier.

`SessionManager` restores `AuthSession` from Keychain, calls `/api/v1/auth/logout`, then clears the in-memory session, Keychain item, and cookies. Patient and Staff have different bundle/application Keychain access groups, so the shared service/account names do not prevent both apps from coexisting.

## Refresh verification

The native request path is:

```text
401 from protected endpoint
→ APIError.isUnauthorized for raw or structured response
→ SessionManager single-flight refresh
→ save rotated access token
→ retry original request once
```

Verified behavior:

- Three concurrent protected requests caused one refresh and three successful retries in the unit test.
- A structured backend 401 caused one refresh and one successful original-request retry.
- A failed refresh cleared the session and did not retry indefinitely.
- A real backend refresh produced a different access token.
- The new token loaded all six Today tasks.
- Reuse of the old refresh credential returned 401.
- Real logout revoked the refresh session; refresh afterward returned 401 `REFRESH_REVOKED`.

## Patient UI behavior from code

The Patient screen includes:

- loading, empty, error, and retry states;
- Daily Progress;
- the next `DUE` or `UPCOMING` action;
- all five derived occurrence states: `UPCOMING`, `DUE`, `COMPLETED`, `MISSED`, and `SKIPPED`;
- measurement sheet with numeric value, backend unit, and optional note;
- activity completion;
- medication/insulin `Mark Taken` and `Skip` actions;
- persisted values returned from Today;
- Recent Activity sourced from the timeline endpoint.

The UI contains no diagnosis, threshold classification, insulin calculation, dose recommendation, or medication editing control.

## Staff and RBAC audit

Doctor access is wired through `PatientDossierView`. Nurse access is wired from the assigned queue patient's triage form. Both use `PatientCarePlanMonitoringView`, which exposes no task create, replace, deactivate, medication change, insulin change, activity prescription, or measurement prescription action.

Actual backend authorization results were:

```text
Doctor GET Today: 200, 6 tasks
Nurse GET timeline: 200, 6 persisted results
Nurse POST adherence mutation: 403
Admin GET Today: 403
```

No Care Plan access path was added to the Admin native views.

## Optimistic locking

A measurement response was created at version 1 and successfully corrected to version 2. A second update using the stale version 1 returned:

```text
HTTP 409
STALE_STATE
```

The Patient view model does not overwrite local data on this response. It displays a recoverable message and refetches both Today and timeline. A generic mutation failure uses safe copy rather than raw backend JSON.

## PostgreSQL persistence evidence

All data below are synthetic.

```text
patient_id: ios-patient
care_plan_id: ios-plan
prescription_id: ios-rx
```

| Task | Task type | Response | Final state/version | Observation/value | Prescription item |
|---|---|---|---|---|---|
| `ios-task-before-dinner` | MEASUREMENT | `care-response-f87995d6-6bf2-4fb5-b16f-1a66bf67d0c8` | RECORDED / 1 | `observation-c232cd2d-e3ae-4e11-afcc-ba923a6b5ab9`, 104 mg/dL | — |
| `ios-task-fasting` | MEASUREMENT | `care-response-56c19c09-3fa8-4c9b-91ae-871d48afa126` | RECORDED / 2 | `observation-de961b1b-7d45-424f-8322-f06bbf85e7fc`, 97 mg/dL | — |
| `ios-task-post-dinner` | MEASUREMENT | `care-response-5e7a9394-e447-423f-bc99-6dade8019441` | RECORDED / 1 | `observation-6b40812c-049c-4d2d-be66-1a220b3b38dd`, 132 mg/dL | — |
| `ios-task-walk` | ACTIVITY | `care-response-b16b74b1-0e08-4593-b96c-e6b5864ec9fb` | COMPLETED / 1 | — | — |
| `ios-task-medication` | MEDICATION | `care-response-6e09a839-469e-4451-b724-7e1a689911e6` | TAKEN / 3 | — | `rxitem-4a9070e0-935b-41e5-8a3b-013dda722f2a` |
| `ios-task-insulin` | INSULIN | `care-response-34232af7-f9c1-48b0-ab1d-7b76d29e4d79` | TAKEN / 3 | — | `rxitem-20286708-c6da-4b68-8d10-faedbadbd9be` |

Medication and insulin were each changed to `SKIPPED` through the canonical Patient API and then restored to `TAKEN`, proving both allowed states and version increments. Doctor and Nurse identities retrieved the same PostgreSQL-backed results. This proves the backend half of the acceptance chain; it is not represented as native proof because the Patient UI did not originate these writes.

## Build, schemes, install, and warnings

Usable schemes:

```text
ChettinadCarePatient
ChettinadCareStaff
ChettinadCore
```

Final build results:

```text
ChettinadCarePatient: BUILD SUCCEEDED
ChettinadCareStaff: BUILD SUCCEEDED
```

Final installed bundle IDs on the same simulator:

```text
com.chettinadcare.patient
com.chettinadcare.staff
```

No Swift warnings remained. Each app emitted this Xcode metadata notice:

```text
Metadata extraction skipped, no AppIntents.framework dependency found
```

This does not affect runtime or Care Plan behavior.

## Test results

The one skipped test in every scheme is `SamePostgreSQLProofTests.testSamePostgreSQLProof`. It deliberately requires the separate disposable fixture at `http://127.0.0.1:3011`; the verified backend for this pass was the required PostgreSQL instance at port 3001. It was skipped, not failed.

| Suite/scheme | Executed | Passed | Failed | Skipped |
|---|---:|---:|---:|---:|
| Core scheme | 11 | 10 | 0 | 1 |
| Patient scheme | 12 | 11 | 0 | 1 |
| Staff scheme | 16 | 15 | 0 | 1 |
| Token/session tests within Core | 5 | 5 | 0 | 0 |
| Care Plan decoding tests within Core | 3 | 3 | 0 | 0 |
| Backend health/role integration tests within Core | 2 | 2 | 0 | 0 |
| Disposable port-3011 PostgreSQL proof | 1 | 0 | 0 | 1 |

The external canonical API/PostgreSQL proof completed successfully on port 3001 and covered six task writes, timeline retrieval, Doctor/Nurse reads, Nurse/Admin rejection, refresh rotation, logout revocation, skip/taken transitions, and stale-state rejection.

## Mock-data audit

Runtime source was searched for glucose values, units, medication names, insulin doses, Care Plan tasks, patient/encounter IDs, queue fixtures, timeline entries, mock/sample/demo markers, and common clinical values. No hardcoded Care Plan or Staff clinical record can enter the production runtime flow. Example values in field placeholders are input hints, not clinical data. Synthetic clinical content is confined to tests and the isolated acceptance database.

```text
MOCK CLINICAL DATA REMAINING: NONE
```

## Visual QA

The initial Patient launch was captured and showed correct branding, hierarchy, safe-area behavior, and no clipping on the requested iPhone 18 Pro. Code inspection confirms the approved Care Plan structure: title, progress, Next Action, checklist rows, status chips, measurement sheet, and recent activity.

The live Care Plan screen, keyboard behavior, measurement sheet, long-list scrolling, completed/skipped chips, Staff monitoring view, and navigation/relaunch sequence were not visually accepted in this pass because the user chose to perform the live run and report UI bugs separately.

## Files modified by Codex

Codex made targeted native corrections or test hardening in:

```text
ChettinadCore/Models/CarePlanModels.swift
ChettinadCarePatient/Features/CarePlanViewModel.swift
ChettinadCarePatient/Features/PatientCarePlanView.swift
ChettinadCareStaff/Features/PatientCarePlanMonitoringView.swift
ChettinadCareStaff/Features/NurseTriageViews.swift
ChettinadCareStaff/Features/StaffViews.swift
ChettinadCoreTests/CarePlanDecodingTests.swift
ChettinadCoreTests/TokenRefreshTests.swift
ChettinadCoreTests/BackendIntegrationTests.swift
ChettinadCare-iOS.xcodeproj/project.pbxproj (regenerated from the existing project.yml)
```

No backend source, migration, React, Android, Git history, or remote branch was modified.

## Remaining manual native acceptance

The user-run live pass should verify this exact sequence without uninstalling either app:

```text
Patient login
→ Care Plan Today and Next Action
→ three measurement sheets and notes
→ activity COMPLETED
→ medication TAKEN and SKIPPED UI
→ insulin TAKEN and SKIPPED UI
→ timeline
→ navigate away/back
→ terminate and relaunch
→ session restored
→ Doctor and Nurse open the same persisted results
→ stale update presents recoverable copy and refetches
```

Any UI bug found in that run should be added here with a screenshot, reproduction steps, and the affected status changed from `PARTIAL` or `NOT TESTED`.

IOS CARE PLAN VERIFIED: NO
