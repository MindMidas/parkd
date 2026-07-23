/// Maps UI day chip index ([kWeekdayLabels]: 0 = Mon … 6 = Sun) to Postgres
/// `availability_weekly.day_of_week` (0 = Sun … 6 = Sat)
int weekdayUiMonFirstToPostgres(int uiIndex) {
  if (uiIndex < 0 || uiIndex > 6) return 1;
  if (uiIndex == 6) return 0;
  return uiIndex + 1;
}
