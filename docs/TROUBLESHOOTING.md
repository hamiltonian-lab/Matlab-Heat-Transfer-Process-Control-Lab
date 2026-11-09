# Troubleshooting

| Symptom | First check | Common cause |
|---|---|---|
| Student web page unavailable | `http://MASTER_IP:8088/api/health` on master | Wrong/busy server bind IP, bridge not running, firewall TCP/8088, wrong Wi-Fi LAN |
| `MATLAB offline / stale` | Is `runtime/stationN.json` updating? Compare UTC epoch to current time | Old Python bridge using another folder, paused MATLAB timer, timestamp mismatch, callback error |
| Live Start disabled | `engine_online`, `live_ok`, `live_setpoint_ok` | Stale state, invalid analog status, live setpoint at/above instructor trip, already running |
| ADAM-6050 connected, no SSR activation | Physical arming; live PID running; DO logic and independent low-voltage test | Small PWM ON window missed by 1 s loop, miswired sink return, input current mismatch, output unarmed |
| Incorrect temperatures | ADAM AI range code, channel status, transmitter span | Software assumed 0–150 °C when transmitter has another configuration |
| Browser is reachable but commands not applied | Same runtime folder; command inbox; UTC clock | Bridge and MATLAB versions differ, too-old queued command, callback error |
| Wi-Fi internet fails with lab Ethernet plugged in | Windows routes and Ethernet default gateway | Isolated router advertising an unnecessary internet gateway |
| Station passcodes changed | Local `runtime/access_codes.json` persistence | Extracted new copy in another folder; copied app without local runtime |
| CSV contains idle data | [Data/exports notes](DATA_EXPORTS.md) | Current exporter retains latest 400 mixed-timer samples and splits columns only |

## Low-risk diagnostic sequence

First, isolate heater mains. Run `Verify_Dual_ADAM` for read-only checks. Then verify Python server reachability, MATLAB timer/station JSON freshness, session state, station isolation and low-voltage DO behavior. Only a separately commissioned hardware system should proceed to powered heating.
