// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'WLM Project';

  @override
  String get statusOnline => 'Online';

  @override
  String get statusBusy => 'Busy';

  @override
  String get statusAway => 'Away';

  @override
  String get statusAppearOffline => 'Appear offline';

  @override
  String get statusOffline => 'Offline';

  @override
  String get contactsFavorites => 'Favorites';

  @override
  String get contactsGroups => 'Groups';

  @override
  String get contactsAvailable => 'Available';

  @override
  String get contactsOffline => 'Offline';

  @override
  String get searchContactsWeb => 'Search contacts or the Web...';

  @override
  String get quickSharePlaceholder => 'Share a quick message';

  @override
  String get syncingContacts => 'Syncing contact list...';

  @override
  String get windowsLiveMessenger => 'Windows Live Messenger';

  @override
  String get changeStatus => 'Change status';

  @override
  String get spaceHeyFooter => 'SpaceHey - a space for friends.';

  @override
  String messageSays(Object name) {
    return '$name says:';
  }

  @override
  String get messageMeSays => 'I say:';

  @override
  String typingIndicator(Object name) {
    return '$name is typing...';
  }
}
