# Staging checkpoint - 16 September 2026

Mobile release: 0.1.10-staging (20260924), APK v9.

Included: FGG HUB account integration with separate staging/production endpoints; actionable DST/shipment filters; phone GPS, delivery journeys, cleaned directions addresses, private delivery proof; daily employee/field/attendance reports; face scan and heatmap fixes; mobile role-specific cards and collapsed sections; collapsible HR navigation, filters and survey catalogs.

Validation: 147 backend tests (981 assertions); 36 focused mobile/widget tests after adapting the expanded-panel interactions; targeted Dart analysis clean; staging release APK built and installed; local browser checks on navigation, filters, survey catalogs and narrow layouts; full deployment ZIP verified against source and extraction checksums.

Runtime secrets, local uploads, device screenshots, build caches and ZIP/APK artifacts are excluded from Git. Preserve server .env (including APP_KEY), database and storage on deployment. Install dependencies using the lockfiles and run Laravel migrations. FGG_ENVIRONMENT must be staging on staging.

Deployment helpers are generated locally by scripts/new_staging_artisan_helper.ps1 from a token-free template. Generated helpers and release packages stay in ignored deploy/ and dist/ directories. Use a unique ReleaseId for each deployment to avoid reusing a completed lock.

This Git checkpoint does not itself deploy the website or change production.
