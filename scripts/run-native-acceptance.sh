#!/bin/bash
set -euo pipefail
# Pass the reviewed backend checkout and a work directory; no existing database is touched.
backend_checkout="${1:?Backend checkout required}"
validation_work="${2:?Work directory required}"
project_root="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$validation_work"
node "$project_root/scripts/start-native-integration.cjs" "$backend_checkout" > "$validation_work/native-api.log" 2>&1 &
fixture_pid=$!
trap 'kill -TERM "$fixture_pid" 2>/dev/null || true; wait "$fixture_pid" 2>/dev/null || true' EXIT
for attempt in {1..100}; do
  if curl --silent --fail http://127.0.0.1:3011/api/v1/auth/opd/config > /dev/null; then break; fi
  sleep 0.1
done
xcodebuild build-for-testing -project "$project_root/ChettinadCare-iOS.xcodeproj" -scheme ChettinadCareStaff -configuration Debug -destination 'platform=macOS,variant=Mac Catalyst' -derivedDataPath "$validation_work/derived" -skip-testing:ChettinadCareStaffUITests DEVELOPMENT_TEAM=47797T9SLZ -allowProvisioningUpdates > "$validation_work/build.log" 2>&1
python3 - "$validation_work/derived/Build/Products" <<'PY'
import sys,plistlib
from pathlib import Path
folder=Path(sys.argv[1]);source=next(folder.glob('ChettinadCareStaff_*.xctestrun'));run=plistlib.loads(source.read_bytes())
for value in run.values():
 if isinstance(value,dict) and 'TestBundlePath' in value: value.setdefault('EnvironmentVariables',{})['CC_INTEGRATION_BASE_URL']='http://127.0.0.1:3011'
(folder/'NativeAcceptance.xctestrun').write_bytes(plistlib.dumps(run))
PY
xcodebuild test-without-building -xctestrun "$validation_work/derived/Build/Products/NativeAcceptance.xctestrun" -destination 'platform=macOS,variant=Mac Catalyst' -only-testing:ChettinadCareStaffTests -only-testing:ChettinadCoreTests/NativeRecordContractTests -only-testing:ChettinadCoreTests/TokenRefreshTests -resultBundlePath "$validation_work/NativeAcceptance.xcresult" > "$validation_work/tests.log" 2>&1
