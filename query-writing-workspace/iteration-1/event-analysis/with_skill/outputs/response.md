### Table Choice

This query uses `mozdata.firefox_desktop.events_stream`, which is the recommended table for event analysis in Firefox Desktop. Per the aggregation hierarchy, `events_stream` provides pre-flattened event rows (no manual `UNNEST` needed) and is clustered by `event_category`, making it significantly faster than querying the raw `events_v1` table.

### Query Explanation

The query retrieves **activity_stream click events** from the last 7 days, broken down by date and country:

- **`event_category = 'activity_stream'`** filters to Activity Stream events (the Firefox New Tab / about:home experience). Because `events_stream` is clustered on `event_category`, this filter prunes data efficiently.
- **`event_name = 'click'`** narrows to click interactions specifically.
- **`normalized_country_code`** provides the ISO country code derived from the client's IP at submission time (server-side geolocation, not client-reported).
- **`COUNT(*)`** gives total click events; **`COUNT(DISTINCT client_id)`** gives the number of unique client profiles that generated those clicks.

### Performance Notes

- **Partition filter**: `DATE(submission_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)` ensures BigQuery only scans 7 days of data instead of the full table.
- **sample_id = 0**: Limits to a 1% consistent sample for fast development iteration. Remove this filter when you want full production results. To scale up the 1% sample estimate to approximate full counts, multiply by 100.
- **Terminology**: Results reflect client profiles, not individual users. A single user may have multiple profiles.

### Extending the Query

- To filter to specific countries, add `AND normalized_country_code IN ('US', 'DE', 'FR')`.
- To see what extra dimensions are available on click events, inspect `event_extra` (an `ARRAY<STRUCT<key STRING, value STRING>>` column) which may contain additional properties like the click source or tile type.
- To restrict to the release channel only, add `AND normalized_channel = 'release'`.
