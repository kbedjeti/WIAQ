# check_forecast.R
# Polls the WI DNR air quality forecast page and emails the narrative
# whenever it changes. State (last-seen forecast text) is stored in
# last_forecast.txt and committed back to the repo by the workflow.

suppressPackageStartupMessages({
  library(httr2)
  library(rvest)
  library(blastula)
})

forecast_url <- "https://airquality.wi.gov/home/text/324"
state_file   <- "last_forecast.txt"

# ---- Fetch ------------------------------------------------------------------

resp <- tryCatch(
  request(forecast_url) |>
    req_user_agent("aqi-forecast-watcher (personal use; R/httr2)") |>
    req_timeout(30) |>
    req_perform(),
  error = function(e) {
    # Transient network failures shouldn't turn the run red; just skip.
    message("Fetch failed, skipping this run: ", conditionMessage(e))
    quit(status = 0)
  }
)

page <- read_html(resp_body_string(resp))
page_text <- html_text2(page)

# ---- Extract the forecast section ------------------------------------------
# The narrative sits between the "Updated <day> - <time>" line and the
# "Forecast Maps" / AQI-ranges boilerplate. Fall back to the whole page
# text if the markers ever move.

lines <- strsplit(page_text, "\n", fixed = TRUE)[[1]]

start_idx <- grep("^\\s*Updated\\b", lines)[1]
end_idx   <- grep("Forecast Maps|Air Quality Index \\(AQI\\) ranges", lines)[1]

if (is.na(start_idx)) start_idx <- 1L
if (is.na(end_idx) || end_idx <= start_idx) end_idx <- length(lines) + 1L

section <- trimws(paste(lines[start_idx:(end_idx - 1L)], collapse = "\n"))

if (nchar(section) < 40) {
  message("Extracted section suspiciously short; page layout may have changed. Skipping.")
  quit(status = 0)
}

updated_line <- trimws(lines[start_idx])

# ---- Compare with last-seen state ------------------------------------------

previous <- if (file.exists(state_file)) {
  paste(readLines(state_file, warn = FALSE), collapse = "\n")
} else {
  ""
}

if (identical(trimws(previous), section)) {
  message("No change since last check (", updated_line, ").")
  quit(status = 0)
}

message("Forecast changed — sending email.")

# ---- Send email -------------------------------------------------------------
# Wrap the narrative in <pre>-style markdown so line breaks survive.

email <- compose_email(
  body = md(paste0(
    "**Wisconsin DNR Air Quality Forecast**\n\n",
    section,
    "\n\n---\n\n",
    "[View the forecast page](", forecast_url, ")"
  )),
  footer = md("Sent by your GitHub Actions forecast watcher.")
)

smtp_send(
  email,
  from    = Sys.getenv("SMTP_USERNAME"),
  to      = Sys.getenv("EMAIL_TO"),
  subject = paste("WI Air Quality Forecast:", updated_line),
  credentials = creds_envvar(
    user        = Sys.getenv("SMTP_USERNAME"),
    pass_envvar = "SMTP_PASSWORD",
    host        = Sys.getenv("SMTP_HOST", unset = "smtp.gmail.com"),
    port        = as.integer(Sys.getenv("SMTP_PORT", unset = "465")),
    use_ssl     = TRUE
  )
)
# If smtp_send() errors, the script (and the Actions run) fails visibly,
# which is what you want -- silent email failures would defeat the purpose.

# ---- Persist state ----------------------------------------------------------

writeLines(section, state_file)
message("State file updated.")
