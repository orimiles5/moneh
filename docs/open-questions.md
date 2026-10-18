# Open questions

Source of truth for tariffs: צו פיקוח על מחירי מצרכים ושירותים (מחירי נסיעה במוניות) (תיקון), התשפ"ו–2026, קובץ התקנות 12345, 30.3.2026,
<https://www.gov.il/BlobFolder/policy/taxi-rate-2026/he/taxi-rate-26.pdf>. Base order: התשע"ח–2018.

Values from the temporary provision (הוראת שעה, §6, 1.4.2026–31.3.2027), part ד (special trip by meter):

| | תעריף א׳ | תעריף ב׳ | תעריף ג׳ |
|---|---|---|---|
| Starting fare | 10.56 | 10.56 | 10.56 |
| Per minute | 1.65 | 1.98 | 2.31 |
| Per km, up to 10 km | 1.65 | 1.98 | 2.31 |
| Per km, over 10 km | 3.21 | 3.54 | 3.87 |

Extras (§4(3)): booking 4.90 (temporary provision), Ben Gurion airport +4.24, Ramon/Haifa airports +1.69, Highway 6 +16.95, segment 18 +6.56, express lane = toll shown on sign, Carmel Tunnels 10.02 / 20.03, hourly waiting 99 / 118.8 / 138 pro rata.

## Tariffs

- **Q1 VAT.** The amended prices appear VAT-exclusive (10.56 × 1.18 = 12.46, matching consumer sites). Confirm. Is VAT applied to the total or per component, and where is the agora rounding applied? Eilat is VAT-exempt: confirm passengers there pay the ex-VAT price.
- **Q2 Tariff switch mid-trip.** When a trip crosses a band boundary (e.g. 21:00), does the rate switch at the boundary or stay at the starting tariff?
- **Q3 Over 10 km.** Assumed: per-minute charge is unchanged beyond 10 km, only the per-km rate rises. Confirm. Also: does the smart meter charge continuously (rounded on display) or in discrete increments?
- **Q4 Rest-day bands.** Read as ב 06:00–19:00, ג 19:01–05:59; the consolidated text available was garbled on this row. Need an authoritative consolidated version.
- **Q5 Extras UX.** v1 proposal: driver toggles extras manually (airport, Highway 6, tunnels, booking). No geofencing.
- **Q6 Tariff updates.** Temporary provision ends 31.3.2027. v1 proposal: new tariff file ships with an app release (no backend).

## Product

- **Q7 Apple Developer account / Team ID.** None yet. Needed for on-device testing of background location and Live Activities, and for the CarPlay entitlement request.
- **Q8 Bundle ID.** Placeholder `com.orimiles.moneh`, set in one xcconfig.
