# Israel tariff: how the fare is computed

Sources:
- **[Order 2018]** צו פיקוח על מחירי מצרכים ושירותים (מחירי נסיעה במוניות), התשע"ח–2018, קובץ התקנות 8034, 5.7.2018. <https://www.gov.il/BlobFolder/dynamiccollectorresultitem/supervisionorder_05072018/he/decision_and_directives_SupervisionOrder_05072018.pdf>
- **[Amendment 2026]** the same order (תיקון), התשפ"ו–2026, קובץ התקנות 12345, 30.3.2026. <https://www.gov.il/BlobFolder/policy/taxi-rate-2026/he/taxi-rate-26.pdf>
- **[Committee 2025]** ועדת מחירים, סיכום דיוני בדיקת בסיס של תעריפי נסיעה במוניות מיוחדות, 18.8.2025. <https://www.gov.il/BlobFolder/dynamiccollectorresultitem/decision_18082025/he/decision_and_directives_decision_18082025.pdf>
- **[Spec 2018]** משרד התחבורה, מפרט בדיקות למונה אלקטרוני למוניות הנשלט מרחוק ("מונה חכם"), דצמבר 2018. <https://www.gov.il/BlobFolder/dynamiccollectorresultitem/4public_transport/he/56.pdf>

## Prices in force 1.4.2026 – 31.3.2027 (VAT-exclusive, ₪)

From the temporary provision, [Amendment 2026] §6:

| | תעריף א׳ | תעריף ב׳ | תעריף ג׳ |
|---|---|---|---|
| Starting fare | 10.56 | 10.56 | 10.56 |
| Per minute | 1.65 | 1.98 | 2.31 |
| Per km, up to 10 km | 1.65 | 1.98 | 2.31 |
| Per km, beyond 10 km | 3.21 | 3.54 | 3.87 |

Extras, from [Amendment 2026] §4(3), part ד, with item 2 per §6:

| Extra | Price |
|---|---|
| Booking to the caller's location (item 2) | 4.90 |
| Ben Gurion airport (item 5) | +4.24 |
| Ramon and Haifa airports (item 6) | +1.69 |
| Highway 6 on request (item 7) | +16.95 |
| Highway 6 segment 18 (item 8) | +6.56 |
| Ben Gurion express lane (item 9) | the toll shown on the sign |
| Carmel Tunnels (item 10) | 10.02 one segment, 20.03 both |
| Waiting, per hour (item 11) | 99 / 118.8 / 138, pro rata |

The luggage extra expired on 31.12.2020.

## Answers to the open questions

**Time and distance are added together, with no crossover speed.** The committee's worked fare is the fixed fare + minutes × per-minute rate + km × per-km rate + the booking extra. For tariff 1 that is 10.86 + 22.75 + 8.95 + 2.52 = 45.08 ([Committee 2025], table 6). Minutes count the whole trip duration: 5.26 km in 13.38 minutes is the table's average speed of 23.6 km/h.

**Over 10 km only the per-km rate rises.** The committee adopted a "distance factor" of +1.56 ₪ per km beyond the first 10 km ([Committee 2025], decision item 3). The 2026 figures match exactly (3.21 − 1.65 = 1.56), and the per-minute rate is unchanged. The 10 km threshold is cumulative over the whole trip.

**Prices exclude VAT, and the passenger pays VAT on top.** The committee decided the order would state prices "ללא מע"מ" so that Eilat needs no separate tariff and VAT changes need no amendment ([Committee 2025], decision item 4). The new §3 updates prices automatically when the VAT rate changes. Table 6 confirms the passenger price is the ex-VAT price × 1.18. Eilat (אזור אילת) is VAT-exempt.
- **Our choice:** VAT is applied once to the trip total and rounded half-up to the agora. VAT is charged on a transaction, not per line. Per-line rounding would drift by up to an agora per component.
- **Final rounding:** the total, extras and tolls included, is then rounded to 0.10 ₪: up to 5 agorot down, above 5 up, as the Ministry's smart meter spec requires ([Spec 2018] §8.2.3). The receipt shows the difference as a rounding line.

**Tariff bands switch mid-trip.** Tariffs are defined as "התעריף ... בעד נסיעה בימים ובשעות" — the price for travel during those days and hours ([Order 2018] §1). Each minute and each km is charged at the band in which it happens. The starting fare and booking extra are the same in every band, so the start time doesn't matter for them.

**Day and hour bands** ([Order 2018] §1, original table):

| Day | Tariff א | Tariff ב | Tariff ג |
|---|---|---|---|
| Sun–Wed | 06:00–21:00 | 21:01–05:59 | — |
| Thursday | 06:00–21:00 | 21:01–23:00 | 23:01–05:59 |
| Eve of a rest day | 06:00–16:00 | 16:01–21:00 | 21:01–05:59 |
| Rest day | — | 06:00–19:00 | 19:01–05:59 |

- **Rest days (ימי מנוחה):** those under Government and Law Procedure Ordinance §18A(a) (Shabbat and the Jewish holidays), plus Independence Day. Each runs 06:00 to 05:59 the next day.
- **Eve of a rest day (ערב יום מנוחה):** Friday, and any day before a rest day, until 05:59.
- **Our choice when categories overlap:** rest day > eve of a rest day > Thursday > Sunday–Wednesday. For example, the second day of Rosh Hashana is both a rest day and the eve of one, so it is a rest day.

**Meter resolution (our choice).** The order defines prices per minute and per km, not per step. The engine charges continuously: whole seconds × rate/60 and whole metres × rate/1000, accumulated exactly and rounded once at the end. The running display rounds down to 0.10 ₪, so the shown fare never runs ahead of the final one.

**Extras in v1 (product choice).** The driver toggles extras by hand: booking, airports, Highway 6, tunnels, and the express-lane toll with an amount entered. No geofencing.

**Tariff updates (product choice).** The temporary provision ends 31.3.2027. New tariff files ship with app releases, and each trip records the tariff version it used.
