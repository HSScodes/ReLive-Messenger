import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('pt')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'WLM Project'**
  String get appTitle;

  /// No description provided for @statusOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get statusOnline;

  /// No description provided for @statusBusy.
  ///
  /// In en, this message translates to:
  /// **'Busy'**
  String get statusBusy;

  /// No description provided for @statusAway.
  ///
  /// In en, this message translates to:
  /// **'Away'**
  String get statusAway;

  /// No description provided for @statusAppearOffline.
  ///
  /// In en, this message translates to:
  /// **'Appear offline'**
  String get statusAppearOffline;

  /// No description provided for @statusOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get statusOffline;

  /// No description provided for @contactsFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get contactsFavorites;

  /// No description provided for @contactsGroups.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get contactsGroups;

  /// No description provided for @contactsAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get contactsAvailable;

  /// No description provided for @contactsOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get contactsOffline;

  /// No description provided for @searchContactsWeb.
  ///
  /// In en, this message translates to:
  /// **'Search contacts or the Web...'**
  String get searchContactsWeb;

  /// No description provided for @quickSharePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Share a quick message'**
  String get quickSharePlaceholder;

  /// No description provided for @syncingContacts.
  ///
  /// In en, this message translates to:
  /// **'Syncing contact list...'**
  String get syncingContacts;

  /// No description provided for @windowsLiveMessenger.
  ///
  /// In en, this message translates to:
  /// **'Windows Live Messenger'**
  String get windowsLiveMessenger;

  /// No description provided for @changeStatus.
  ///
  /// In en, this message translates to:
  /// **'Change status'**
  String get changeStatus;

  /// No description provided for @spaceHeyFooter.
  ///
  /// In en, this message translates to:
  /// **''**
  String get spaceHeyFooter;

  /// No description provided for @messageSays.
  ///
  /// In en, this message translates to:
  /// **'{name} says:'**
  String messageSays(Object name);

  /// No description provided for @messageMeSays.
  ///
  /// In en, this message translates to:
  /// **'{name} says:'**
  String messageMeSays(Object name);

  /// No description provided for @messageSends.
  ///
  /// In en, this message translates to:
  /// **'{name} sends:'**
  String messageSends(Object name);

  /// No description provided for @typingIndicator.
  ///
  /// In en, this message translates to:
  /// **'{name} is typing...'**
  String typingIndicator(Object name);

  /// No description provided for @moreStatuses.
  ///
  /// In en, this message translates to:
  /// **'More Statuses'**
  String get moreStatuses;

  /// No description provided for @signOutHere.
  ///
  /// In en, this message translates to:
  /// **'Sign out here'**
  String get signOutHere;

  /// No description provided for @changeDisplayPicture.
  ///
  /// In en, this message translates to:
  /// **'Change display picture...'**
  String get changeDisplayPicture;

  /// No description provided for @changeScene.
  ///
  /// In en, this message translates to:
  /// **'Change scene...'**
  String get changeScene;

  /// No description provided for @changeDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Change display name...'**
  String get changeDisplayName;

  /// No description provided for @menuOptions.
  ///
  /// In en, this message translates to:
  /// **'Options...'**
  String get menuOptions;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'pt': return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
