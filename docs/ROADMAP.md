# Known limitations and future improvements

The current software is an educational prototype, not a validated multi-loop industrial controller.

## Software and measurement

- **PWM resolution:** the ~1 s MATLAB timer can skip short ON intervals, especially at low duties (e.g., 8% of 20 s = 1.6 s). Evaluate real-time output scheduling and independent measurements.
- **Separate settings:** simulation and live PID setpoint/gains are shared per station. Introduce independent profiles and explicit transfer/approval before live use.
- **Data capture:** export presently uses bounded (~400-sample) recent history; add persistent per-run logging, UTC timestamps, experiment IDs, state flags and mode-exclusive rows.
- **Network configuration:** move hardcoded IP addresses into a user-supplied, noncommitted local configuration file.
- **Security:** replace six-digit HTTP-only logins with institution-approved authentication and transport if broader network deployment is ever desired.
- **Control improvements:** test actuator saturation, anti-windup, derivative filtering, disturbances, model mismatch and communication faults under structured software tests.
- **Identification:** fit gain, time constant, and dead time from measured step responses rather than relying on nominal defaults.
- **Documentation:** add a verified electrical schematic and commissioning test report only after qualified review.

## Validation status

Python source can be syntax checked independently. Hardware timing, output wiring, thermal behavior and synchronized four-station operation require tests on the actual isolated rig. Screenshots are from an offline preview.
