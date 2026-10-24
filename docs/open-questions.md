# Open questions

Resolved tariff questions and their sources are in `docs/tariffs-il.md`.

- **Q1 Waiting hour (part ד item 11).** Priced per hour (99 / 118.8 / 138, ex-VAT). Unclear whether this replaces the per-minute charge while a hired taxi waits for the passenger, or is a separate hourly hire. v1 keeps the per-minute meter running during waiting.
- **Q2 Apple Developer account / Team ID.** None yet. Needed for on-device background location and Live Activities beyond free provisioning, TestFlight, and the CarPlay entitlement request.
- **Q3 Bundle ID.** Placeholder `com.orimiles.moneh`, set in `ios/Config/App.xcconfig`.
- **Q4 Express lane toll and VAT.** Item 9 charges "the toll shown on the electronic sign". The tariff treats it as a pass-through amount the driver enters, with no VAT added, on the assumption that the sign shows the final price.
- **Q5 Final rounding.** The 2018 smart meter spec (§8.2.3) rounds the final sum to 0.10 ₪ (≤ 5 agorot down, > 5 up). The 2026 tariff order is silent. Is the spec still in force? If so, the fare engine should round the final total to 0.10 ₪.
- **Q6 Approval route.** Does the Ministry accept any phone-based meter, or only dedicated devices tested to the 2018 spec? See `docs/regulatory.md`.

