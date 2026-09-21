#!/bin/bash

# A script to run all tests and format the output

echo "Waiting for simulator to be available..."
while ! xcrun simctl list runtimes | grep -q 'iOS'; do
    sleep 5
done

# Boot the simulator
SIM_ID=$(xcrun simctl list devices available | grep -v '==' | head -n 1 | awk -F '[()]' '{print $2}')
xcrun simctl boot "$SIM_ID"

echo "Running ChettinadCoreTests"
xcodebuild test -project ChettinadCare-iOS.xcodeproj -scheme ChettinadCoreTests -destination "id=$SIM_ID" | tee core_tests.log
echo "Running ChettinadCarePatientTests"
xcodebuild test -project ChettinadCare-iOS.xcodeproj -scheme ChettinadCarePatientTests -destination "id=$SIM_ID" | tee patient_tests.log
echo "Running ChettinadCareStaffTests"
xcodebuild test -project ChettinadCare-iOS.xcodeproj -scheme ChettinadCareStaffTests -destination "id=$SIM_ID" | tee staff_tests.log

