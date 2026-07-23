// Which slice of /home you're on — stays in sync with AppBottomNav
abstract final class MainTab {
  static const int map = 0;
  static const int reservations = 1;
  static const int hosting = 2;
  static const int account = 3;

  static const int count = 4;

  // Parses ?tab= on /home (legacy profile → account)
  static int fromQuery(String? tab) {
    switch (tab) {
      case 'map':
        return map;
      case 'reservations':
        return reservations;
      case 'hosting':
      case 'listings':
        return hosting;
      case 'account':
      case 'profile':
        return account;
      default:
        return map;
    }
  }

  // Maps tab index back to query string for /home?tab=
  static String toQuery(int index) {
    switch (index) {
      case reservations:
        return 'reservations';
      case hosting:
        return 'hosting';
      case account:
        return 'account';
      default:
        return 'map';
    }
  }
}
