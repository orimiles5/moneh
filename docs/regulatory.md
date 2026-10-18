# Regulatory notes

Moneh is **not a certified taxi meter**. Until it is, the app must say so plainly (onboarding and settings) and must not present itself as an official meter or the fare as legally binding.

Draft notice (Hebrew, to be reviewed):

> מונה היא אפליקציית עזר לחישוב מחיר נסיעה לפי התעריפים שפורסמו על ידי משרד התחבורה. היא אינה מונה מאושר ואינה מחליפה את המונה המותקן במונית.

## What certification would likely involve (to research, not yet verified)

- Israeli taxis must use an approved meter; since 2020 the tariff structure assumes a "smart meter". The Ministry of Transport spec for smart meters, and the approval route for a phone-based meter, need to be obtained from the Ministry.
- International references a regulator may lean on: OIML R 21 (taximeters) and EU MID Annex MI-007.
- Expected technical asks, which the architecture already prepares for:
  - Deterministic fare calculation, separated from UI and platform code (`core/`).
  - Tamper-evident trip log (hash chain) recording tariff version, events and fare.
  - Versioned tariffs traceable to their legal source.
  - Distance and time measurement accuracy, which will need a test protocol (GPS limits, OBD-II option).
  - Sealing: proof that the app binary and tariff data were not modified.

## Privacy

Location stays on the device. No analytics SDKs. Only the trip data needed for the fare and receipt is stored.
