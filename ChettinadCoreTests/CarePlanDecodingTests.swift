import XCTest
@testable import ChettinadCore

final class CarePlanDecodingTests: XCTestCase {
    
    func testMeasurementTaskDecoding() throws {
        let json = """
        {
            "id": "cpt-1",
            "series_id": "series-1",
            "revision": 1,
            "plan_id": "cp-1",
            "supersedes_task_id": null,
            "task_type": "MEASUREMENT",
            "title": "Fasting Blood Sugar",
            "instruction": "Before breakfast",
            "observation_type": "FASTING_GLUCOSE",
            "timing_relation": "FASTING",
            "target_unit": "mg/dL",
            "prescription_item_id": null,
            "frequency_type": "DAILY",
            "scheduled_time": "08:00",
            "start_date": "2026-09-20",
            "end_date": null,
            "expected_duration_minutes": null,
            "window_before_minutes": 60,
            "window_after_minutes": 120,
            "status": "ACTIVE",
            "drug_name": null,
            "dose": null,
            "frequency": null,
            "outdated": null
        }
        """
        
        let decoder = JSONDecoder()
        let task = try decoder.decode(CarePlanTaskDTO.self, from: json.data(using: .utf8)!)
        
        XCTAssertEqual(task.task_type, .MEASUREMENT)
        XCTAssertEqual(task.observation_type, "FASTING_GLUCOSE")
        XCTAssertEqual(task.target_unit, "mg/dL")
    }
    
    func testTodayAdherenceDecoding() throws {
        let json = """
        {
            "id": "occ-1",
            "task_id": "cpt-2",
            "plan_id": "cp-1",
            "series_id": "series-2",
            "revision": 1,
            "task_type": "ACTIVITY",
            "title": "Morning Walk",
            "description": "Walk for 30 minutes",
            "instruction": "Walk for 30 minutes",
            "target_metric": null,
            "observation_type": null,
            "timing_relation": null,
            "target_unit": null,
            "occurrence_date": "2026-09-21",
            "due_date": "2026-09-21",
            "due_time": "08:30",
            "scheduled_for": "2026-09-21T08:30:00Z",
            "status": "COMPLETED",
            "response_status": "COMPLETED",
            "completed_at": "2026-09-21T08:45:00Z",
            "recorded_at": "2026-09-21T08:45:00Z",
            "recorded_value": null,
            "patient_note": null,
            "__v": 1,
            "observation": null,
            "medication_source": null
        }
        """
        
        let decoder = JSONDecoder()
        let occ = try decoder.decode(CarePlanOccurrenceDTO.self, from: json.data(using: .utf8)!)
        
        XCTAssertEqual(occ.status, .COMPLETED)
        XCTAssertEqual(occ.task_type, .ACTIVITY)
        XCTAssertEqual(occ.task_id, "cpt-2")
    }

    func testPostgresNumericObservationDecoding() throws {
        let json = """
        {"id":"obs-1","adherence_id":"response-1","observation_type":"GLUCOSE","timing_relation":"FASTING","observed_at":"2026-09-21T03:00:00Z","recorded_at":"2026-09-21T03:01:00Z","components":[{"component_code":"GLUCOSE","numeric_value":"105.0000","unit":"mg/dL"}]}
        """
        let observation = try JSONDecoder().decode(PatientObservation.self, from: Data(json.utf8))
        XCTAssertEqual(observation.components?.first?.numeric_value, 105)
    }
    func testReminderPolicyHonorsBooleanAndSQLiteFlagsAndOnlyTheActivePlan() throws {
        let data = Data("""
        {"plan":{"id":"plan"},"tasks":[
          {"id":"disabled","plan_id":"plan","status":"ACTIVE","reminder_enabled":0},
          {"id":"numeric","plan_id":"plan","status":"ACTIVE","reminder_enabled":1},
          {"id":"boolean","plan_id":"plan","status":"ACTIVE","reminder_enabled":true},
          {"id":"stopped","plan_id":"plan","status":"INACTIVE","reminder_enabled":1},
          {"id":"old-plan","plan_id":"old","status":"ACTIVE","reminder_enabled":1},
          {"id":"missing-policy","plan_id":"plan","status":"ACTIVE"}]}
        """.utf8)
        let policy = try JSONDecoder().decode(CarePlanReminderPolicy.self, from: data)
        let ids = ["disabled","numeric","boolean","stopped","old-plan","missing-policy"]
        let occurrences = try ids.map { try occurrence(taskId:$0) }
        XCTAssertEqual(policy.eligible(occurrences).map(\.task_id), ["numeric","boolean"])
        let empty = try JSONDecoder().decode(CarePlanReminderPolicy.self, from: Data("{\"plan\":null,\"tasks\":[]}".utf8))
        XCTAssertTrue(empty.eligible(occurrences).isEmpty)
    }
    @MainActor func testReminderUsesScheduledInstantAcrossDeviceTimeZones() throws {
        let original = NSTimeZone.default
        defer { NSTimeZone.default = original }
        let now = try XCTUnwrap(ISODate.parse("2026-10-16T03:30:00Z"))
        let task = try occurrence(taskId:"numeric")
        for zone in ["Asia/Kolkata","America/Los_Angeles","Pacific/Auckland"] {
            NSTimeZone.default = try XCTUnwrap(TimeZone(identifier:zone))
            XCTAssertEqual(NotificationManager.reminderDate(for:task,now:now), ISODate.parse("2026-10-16T04:30:00Z"))
        }
        XCTAssertNil(NotificationManager.reminderDate(for:task,now:now.addingTimeInterval(7200)))
    }
    private func occurrence(taskId: String) throws -> CarePlanOccurrenceDTO {
        try JSONDecoder().decode(CarePlanOccurrenceDTO.self, from: Data("""
        {"id":"\(taskId)","task_id":"\(taskId)","plan_id":"plan","series_id":"series","revision":1,"task_type":"ACTIVITY","title":"Synthetic","description":"Synthetic","instruction":"Synthetic","occurrence_date":"2026-10-16","due_date":"2026-10-16","due_time":"10:00","scheduled_for":"2026-10-16T04:30:00Z","status":"UPCOMING","__v":0}
        """.utf8))
    }

}
