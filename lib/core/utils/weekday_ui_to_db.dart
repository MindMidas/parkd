// Maps UI day chip index to Postgres day_of_week.
int weekdayUiMonFirstToPostgres(int uiIndex) {
  if (uiIndex < 0 || uiIndex > 6) return 1;
  if (uiIndex == 6) return 0;
  return uiIndex + 1;
}
