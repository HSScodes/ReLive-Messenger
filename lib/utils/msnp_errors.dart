/// MSNP protocol error codes and human-readable descriptions.
/// Reference: msn-pecan pn_error.c + official MSNP documentation.
class MsnpErrors {
  const MsnpErrors._();

  /// Returns a human-readable description for the given MSNP numeric error
  /// code, or `null` if the code is not recognised.
  static String? describe(int code) => _table[code];

  /// Whether [code] indicates an authentication failure that the user
  /// should be informed about (wrong password, account disabled, etc.).
  static bool isAuthError(int code) =>
      code == 911 || code == 913 || code == 920 || code == 921 || code == 924;

  /// Whether [code] indicates a transient server-side issue that may
  /// resolve with a retry after a short delay.
  static bool isTransient(int code) =>
      code >= 500 && code <= 605 || code == 282 || code == 710;

  /// Whether [code] indicates the switchboard session failed and a new
  /// XFR should be requested.
  static bool isSwitchboardError(int code) =>
      code == 280 || code == 281 || code == 282 || code == 217;

  static const Map<int, String> _table = {
    // ── Syntax / request errors ─────────────────────────────────────────
    200: 'Syntax error',
    201: 'Invalid parameter',
    205: 'Invalid user',
    206: 'Domain name missing',
    207: 'Already logged in',
    208: 'Invalid user name',
    209: 'Invalid friendly name',
    210: 'List full',
    215: 'User already in list',
    216: 'User not in list',
    217: 'User not online',
    218: 'Already in mode',
    219: 'User is in opposite list',
    223: 'Too many groups',
    224: 'Invalid group',
    225: 'User not in group',
    227: 'Not in group',
    229: 'Group name too long',
    230: 'Cannot remove group zero',
    231: 'Invalid group',

    // ── Switchboard errors ──────────────────────────────────────────────
    280: 'Switchboard session failed',
    281: 'Transfer to switchboard failed',
    282: 'Switchboard session ended unexpectedly',

    // ── Server redirect ─────────────────────────────────────────────────
    300: 'Required field missing',
    302: 'Not logged in',

    // ── Server availability ─────────────────────────────────────────────
    500: 'Internal server error',
    501: 'Database server error',
    502: 'Command disabled',
    540: 'Challenge failed or timed out',
    600: 'Server is busy',
    601: 'Server is unavailable',
    602: 'Peer notification server down',
    603: 'Database connection failed',
    604: 'Server is going down',
    605: 'Server unavailable',

    // ── Connection / protocol errors ────────────────────────────────────
    707: 'Could not create connection',
    710: 'Bad CVR parameters',
    711: 'Blocking write',
    712: 'Session overload',
    713: 'Too many active users',
    714: 'Too many sessions',
    715: 'Command not expected',
    717: 'Bad friend file',

    // ── Authentication errors ───────────────────────────────────────────
    911: 'Authentication failed',
    913: 'Not allowed when offline',
    920: 'Not accepting new users',
    921: 'User account not verified',
    922: 'Server too busy for authentication',
    924: 'Account requires verification via email',
  };
}
