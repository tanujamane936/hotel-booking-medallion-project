# Cleaning Rules

| Problem | What I did | Why |
|---|---|---|
| Duplicate bookings (26) | SELECT DISTINCT | Duplicates inflate bookings and revenue |
| Extra spaces, mixed case | INITCAP(TRIM(col)) | Same spelling everywhere, so GROUP BY works |
| Blank city (12) | Replaced with 'Unknown' | Keeps the row, no lost revenue |
| Blank booking channel (13) | Replaced with 'Unknown' | Keeps the row, no lost revenue |
| Blank nights (15) | DATEDIFF(check_out, check_in) | Nights can be calculated from the dates |
| Blank total amount (17) | nights x room_rate | Amount can be calculated |
| Blank discount | Replaced with 0 | Net revenue stays correct |
| Blank rating or guest ID | Left as NULL | AVG skips NULL, 0 would lower the average |
| Check-out on or before check-in (12) | Sent to rejected table | Impossible stay |
| Negative room rate (9) | Sent to rejected table | Impossible price |
| Cancelled bookings | Kept in Silver | Normal business event, not bad data |
| Cancelled bookings in revenue | Not counted in Gold | Only Completed stays earn revenue |
