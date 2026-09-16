# FGG Pengiriman

FGG shipping is a separate linked account inside Folony Activity. The app uses its
existing Folony session to call `/api/fgg/*`. The Laravel server owns the FGG token
(encrypted at rest); passwords are used for login only and are never persisted.
Only entries with exact `userRole: HUB` qualify. COHUB does not grant access.

## Environment and deployment

Set `FGG_ENVIRONMENT=staging` on the staging Folony server. Every FGG endpoint,
including login, uses `https://dev.foodukm.com/app/`.

Production requires `FGG_ENVIRONMENT=production`, `APP_ENV=production` and
`APP_URL=https://absent.folony.co.id`. Every FGG endpoint then uses
`https://api.foodukm.com/app/`. The production host guard prevents a staging server
from accidentally sending credentials or shipping transactions to production.
Account bindings and operation deduplication are partitioned by environment.

Run after deploying backend files:

```sh
php artisan optimize:clear
php artisan migrate --force
php artisan config:cache
```

Keep the server APP_KEY unchanged so encrypted FGG tokens remain readable.
The mobile app has no external FGG base URL setting; it follows its Folony backend.
The new APK requires this backend release and migrations before opening FGG.
The GPS release requires fresh latitude, longitude, accuracy_meters, and captured_at
on each shipping POST. These fields remain in Folony's field-activity audit and are
not forwarded to the legacy FGG APIs. Missing, out-of-range, or stale coordinates
reject the transaction before any upstream POST. GPS time is stored in UTC.
Historical transactions have nullable GPS; no coordinates are backfilled.
Deploy the backend migration before using the v5 APK; older APKs cannot submit
transactions after the new GPS requirement is enabled.

Dashboard shipment totals are obtained by traversing all pages of status 1 and 2
and counting distinct transaction_id values. Totals are all-time for the linked
HUB, not just actions taken in Folony. A partial fetch error never displays a
partial count as the total. Counts refresh after actions and by pull-to-refresh.

Both satellite maps use the Esri World_Boundaries_and_Places transparent overlay.
It supplies place labels and available administrative boundaries, not a guaranteed
complete village/kelurahan boundary dataset. Documentation:
https://doc.arcgis.com/en/data-appliance/2022/maps/world-boundaries-places.htm
For large proof photos, configure the web server and PHP to accept JSON payloads
up to 8 MB. The app compresses camera photos and limits the source image to 5 MB.

## Implemented API contract

Login uses form encoding. Shipping uses `Authorization: <login token>` (no Bearer).
Receive sends JSON `no_dst`; delivery sends JSON `transaction_id` and `buktiFoto`
(base64 JPEG/PNG). No extra hub parameter is invented. The client respects
`recipient_button` for reception and exposes delivery under the ready-to-send
filter. The FGG server remains responsible for transaction ownership and transitions.

The provided API contract has no hub-switch operation. Single-HUB accounts must
select their HUB and can continue. Multi-HUB accounts are explicitly blocked
pending an upstream contract for context selection. Local selection alone cannot
be used as a security boundary. No refresh-token API was supplied; expired tokens
require reconnecting FGG only.

Successful POSTs are deduplicated by environment/member/action/target and recorded
in HR's Aktivitas Lapangan timeline, using the successful operation as the source.
Employee work sessions are untouched. The report migration removes only exact
auto-generated employee-activity duplicates, preserving the original operations
and all manual work notes. Known rejections
can be retried. Timeout, malformed response, upstream server error, or interrupted
request leaves a pending/unknown operation that cannot be blindly replayed.
An administrator must reconcile such an operation against FGG before resetting it;
there is no automatic resend, offline queue, or claim of distributed exactly-once.

## Validation

Live staging login and GET list DST, list shipments, detail DPP, and detail order
were inspected using the supplied Postman account. With user authorization, live
POSTs were sent for DST 152 and order 5361 (using the supplied Postman proof photo).
Both correctly returned statusCode 2: already received / already sent. All six
visible DSTs have recipient_button=false; all six shipments are finish. Filters
for ready orders returned no data. A fresh eligible shipment is still needed to
verify a successful state transition end to end.
Automated tests fake FGG responses for role gating, encrypted tokens, environment
isolation, production guard, proof validation, duplicate prevention, expiry, and
activity logging. Successful live receipt/delivery still requires eligible staging data.
No credentials from the Postman collection are embedded in source or release files.

## Daily field activity and OpenStreetMap (16 September 2026)
- Monitoring Jaringan and mobile Heatmaps start in OpenStreetMap street mode. Satellite imagery with Esri labels remains selectable.
- `/admin/network-activities` groups records by actor ID and local recording date (APP_TIMEZONE, normally Asia/Jakarta). Search selects matching days; each selected day includes all events, and detail is never truncated to 500 records.
- Details show profile creation, visits, successful DST receive and order send; records from other FGG environments and unsuccessful operations are excluded.
- Visit intervals are merged to avoid duplicate working time for overlapping visits. Legacy duration-only entries are added separately. No duration is fabricated for profile creation or shipping. A cross-midnight visit belongs to its recording date.
- Numbered route markers follow visit start time or recording time. Distances and dashed lines are straight-line links, not street routes or background GPS tracking. Missing coordinates break the route. Network visits use registered profile coordinates; shipping uses recorded phone GPS. Source and accuracy are displayed.
- Standard OSM tiles use visible attribution, app identification, and Flutter Map 8.3 built-in HTTP tile caching; there is no offline tile download feature. Provider policy: https://operations.osmfoundation.org/policies/tiles/.

## Attendance daily and delivery journeys (v7 / 0.1.8-staging)
- Attendance monitoring groups by user ID/work_date; detail retains every attempt and its location/face audit. Durations count completed successful check-in/out pairs (office and outside), merge overlaps, exclude gaps and incomplete sessions. CSV follows daily grouping.
- Home displays FGG Pengiriman only for AppRole.fgg.
- `/api/fgg/trips/{order}` GET restores a journey; POST action=start/arrive requires fresh phone GPS and FGG role. Server timestamps are authoritative and repeats do not reset times. The trip is scoped by environment/member/order plus owning Folony user and HUB.
- Destination is the upstream order detail's senders_address, confirmed by the product owner as the buyer address. Google Maps resolves the textual address; user should check the mapped destination before departing.
- Start opens directions; Arrive stops travel time; photo proof/send is a separate step. A journey that exists must have arrival before sending. Old clients can still send orders without a journey, which produces no invented duration.
- Successful send marks completed_at and appears in field activities with start/arrival duration; union of recorded travel and visit intervals avoids double counting daily work.
- The app uses Google Maps URLs, not a paid routing API. No ETA is imported into Folony and no continuous background tracking is recorded. Journey timing requires network connectivity to start/arrive.
- The full backend includes the OSM per-tile Referrer-Policy fix and blank storage folder structure. Preserve/restore the server .env with original APP_KEY and user storage; these are not bundled.

## HR delivery proof (16 September 2026)
Successful sends now retain the validated JPEG/PNG on the private local disk before calling FGG. A storage failure prevents the upstream request and permits retry. Duplicate successes keep the original proof. HR can view photos from daily field activity details through an authenticated, environment-scoped endpoint. Old operations without a stored proof remain unavailable. Preserve storage/app/private when deploying/backing up. Run migration 000005 before use. APK v8 already sends the required photo payload.
