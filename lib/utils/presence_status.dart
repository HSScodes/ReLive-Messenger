enum PresenceStatus {
  online,
  busy,
  away,
  appearOffline,
}

PresenceStatus presenceFromMsnp(String code) {
  switch (code.toUpperCase()) {
    case 'NLN':
      return PresenceStatus.online;
    case 'BSY':
    case 'BRB':
      return PresenceStatus.busy;
    case 'IDL':
    case 'AWY':
    case 'LUN':
    case 'PHN':
      return PresenceStatus.away;
    case 'HDN':
    case 'FLN':
      return PresenceStatus.appearOffline;
    default:
      return PresenceStatus.online;
  }
}

String presenceToMsnp(PresenceStatus status) {
  switch (status) {
    case PresenceStatus.online:
      return 'NLN';
    case PresenceStatus.busy:
      return 'BSY';
    case PresenceStatus.away:
      return 'AWY';
    case PresenceStatus.appearOffline:
      return 'HDN';
  }
}
