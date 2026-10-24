# Regulatory notes

Moneh is **not a certified taxi meter**. Until it is, the app must say so plainly (onboarding and settings) and must not present itself as an official meter or the fare as legally binding.

Draft notice (Hebrew, to be reviewed):

> מונה היא אפליקציית עזר לחישוב מחיר נסיעה לפי התעריפים שפורסמו על ידי משרד התחבורה. היא אינה מונה מאושר ואינה מחליפה את המונה המותקן במונית.

## The approval route: the Ministry's smart meter spec

Source: [Spec 2018] משרד התחבורה, "מפרט בדיקות למונה אלקטרוני למוניות הנשלט מרחוק ('מונה חכם')", December 2018, <https://www.gov.il/BlobFolder/dynamiccollectorresultitem/4public_transport/he/56.pdf>. It builds on ת"י 50148 (taximeters). Traffic Regulation 485 defines a meter as a device approved by the authority and requires the driver to run it on every trip.

Compliance can be tested by any lab accredited under the law (cover letter §13). One Israeli smart meter (AppByWeb for Kupona) says it was built to this spec, passed a standards lab and is approved by the Tax Authority as a computerized system; it is a dedicated device wired to the roof sign, driven from a phone app.

**Moneh as built today cannot be approved.** The spec assumes a dedicated in-car device. Gaps, by section:

| Spec | Requirement | Moneh today |
|---|---|---|
| 5.1 | Protected against changes without approval (reg. 485); used only as a meter, nothing else | Runs on a general-purpose phone; unsigned tariff data inside the app |
| 5.1, 7.2 | Integral printer, non-thermal paper, 44 mm, kept 7 years | Image receipt only |
| 6 | Marked with maker, model, serial number; Hebrew user guide | None |
| 8.1.4, 12 | Distance from vehicle pulses (meter constant K ≥ 500 pulses/km, matched to vehicle W) | GPS |
| 14 | Distance error ≤ ±0.2%, time ≤ ±0.1% | Time is fine; GPS distance is nowhere near ±0.2% |
| 10–11 | 12 V supply, 9–16 V range, cold/heat/humidity/vibration/EMC tests (IEC 60068, IEC 61000, ISO 7637, ת"י 961, ת"י 1358) | A phone can't pass these as a meter |
| 8.1.5–8.1.8, 8.2.1 | Three states shown as words: פנוי, תפוס, תשלום. Only פנוי → תפוס → תשלום. No return to פנוי while the invoice prints | idle/hired/paused/stopped/settled; Pause has no counterpart in the spec |
| 8.1.7 | In תשלום, if the car moves more than 10 m the meter goes back to תפוס automatically | Not implemented |
| 8.1.2 | Display updates at least every 30 s | Every second (fine) |
| 8.2.3 | Final sum including extras rounded to 0.10 ₪: up to 5 agorot down, above 5 up (24.67 → 24.70, 24.23 → 24.20) | Rounded to the agora |
| 8.2.4 | Extras shown in a separate display labelled תוספות; max 999.99 ₪ | Extras inside the total |
| 8.2.5 | Distance in km to one decimal; time MM:SS under an hour, HH:MM from an hour | Matches |
| Annex א | Tax invoice: taxi number, licence number, dealer number, owner, driver name and ID, invoice number, date, start and end time, distance to the metre, tariff, fare, extras (≤ 18, names ≤ 16 chars, ≤ 99.99 ₪ each), discount, total | Receipt says "not a tax invoice"; no driver, taxi or dealer details |
| 8.3 | Shift open/close, shift summary and cumulative totals; kept 6 months | None |
| 7.1, 7.3, Annex ג | Remote tariff and parameter updates; electronic seal that logs the last five K, licence and tariff changes and prints them | Tariffs ship in app updates; the hash-chained trip log is a start, but there is no seal log |
| 9.4, 9.6 | Opening and closing of shifts and every trip reported to approved meter companies' servers; remote access for the licensed dealer | Local only, no backend |
| 9.7 | Driver identification (card or approved ID) | None |
| 9.8 | Roof sign lit when פנוי, off when תפוס | None |
| 9.9, 9.10 | Pre-agreed fixed price; discount | None |
| 8.3.3 | Shared trip: several trips at once, separate invoices | One trip at a time |
| 9.3 | Card and digital payments | None |

