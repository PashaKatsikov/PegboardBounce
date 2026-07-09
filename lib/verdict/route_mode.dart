/// Which experience the shell has committed the install to.
///
/// - [hosted]   → returning session that previously received a URL.
/// - [gameplay] → returning session that previously fell back to the
///                native game. Never re-checks the gate.
/// - [fresh]    → first launch; not decided yet.
enum RouteMode {
  hosted,
  gameplay,
  fresh;

  static RouteMode fromToken(String? token) {
    switch (token) {
      case 'hosted':
        return RouteMode.hosted;
      case 'gameplay':
        return RouteMode.gameplay;
      default:
        return RouteMode.fresh;
    }
  }

  String get token => name;
}
