UNIT OPERATIONS | MATLAB + TWO ADAM MODULES | FOUR STATIONS
============================================================
This is an UPDATED four-station version of the previous MATLAB master +
student browser package. MATLAB remains the ONLY process that reads/writes
Modbus. Python standard-library bridge.py only hosts web pages and queues
station-scoped commands; student PCs only need a browser.

HARDWARE
ADAM-6024-D (ANALOG INPUTS) : 192.168.0.20, TCP/502
ADAM-6050-D (DIGITAL OUTPUTS): 192.168.0.21, TCP/502 (proposed - configure!)
Main MATLAB PC:               192.168.0.200 (wired; reserve its IP)
Router:                       192.168.0.1
Station 1: AI0 -> ADAM-6050 DO0 / coil 17
Station 2: AI1 -> ADAM-6050 DO1 / coil 18
Station 3: AI2 -> ADAM-6050 DO2 / coil 19
Station 4: AI3 -> ADAM-6050 DO3 / coil 20

PREPARATION
1. Set an UNUSED static IP 192.168.0.21 on the ADAM-6050 in Advantech Utility.
   Verify no conflicts in router DHCP. Connect both ADAMs and central PC to
   three separate LAN ports of lab router. Students connect on lab Wi-Fi.
2. Set each ADAM-6024 analog channel AI0-AI3 to 4-20 mA (range code 7),
   set current mode jumpers, and VERIFY programmed transmitter spans.
   The code's common 0-150 C transmitter range is PROVISIONAL.
3. Configure ADAM-6050 communication watchdog with DO0-DO3 FSV=0 (OFF)
   and an appropriate timeout, and test its behavior. Check SSR inputs
   compatible with sink outputs rated 30 V and 100 mA maximum/channel.
4. Follow LOW_VOLTAGE_WIRING.txt for input/sink loop wiring. Mains heating
   circuits require a qualified electrician, independent overtemperature
   protection, a real means of disconnecting heater power, and E-stop as
   appropriate. Software STOP/coil readback DOES NOT guarantee isolation.
5. On central laptop, run in PowerShell:
       Test-NetConnection 192.168.0.20 -Port 502
       Test-NetConnection 192.168.0.21 -Port 502
   Or run `Verify_Dual_ADAM` in MATLAB (read-only, no output writes).

LAUNCH ON CENTRAL WINDOWS MATLAB PC
- Stop all older version servers using TCP/8088 before starting.
- Ensure MATLAB R2026b with Industrial Communication Toolbox for Modbus;
  Python 3 launcher `py -3` present for the web bridge.
- Double-click Launch_Lab.bat OR open MATLAB, change to this directory, run:
       master = Start_UnitOps_Lab;
- Instructor MATLAB panel displays all four stations, four arming boxes,
  and separately editable software temperature trips for each physical station.
  The trip entries are bounded by the provisional transmitter spans configured
  in UnitOpsMaster.m. Verify/correct these spans before any live operation.
- For student station codes, click 'Open station access codes' on instructor PC.
- Remote students open http://192.168.0.200:8088 over LAB Wi-Fi.
- The Python bridge must run (the launcher starts it automatically). It
  does NOT own temperature data, DO writes, or PID loops.

TABS
- Simulation: separate first-order plus dead-time virtual plant for every station.
- Live experiment: actual AI0..AI3 readings; start/stop live PID calculations;
  output only commands when respective instructor commissioning toggle armed.
- ZN/IMC/fuzzy tuning: each student can calculate and apply model-based gains.
- Simulation setpoint, PID gains and process model no longer have the previous
  arbitrary browser limits; inputs must still be finite and models physically
  well-posed (gain and time constant > 0).
- Live setpoints are independently constrained by the corresponding station's
  instructor-controlled software trip, not by a universal 55 C GUI ceiling.
- No fixed 600-second live experiment timeout. Live runs continue while active
  and the sensor/browser/controller/device checks remain satisfied.

LIVE EQUIPMENT LIMITS / HARDWARE SAFEGUARDS
- Physical outputs remain disarmed on launch. Instructor can arm each station
  without the old repeated commissioning confirmation popup.
- A new per-station instructor software trip (default 60 C) replaces the single
  fixed trip. Changing a trip stops that station's live PID and requests DO OFF.
- Every digital reconnection commands OFF to DO0-DO3 and stops live PID runs.
- One independent station stop requests its DO OFF; Stop All requests all OFF.
- Faults, stale browser heartbeat, bad AI status, and reaching the configured
  temperature trip request OFF. There is no fixed maximum experiment runtime.
- Student PID duty remains clamped to the physically meaningful SSR range
  of 0-100 percent. The SSR PWM period remains 4-120 seconds.
- Software trips are NOT safety-rated and cannot replace hardware cutouts.
- If the MATLAB process, Windows PC, Ethernet, SSR, or module fails, a software
  OFF command cannot guarantee electricity is disconnected. Use independent
  cutouts, tested module watchdog FSV=OFF, and professional electrical design.
- DO readback shows ONLY Modbus output logic, not SSR conduction/heater power.

NOTES
- IMPORTANT: the dual-ADAM MATLAB code has not been run in MATLAB or connected
  to physical modules in this environment. The Python bridge and browser JS
  can be syntax-checked here, but MATLAB and physical IO must be validated
  on a bench with heater mains isolated before any live run.
- Each student has a unique six-digit numeric station code; users must not share codes.
- Codes are created on first bridge start and stored in runtime/access_codes.json.
  Existing long-format codes will be replaced automatically on first start.
  Afterward, valid six-digit codes remain the same across restarts.
  Click the MATLAB instructor button "Open station access codes" to view them.
- Keep the network isolated from the URI production LAN or coordinate with IT.
- This is a prototype for teaching, not a safety-rated industrial controller.
