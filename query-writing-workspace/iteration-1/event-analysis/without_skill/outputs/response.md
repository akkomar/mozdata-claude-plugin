Here's a BigQuery query to analyze Activity Stream click events in Firefox Desktop over the last week, broken down by country.

### How it works

Firefox telemetry stores events in an array within each ping. The query uses `UNNEST(events)` to flatten the event array so we can filter and aggregate individual events.

- **`event.category = 'activity_stream'`** filters to Activity Stream events (the new tab page)
- **`event.name = 'click'`** narrows to click events specifically
- **`metadata.geo.country`** provides the country based on GeoIP lookup

### Results

The query returns daily event counts and unique user counts by country for activity_stream click events.

### Notes

- This query may be expensive on large date ranges since it scans raw event data
- Consider adding a `LIMIT` clause for initial exploration
- You may also want to look at `event.extra` for additional click properties (e.g., what was clicked)
