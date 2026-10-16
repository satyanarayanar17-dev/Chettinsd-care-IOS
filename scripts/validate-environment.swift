import Foundation
let env = ProcessInfo.processInfo.environment
let mode = env["APP_ENV"] ?? "", value = env["CC_API_BASE_URL"] ?? ""
guard ["local","staging","production"].contains(mode), let url = URL(string:value),
      let host = url.host, !host.isEmpty, url.user == nil, url.password == nil,
      url.query == nil, url.fragment == nil, url.path.isEmpty || url.path == "/",
      url.scheme == "https" || (mode == "local" && url.scheme == "http" && ["127.0.0.1","localhost","::1"].contains(host)),
      env["CONFIGURATION"] != "Release" || mode == "production",
      env["CONFIGURATION"] != "Staging" || mode == "staging" else {
    fputs("error: Configure an explicit backend origin and matching app environment before building.\n",stderr);exit(1)
}

if mode != "local" && env["CC_PILOT_ENDPOINT_APPROVED"] != "YES" {
    fputs("error: Verify the owned pilot backend and set CC_PILOT_ENDPOINT_APPROVED=YES before distributing this build.\n",stderr);exit(1)
}
