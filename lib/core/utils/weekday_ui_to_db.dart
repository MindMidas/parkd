// Maps UI day chip index (kWeekdayLabels: 0 = Mon … 6 = Sun) to Postgres
int weekdayUiMonFirstToPostgres(int uiIndex) {
  if (uiIndex < 0 || uiIndex > 6) return 1;
  if (uiIndex == 6) return 0;
  return uiIndex + 1;
}
