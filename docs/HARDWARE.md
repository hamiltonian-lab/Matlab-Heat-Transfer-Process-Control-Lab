# Hardware interfaces and network

## Current source defaults — verify locally

| Item | Current value | Notes |
|---|---|---|
| Central Windows master | `192.168.0.200`, HTTP 8088 | Static Ethernet on segregated lab LAN; Wi-Fi internet should use its own routing policy |
| ADAM-6024 | `192.168.0.20`, TCP 502 | Analog acquisition AI0–AI3 |
| ADAM-6050 | `192.168.0.21`, TCP 502 | DO0–DO3 sinking outputs; configured coil numbers 17–20 |
| Router | example `192.168.0.1` | DHCP pool should not overlap reserved/static devices |
| WIKA transmitters | 4–20 mA | Four temperature transmitters, one per AI channel |
| Transmitter span in software | provisional 0–150 °C | **Must match the installed transmitter configuration** |

The source currently embeds lab addresses in `UnitOpsMaster.m`, `Start_UnitOps_Lab.m`, `Verify_Dual_ADAM.m`, and `bridge.py`. Changing the master IP on Windows **alone** does not update those strings. Updating the repository for portable network configuration is a future improvement.

## Station mapping

| Station | Temperature input | Digital channel | Coil (MATLAB Modbus address) |
|---|---|---|---:|
| 1 | AI0 | DO0 | 17 |
| 2 | AI1 | DO1 | 18 |
| 3 | AI2 | DO2 | 19 |
| 4 | AI3 | DO3 | 20 |

These are software expectations. Always verify the actual current loop and output wiring with appropriate instruments before heater power is connected.

## Analog inputs

ADAM-6024 AI0–AI3 are assumed configured in 4–20 mA mode (range code 7) with a valid sensor diagnostic status. The example software converts input current using its programmed temperature span. If the transmitter span is incorrect, the displayed temperature and controller response will be incorrect even when Modbus communication succeeds.

## SSR outputs

ADAM-6050 low-voltage sinking outputs are used to command SSR control inputs; they **do not directly power the heaters**. The SSR input polarity, current/voltage, common/return and module output ratings must be verified against actual hardware manuals. Heater mains wiring, emergency stops, earth bonding and cutout design belong to a separately reviewed electrical system. **Modbus output readback is logic-state feedback, not proof of mains isolation or actual SSR conduction.**

For original interface notes, see [`LOW_VOLTAGE_WIRING.txt`](../LOW_VOLTAGE_WIRING.txt), but do not treat the notes as a certified panel schematic.
