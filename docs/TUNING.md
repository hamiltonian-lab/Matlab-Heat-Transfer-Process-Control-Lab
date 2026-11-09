# Model-based tuning options

The tuning panel consumes the currently entered digital-twin parameters: $K_p^{plant}=\texttt{gain}/100$ (units °C per percent heater command), $\tau=\texttt{tau}$ and $L=\max(1,\texttt{deadtime})$.

It writes calculated **controller** gains $K_p$, $K_i$, $K_d$ into the **same station gains used by simulation and live PID**. It does *not* perform real-time system identification.

## Available methods (as implemented)

| Choice | MATLAB formulas | Intended interpretation |
|---|---|---|
| **Ziegler–Nichols PI** | $K_p=0.9\tau/(KL)$, $K_i=K_p/(3L)$, $K_d=0$ | Aggressive PI tuning from the assumed plant model |
| **Ziegler–Nichols PID** | $K_p=1.2\tau/(KL)$, $K_i=K_p/(2L)$, $K_d=K_p L/2$ | Aggressive full PID; may overshoot or saturate |
| **Conservative IMC PI** | $\lambda=\max(\tau/2,L)$, $K_p=\tau/[K(\lambda+L)]$, $T_i=\min(\tau,4(\lambda+L))$, $K_i=K_p/T_i$, $K_d=0$ | Slower, smoother PI starting point |
| **Manual PID** | Keep current gains | Use the values entered by the student |
| **Fuzzy PID** | Switch to fuzzy rule multipliers | Adjust existing gains via a fixed 3×3 Sugeno rule base based on temperature error and rate |

The fuzzy supervisor is deterministic rule-based logic, **not machine learning**. If the base derivative gain is zero, its fuzzy-scaled derivative contribution remains zero.

### Starting-model example

At `gain=70 °C`, `tau=100 s`, `deadtime=5 s`, the plant gain in controller units is $K=0.7\,°C/\%$:

| Method | Kp | Ki | Kd |
|---|---:|---:|---:|
| ZN PI | 25.714 | 1.714 | 0 |
| ZN PID | 34.286 | 3.429 | 85.714 |
| IMC PI | 2.597 | 0.026 | 0 |

These are model-based values only. At a 14 °C error, ZN PI proportional action alone far exceeds 100% demand. Treat these numbers as an instructional example, **not validated live-heater tuning**.

## Teaching workflow

Compare P-only, manual PI, ZN PI, ZN PID and IMC in simulation under identical starting conditions and cooling disturbances. Record rise time, peak overshoot, settling behavior, steady-state offset, disturbance recovery and actuator demand. For an actual vessel, identify a FOPDT approximation from a properly supervised, protected step-response test before choosing any live gains.

**Operational caveat:** applying tuning while a physical live controller is running changes shared gains. Instructor procedures should prevent students from changing control gains during a live run without authorization.
