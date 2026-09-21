#!/bin/bash
set -euo pipefail

echo "Waiting for simulator to be available..."
while ! xcrun simctl list runtimes | grep -q 'iOS'; do
    sleep 5
done

# We will use the specific iPhone 18 Pro simulator provided by the user if available, or fallback to the first one
SIM_ID=${1:-"6452510D-6534-415E-AC1B-9DFE324B30CD"}
xcrun simctl boot "$SIM_ID" || true

echo "Running ChettinadCore tests..."
xcodebuild test -project ChettinadCare-iOS.xcodeproj -scheme ChettinadCore -destination "id=$SIM_ID" | tee core_tests.log

echo "Running ChettinadCarePatient tests..."
xcodebuild test -project ChettinadCare-iOS.xcodeproj -scheme ChettinadCarePatient -destination "id=$SIM_ID" -only-testing:ChettinadCarePatientTests | tee patient_tests.log

echo "Running ChettinadCareStaff tests..."
xcodebuild test -project ChettinadCare-iOS.xcodeproj -scheme ChettinadCareStaff -destination "id=$SIM_ID" -only-testing:ChettinadCareStaffTests | tee staff_tests.log
