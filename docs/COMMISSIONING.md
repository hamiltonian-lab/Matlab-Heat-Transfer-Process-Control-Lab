# Commissioning requirements (before physical heater operation)

> [!CAUTION]
> This repository is teaching-lab control software, **not** a safety-rated heater control system. Software OFF commands can fail, an SSR can fail closed, and a displayed temperature can be incorrect. Hardware and mains work require a qualified professional and applicable institutional review.

## Suggested staged verification

- Confirm the source build, master IP and module addresses; avoid address conflicts.
- Verify all 4–20 mA transmitter ranges, status codes, and temperature readback against independent references.
- With **heater mains isolated**, confirm independent DO0–DO3 control signals using suitable low-voltage loads/indicators and verify station isolation.
- Confirm the ADAM-6050 output watchdog and tested fail-safe OFF configuration, including communication loss.
- Verify browser authentication, command age filtering, MATLAB freshness, instructor arming, emergency output OFF requests, and lost browser heartbeat behavior.
- Independently commission thermal cutoffs, wiring protection, disconnect(s), grounding, and emergency stop provisions; assess SSR fail-closed behavior.
- Only after the above review, conduct supervised tests on **one station at a time**, then assess simultaneous operation and thermal/electrical loading.

## Critical limitations

- `STOP ALL` attempts to command Modbus outputs OFF, **not** to isolate heater mains.
- A valid `do_readback` is not current/voltage measurement through the physical heater.
- MATLAB timer timing is coarse for small PWM duty percentages.
- Instrument scaling is provisional until calibrated.
- The software trip threshold is not an independent high-limit thermostat.
- Student browser connections use HTTP over an assumed trusted isolated lab LAN; they are not suitable for access across the public internet.

Records from commissioning, electrical design review, real-world control validation, and qualified sign-off are not included in this repository.
