# Architecture and data flow

## Software layers

| Layer | File(s) | Responsibility |
|---|---|---|
| MATLAB instructor and control engine | `UnitOpsMaster.m` | 1 Hz-ish timer, Modbus acquisition/output, four independent station structs, FOPDT simulation, PID, safety requests, GUI, state/CSV publication |
| MATLAB launcher | `Start_UnitOps_Lab.m` | Starts the Python bridge bound to the designated Ethernet IP and constructs `UnitOpsMaster` |
| Hardware verification | `Verify_Dual_ADAM.m` | Read-only Modbus checks of four channels and DO logic states; no DO writes |
| Web transport | `bridge.py` | HTTP on TCP/8088, access codes/session cookies, station-scoped command queuing, state and CSV endpoints |
| Browser UI | `www/index.html`, `www/app.js`, `www/style.css` | Station login, simulation/live/tuning tabs, plots, CSV download |
| Local runtime | `runtime/` | Station JSON, CSV history, command inbox, browser heartbeat, local access codes; do not commit |

## Request/response path

1. Student enters one assigned six-digit code in a browser; `POST /api/login` establishes an authenticated session for **one station**.
2. Browser polls `GET /api/state` about every 1.2 s and writes a student heartbeat through the bridge.
3. Student requests changes with `POST /api/command`. The Python bridge validates and stores a timestamped JSON command in `runtime/inbox/`. The station is determined by the authenticated session, not a client-supplied station number.
4. MATLAB's timer reads the inbox and runs commands, reads analog inputs, evaluates the digital twin and live PID, and—when permitted—writes appropriate Modbus coils.
5. MATLAB publishes `stationN.json` and short CSV histories. Python serves only that station's data.

The web bridge **does not** directly address Modbus and cannot prove actuator power state. A Python HTTP health response alone does not mean the MATLAB process is healthy.

## Runtime freshness and continuity

- MATLAB writes Unix epoch timestamps in UTC; the bridge marks states stale when older than approximately 6 s.
- The browser disables Live Start when data is stale or sensor/setpoint checks fail.
- MATLAB checks recent browser heartbeats for armed live stations.
- Browser access codes are session permissions, **not** a suitable boundary against users already on an untrusted network.
- The server is plain HTTP, designed for a segregated lab LAN, not internet publication.

## Station independence: important caveat

Each station has independent state, process model, temperature readback, PID integrals, arming status and output request. **Within each station, simulation and live control presently share the same setpoint and base PID gains.** The web interface does not create separate gains per tab.

## Live output timing

Current output demand uses `mod(s.live_seconds, s.window) < s.window*s.live_duty/100` in a roughly one-second MATLAB timer. Very short ON pulses may be missed or distorted by callback delays, I/O latency, or the timer `BusyMode='drop'`. This is **not** accurate high-resolution PWM scheduling; verify with low-voltage indicators and make a design change before applications requiring accurate low-duty control.
