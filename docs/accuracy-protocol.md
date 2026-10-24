# Distance and time accuracy: test protocol

The Ministry smart meter spec (Dec 2018) sets the accuracy a meter must reach: distance within ±0.2% and time within ±0.1% (§14). A hardware meter is tested on a bench with a pulse generator (§12–13). Moneh has no pulse input, so the equivalent tests run on the road and on the device clock. This is the protocol we propose to the Ministry; the results go in the table at the end.

## Time (§13)

The spec runs a tariff of 1 ₪ per minute with no pulses for one hour and expects 61.00 ₪ (1 ₪ start + 60 minutes).

1. Load a test tariff: starting fare 1.00, per minute 1.00, per km 0, VAT 0. (Test tariffs are data files; they never ship.)
2. Start a trip with the phone stationary. Stop after exactly one hour by a reference clock (GPS-disciplined or NTP-synchronised).
3. Record the fare and the trip's charged seconds. Pass: 61.00 ₪ and 3600 s ± 3.6 s.
4. Repeat with the app in the background and the screen locked, and once across a device restart mid-trip.

The meter charges from event timestamps in the trip log, not from a running counter, so time accuracy is the device clock's accuracy. iOS keeps the clock synchronised to network time; the log clamps backward clock steps so a correction can never reduce the fare.

## Distance (§12)

The spec drives the meter with simulated pulses for 10, 20, 30, 40 and 50 km at 50 km/h, with a tariff of 1 ₪ start + 1 ₪ per km, and expects 11, 21, 31, 41, 51 ₪.

Road equivalent:

1. Load a test tariff: starting fare 1.00, per km 1.00, per minute 0, VAT 0.
2. Choose surveyed routes of 10, 20, 30, 40 and 50 km whose length is known to the metre (from survey or a calibrated reference vehicle odometer), covering city, highway, tunnels, and urban canyons.
3. Drive each route five times at legal speeds, with a reference distance measured independently (a calibrated wheel sensor or a certified meter in the same vehicle).
4. For each run record: reference distance (A), fare shown (B), distance the fare implies (C = B − 1 km), difference (D = A − C) and error (E = D / A). Pass: |E| ≤ 0.2%.
5. Repeat with the vehicle-speed source (OBD-II) enabled and disabled, so the contribution of each is visible.

## What we expect, and what follows

GPS alone will not reach ±0.2% on every route: urban canyons, tunnels and multipath add or lose tens of metres per kilometre. The distance pipeline already rejects poor fixes, outliers and standing-still drift, but the requirement calls for a second source. The plan:

- **OBD-II vehicle speed** over Bluetooth LE (standard PID 0x0D), integrated over time and fused with GPS. This replaces the spec's pulse input (§8.1.4) with the vehicle's own speed signal.
- **Per-vehicle calibration factor**, the software equivalent of matching the meter constant K to the vehicle constant W (§8.1.4). It is set by an authorised technician, never by the driver, and every change is recorded in the electronic seal log (§7.3).

## Results

| Run | Route | Source | Reference (m) | Fare (₪) | Implied (m) | Error |
|---|---|---|---|---|---|---|
| | | | | | | |
