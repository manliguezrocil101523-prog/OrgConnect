# OrgConnect — Green UI & Finals Analytics Update

This version keeps the existing OrgConnect role flow and Supabase connection while adding the approved requirements from the project notes.

## Included updates

- Lively green visual system across the main app theme and major role screens.
- Separate **Final Analytics** area for administrators.
- Organization comparison based on member and event activity.
- Active-student activity tracking through `last_seen_at`.
- Event view tracking.
- Members can comment on posted events when signed in.
- Public event feed is shown on app launch even when the user is not logged in.
- Student-life impact tracking for academic, social, leadership and confidence growth.
- Usage logging for app actions so usage patterns can be reviewed during finals.
- Existing inactive-account handling remains in place.

## Supabase setup for the new analytics features

The original Supabase project connection is preserved. The client cannot create database tables, so the new analytics tables/columns are provided as a migration:

`supabase/migrations/20260917_orgconnect_analytics.sql`

Run that SQL once in the Supabase SQL Editor for project:

`cbjttubjzbxrqsnqwoom`

After the migration is applied, the following features become persistent:

- `event_comments`
- `event_views`
- `usage_logs`
- `student_impact`
- `profiles.priority_level`
- `profiles.last_seen_at`

The app is written to fail gracefully when optional analytics tables have not yet been created, so the core organization/event screens can still open.

## Run locally

```bash
flutter pub get
flutter run
```
