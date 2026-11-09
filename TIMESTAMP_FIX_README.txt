FIXED: MATLAB / PYTHON TIMEBASE MISMATCH (2026-11-04)

Previously UnitOpsMaster.m used posixtime(datetime('now')) in four places.
MATLAB interprets a timezone-free datetime as UTC, even if 'now'
reflects the local clock. Python's time.time() is already UTC-based.
This made browser status appear MATLAB offline/stale and caused valid
browser commands and heartbeats to be dropped due to apparent age.

Changed ALL FOUR occurrences to:
    posixtime(datetime('now','TimeZone','UTC'))

The four affected places are digital connection retry timing,
student heartbeat validation, command-age validation, and station
status publication.

No changes were made to PID calculation, physical arming, ADAM mapping,
SSR logic, trip conditions, or station-code generation.

DEPLOYMENT
1. Stop MATLAB controller. Turn heater mains off/disconnect; outputs should
   be independently verified OFF before starting a new instance.
2. Close any previous Python bridge instance. E.g. inspect with PowerShell:
   Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match 'bridge\.py' } | Select ProcessId,CommandLine
3. Extract this ZIP to a NEW folder, preserving its folder structure.
4. Start MATLAB from the extracted directory with Start_UnitOps_Lab.
5. Browse to http://192.168.0.200:8088 . The student computer needs only a browser.
6. Student 6-digit codes can be read from runtime/ACCESS_CODES_FOR_INSTRUCTOR.txt
   on the master PC. Codes from a prior extraction will not automatically carry
   over into this separate folder unless its access_codes.json is copied over.
7. Verify MATLAB online freshness and simulation command delivery first.
   Commission hardware low-voltage paths separately before connecting heaters.

VERIFICATION
MATLAB was not executed in the build environment, and no ADAM/SSR
hardware was connected. Syntax and Python bridge tests are included in
build checks but physical live operation is NOT certified.
