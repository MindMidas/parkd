// Main shell tab index (matches bottom nav order)
abstract final class MainTab {
  static const int map = 0;
  static const int reservations = 1;
  static const int hosting = 2;
  static const int account = 3;

  static const int count = 4;

  // Read ?tab= on /home (old profile string counts as account)
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

  // Write ?tab= for /home from tab index
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
