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
}
