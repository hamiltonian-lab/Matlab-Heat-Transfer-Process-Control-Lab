# Thermal digital twin and PID control

## First-order-plus-dead-time plant

The simulation uses a simplified well-mixed thermal model:

$$
\tau\frac{dT(t)}{dt}=T_{amb} + K\frac{u(t-L)}{100} + D - T(t)
$$

| Parameter | Source field | Starting value | Interpretation |
|---|---|---:|---|
| $T$ | `sim_temp` | 21 °C initially | Simulated vessel temperature |
| $T_{amb}$ | constant | 21 °C | Assumed ambient |
| $K$ | `gain` | 70 °C | Equilibrium temperature increase at 100% input |
| $\tau$ | `tau` | 100 s | Time constant; ~63.2% of a step after one time constant |
| $L$ | `deadtime` | 5 s | Delay between command and modeled effect |
| $D$ | `cool_disturbance` | 0 or -12 °C | Shift in equilibrium temperature |
| $u$ | `sim_duty` | 0-100% | Controller power demand |

The code advances the model using a first-order exact exponential update over the elapsed callback interval:

$$
T_{k+1}=T_k + \left(1-e^{-\Delta t/\tau}\right)(T_{target,k}-T_k),
\quad T_{target,k}=T_{amb}+K\,u_{delayed,k}/100 + D.
$$

Dead time is approximated by a per-station queue of past commands. Changes in MATLAB callback intervals change the discrete delay approximation.

### Example

With $T_{amb}=21\,°C$, $K=70\,°C$, $D=0$ and constant duty $u=50\%$, the predicted equilibrium is **56 °C**. This is a **model result**, not a validated measurement.

## Energy-balance motivation

A physical lumped thermal balance with approximately constant ambient losses can be written:

$$
mc_p\frac{dT}{dt}=\eta P_{max}\frac{u}{100}-UA(T-T_{amb}).
$$

If the assumptions hold, $\tau=mc_p/UA$ and $K=\eta P_{max}/UA$. In the real rig, delay, changing convection, mixing, vessel walls and sensor dynamics also affect identified values. **Do not equate these nominal coefficients to a specific real vessel without a measured step-response identification.**

## PID calculation

With $e_k=T_{set}-T_k$, the implementation uses:

$$
P_k=K_p e_k,\quad I_k=K_i \sum_j e_j\Delta t_j,\quad D_k=-K_d\frac{T_k-T_{k-1}}{\Delta t},
$$
$$
u_k=\max\left(0,\min\left(100,P_k+I_k+D_k\right)\right).
$$

Derivative action is on measured temperature rather than setpoint error, which avoids derivative kick on a setpoint change. The integrator stops accumulating further error in the direction of output saturation (simple anti-windup). The simulation and live controller keep separate integral state but use **shared base gains and setpoint**.

## SSR time-proportioning (live path)

The `window` field defaults to **20 s** and is independent of the FOPDT energy-balance equation. At a constant 8% duty, the ideal requested ON duration is $20(0.08)=1.6$ s, followed by 18.4 s OFF. The actual output is evaluated at roughly one-second intervals; therefore these short pulses are **not guaranteed**. A visible SSR indicator or Modbus coil readback only establishes limited parts of the control path.

## Cooling disturbance

Selecting cooling disturbance changes $D$ to −12 °C; toggling again returns it to 0. It does not instantly subtract 12 °C from the vessel temperature. It lowers the thermal equilibrium for a given heater duty and allows students to observe disturbance rejection. It is a simulation-only effect.
