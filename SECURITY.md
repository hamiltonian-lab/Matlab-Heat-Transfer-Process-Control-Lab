# Security, safety and disclosure

## Deployment scope

This project is designed for a **trusted, isolated teaching-laboratory LAN**. It exposes a plaintext HTTP server on port 8088, uses six-digit station codes, stores generated files under `runtime/`, and can issue low-voltage commands to heater-control SSR inputs through industrial I/O. It is **not** designed for internet-facing deployment, campus-wide access, or unattended heater operation.

### Keep private

- Do **not** commit `runtime/access_codes.json`, `runtime/ACCESS_CODES_FOR_INSTRUCTOR.txt`, `runtime/inbox/`, station JSON, live data CSVs or browser heartbeats.
- Do not publish API tokens, institutional network credentials, remote access details, students' work, personal information or actual panel wiring metadata without review.
- Before making this repository public, confirm software rights, institutional policies, and which contributors should be credited. The repository intentionally has **no license** pending that review.
- Plain HTTP exposes traffic to anyone able to observe that lab segment; separate VLAN/network controls are required as appropriate.

### Safety engineering requirements

- Software STOP / coil readback is **not** electrical isolation or an emergency stop.
- SSRs can fail closed. Independent appropriately rated high-temperature cutoff(s), overcurrent protection, disconnects, protective earth and independent emergency stop provisions require qualified engineering.
- Verify 4–20 mA scaling and sensor status against independent temperature references.
- Test ADAM-6050 watchdog/fail-safe states at its actual hardware configuration.
- Commission one channel at a time with heater mains isolated, then under reviewed controlled conditions if authorized.

Report potential vulnerabilities privately to the repository owner rather than posting access codes or live endpoints in public issues.
