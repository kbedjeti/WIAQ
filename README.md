# WI Air Quality Forecast Watcher

Polls the Wisconsin DNR air quality forecast page
(https://airquality.wi.gov/home/text/324) hourly during the day and emails
you the full narrative forecast whenever it changes.

## Repo layout

```
check_forecast.R              # the checker/emailer
.github/workflows/aqi-watch.yml   # the schedule
last_forecast.txt             # last-seen forecast text (created by the workflow)
```

## Setup

1. Create a new GitHub repo (private is fine) and add these files.

2. Add three repository secrets under
   **Settings → Secrets and variables → Actions → New repository secret**:

   | Secret | Value |
   |---|---|
   | `SMTP_USERNAME` | the email address you're sending *from* (e.g. your Gmail) |
   | `SMTP_PASSWORD` | for Gmail: an **app password**, not your normal password |
   | `EMAIL_TO` | where to deliver the forecast (can be the same address) |

   Gmail app passwords require 2-step verification on the account; create one
   at https://myaccount.google.com/apppasswords. If you use a different
   provider, set `SMTP_HOST` / `SMTP_PORT` in the workflow's `env:` block.

3. Test it: go to the **Actions** tab, select "WI air quality forecast
   watcher", and hit **Run workflow**. The first run always emails (there's
   no stored state yet), so you'll know delivery works.

## Notes

- The schedule attempts a run every 15 minutes. This is overscheduled due to frequent drops from load.
- The script exits quietly on fetch hiccups but fails loudly (red X + GitHub
  notification email) if the SMTP send fails, so you'll notice broken creds.
- GitHub pauses schedules in repos with no activity for ~60 days; the state
  commits normally keep it alive, but during a long stretch of unchanged
  forecasts you may get a "workflow disabled" email — one click re-enables it.
- The extraction assumes the page keeps its "Updated ..." line and
  "Forecast Maps" section. If the DNR redesigns the page, the script skips
  rather than emailing garbage; check the Actions logs if emails stop.
