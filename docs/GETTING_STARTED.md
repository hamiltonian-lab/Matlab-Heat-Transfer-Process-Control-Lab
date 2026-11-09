# Installation and launch (Windows master)

## Prerequisites

- A **Windows master PC** with MATLAB and Modbus support (`modbus('tcpip', ...)`; developed using R2026b Industrial Communication Toolbox).
- **Python 3** installed with the Windows `py` launcher. The bridge imports only standard-library modules.
- ADAM module IPs and master Ethernet IP configured on an isolated laboratory network.
- Student PCs with a modern browser; **no MATLAB or Python installation on student PCs**.

## Software-only check

1. Extract this repository to a local folder such as `C:\Engineering\four-station-process-control-lab`.
2. Open Command Prompt and check: `py -3 --version`.
3. In MATLAB, change its current folder to the project root.
4. Confirm the master network matches the source-configured `192.168.0.200`. If not, update source settings consistently; do **not** use a random hardcoded address owned by another adapter.
5. With heater power disconnected, run `Verify_Dual_ADAM` to check I/O communications; this is a read-only Modbus test.
6. Run `master = Start_UnitOps_Lab;` (or use `Launch_Lab.bat` if MATLAB is on PATH).
7. Verify `http://192.168.0.200:8088/api/health` responds on the master, and the student address `http://192.168.0.200:8088` loads on another lab-connected machine.
8. In the instructor GUI, click **Open station access codes**, then assign one of the generated six-digit codes to each station. Codes are stored only in the local, gitignored `runtime/` directory.
9. Begin with the **Simulation** tab. Live heater control requires the separate [commissioning process](COMMISSIONING.md).

## Where settings currently live

| Value | File(s) | Current example |
|---|---|---|
| Master server IP | `Start_UnitOps_Lab.m`, `UnitOpsMaster.m`, `bridge.py` | `192.168.0.200` |
| Analog module IP | `UnitOpsMaster.m`, `Verify_Dual_ADAM.m` | `192.168.0.20` |
| Digital module IP | `UnitOpsMaster.m`, `Verify_Dual_ADAM.m` | `192.168.0.21` |
| WIKA input temperature ranges | `UnitOpsMaster.m` | 0–150 °C (provisional) |
| Instructor software trips | `UnitOpsMaster.m` | 60 °C initially, adjustable |
| Student codes, states, history | `runtime/` | Generated on first run; never commit |

## Networking tips

- Use a fixed IP on the master Ethernet adapter or a router DHCP reservation. If you use a fixed Ethernet address on an isolated network, avoid installing an unnecessary default gateway on that adapter, especially when the PC separately uses Wi-Fi for internet.
- For a Windows firewall rule, allow inbound TCP 8088 **only on the trusted lab network**, not on public or unrestricted campus networks.
- Module Modbus TCP (502) must be reachable by MATLAB; student browsers should **not** need direct module access.
- A ping result proves network-layer reachability, not that the browser server or Modbus register mapping is correct.

## Closing and restarting

Close the instructor GUI cleanly and terminate any older Python bridge process before starting another version, otherwise TCP port 8088 may be occupied or an old runtime directory may be served. For Windows, PowerShell can locate the old bridge:

```powershell
Get-CimInstance Win32_Process |
  Where-Object { $_.CommandLine -match 'bridge\.py' } |
  Select-Object ProcessId, CommandLine
```

Do not run multiple master controllers against the same physical outputs.