**What does carry over:** the fare engine and tariffs (pure, tested, sourced), the tamper-evident trip log, local persistence, Hebrew UI, and the trip states (mapped onto פנוי/תפוס/תשלום).

**Status (2026-10-24): functional requirements implemented**

| Spec | Implemented |
|---|---|
| §8.1.5–8.1.8, §8.2.1 | States פנוי / תפוס / תשלום shown as words; no pause; driving on more than 10 m in payment returns to hired |
| §8.2.2–8.2.5 | Tariff 1/2/3; price display without extras; separate extras display; km to one decimal; MM:SS / HH:MM |
| §8.2.3 | Final sum rounded to 0.10 ₪ |
| §8.2.4, Annex A note 2 | Up to 18 extras, ≤ 99.99 ₪ each, names ≤ 16 characters; tolls entered by hand in hired or payment |
| §9.9, §9.10 | Agreed price; discount by percent or amount |
| Annex A | Invoice details fixed in the trip log on entering payment: document number, dealer, taxi, licence, driver and ID, times, distance to the metre, tariff, fare, extras, discount, total; shared digitally |
| §8.3.1–8.3.5 | Shifts with summary (cash, card, income, extras, km driven, km hired, trips), cumulative totals, meter number; kept indefinitely; reports only while free |
| §9.7, §9.12 | Driver identified by Face ID or passcode at shift opening; several licensed dealers, one chosen |
| Annex B, §7.3, Annex C | Tariff data report; electronic seal logging every tariff and licence change, last five shown, never erased |
| §9.11 | Trip source recorded; all trip data exportable as CSV |
| §8.3.3 | Shared trips, each computed and invoiced separately and marked shared |

Open: distance accuracy ±0.2% (§14) needs OBD-II speed and road tests (`docs/accuracy-protocol.md`); remote updates and reporting to a server (§7.1, §9.1, §9.2, §9.4, §9.6); card payments (§9.3); roof sign (§9.8). The receipt keeps saying it is not a tax invoice until the Tax Authority approves the app as a computerised invoicing system.

**Decision (2026-10-24): the app replaces the device.** Taxis run Moneh only, with no meter hardware. The app implements every functional requirement of the spec (milestone "R Regulatory parity", issues #52–#63). Hardware-only requirements are replaced by software equivalents, to be agreed with the Ministry:

| Hardware requirement | Proposed replacement |
|---|---|
| Printer, paper kept 7 years (§5.1, §7.2) | Digital tax invoice (share, SMS, email), stored 7 years |
| Vehicle pulses and meter constant K (§8.1.4) | GPS fused with OBD-II vehicle speed; a per-vehicle calibration factor in place of K, logged in the seal log |
| 12 V supply and environmental/EMC tests (§10–11) | Phone power and the phone's own certification; trip survives app kill and reboot |
| Protection against changes (§5.1, reg. 485) | App Store signing, signed tariff files, hash-chained logs, seal log |
| Marking with maker, model, serial (§6) | About screen with app version and a per-install meter ID |
| Roof sign control (§9.8) | Out of scope until a connected sign exists |
| Dedicated device used only as a meter (§5.1) | Open question for the Ministry |

**Open with the Ministry:** ask the Ministry (public transport division) whether the 2018 spec is still current, whether a phone-based meter has any route at all, and which labs are accredited. Ask the Tax Authority what a computerized-system approval requires.

## Privacy

Location stays on the device. No analytics SDKs. Only the trip data needed for the fare and receipt is stored.
