// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'Projeto WLM';

  @override
  String get statusOnline => 'Disponível';

  @override
  String get statusBusy => 'Ocupado';

  @override
  String get statusAway => 'Ausente';

  @override
  String get statusAppearOffline => 'Aparecer como offline';

  @override
  String get statusOffline => 'Offline';

  @override
  String get contactsFavorites => 'Favoritos';

  @override
  String get contactsGroups => 'Grupos';

  @override
  String get contactsAvailable => 'Disponível';

  @override
  String get contactsOffline => 'Offline';

  @override
  String get searchContactsWeb => 'Procurar contactos ou na Web...';

  @override
  String get quickSharePlaceholder => 'Partilhar uma mensagem rápida';

  @override
  String get syncingContacts => 'A sincronizar lista de contactos...';

  @override
  String get windowsLiveMessenger => 'Windows Live Messenger';

  @override
  String get changeStatus => 'Alterar estado';

  @override
  String get spaceHeyFooter => '';

  @override
  String messageSays(Object name) {
    return '$name diz:';
  }

  @override
  String messageMeSays(Object name) {
    return '$name diz:';
  }

  @override
  String messageSends(Object name) {
    return '$name envia:';
  }

  @override
  String typingIndicator(Object name) {
    return '$name está a escrever...';
  }

  @override
  String get moreStatuses => 'Mais Estados';

  @override
  String get signOutHere => 'Terminar sessão aqui';

  @override
  String get changeDisplayPicture => 'Alterar imagem de apresentação...';

  @override
  String get changeScene => 'Alterar cenário...';

  @override
  String get changeDisplayName => 'Alterar nome a apresentar...';

  @override
  String get menuOptions => 'Opções...';
}
