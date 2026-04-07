import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:xml/xml.dart';

import '../config/server_config.dart';

class AbchRosterEntry {
  const AbchRosterEntry({required this.email, required this.displayName});

  final String email;
  final String displayName;
}

class AbchService {
  Future<List<AbchRosterEntry>> fetchRoster({
    required String host,
    required String ticket,
    required String ownerEmail,
    String? mspAuth,
    String? mspProf,
    String? sid,
    void Function(String message)? log,
  }) async {
    if (ticket.isEmpty && (mspAuth == null || mspAuth.isEmpty)) {
      return const <AbchRosterEntry>[];
    }

    final client = HttpClient()..connectionTimeout = ServerConfig.authTimeout;
    try {
      final candidateUris = _abchCandidateUris(host);
      final passportCookie = _buildPassportCookie(
        mspAuth: mspAuth,
        mspProf: mspProf,
        sid: sid,
      );
      final ticketCandidates = <String>[
        if (ticket.isNotEmpty) ticket,
        if (mspAuth != null && mspAuth.isNotEmpty) mspAuth,
      ];

      for (final uri in candidateUris) {
        for (final ticketValue in ticketCandidates) {
          final soapBody = _buildAbFindAllEnvelope(ticket: ticketValue);
          log?.call('ABCH request -> $uri (ticketLen=${ticketValue.length})');
          final xml = await _requestRosterXml(
            client: client,
            uri: uri,
            soapBody: soapBody,
            authTicket: ticketValue,
            passportCookie: passportCookie,
            log: log,
          );
          if (xml == null || xml.isEmpty) {
            continue;
          }

          final roster = _parseRoster(xml, ownerEmail: ownerEmail);
          if (roster.isNotEmpty) {
            return roster;
          }
        }
      }

      return const <AbchRosterEntry>[];
    } finally {
      client.close(force: true);
    }
  }

  /// Persist a contact to the server address book via ABContactAdd SOAP.
  /// Returns `true` on success (`200` response without a SOAP fault).
  Future<bool> addContact({
    required String host,
    required String ticket,
    required String contactEmail,
    String? mspAuth,
    String? mspProf,
    String? sid,
    void Function(String message)? log,
  }) async {
    if (ticket.isEmpty && (mspAuth == null || mspAuth.isEmpty)) {
      return false;
    }

    final client = HttpClient()..connectionTimeout = ServerConfig.authTimeout;
    try {
      final candidateUris = _abchCandidateUris(host);
      final passportCookie = _buildPassportCookie(
        mspAuth: mspAuth,
        mspProf: mspProf,
        sid: sid,
      );
      final ticketCandidates = <String>[
        if (ticket.isNotEmpty) ticket,
        if (mspAuth != null && mspAuth.isNotEmpty) mspAuth,
      ];

      for (final uri in candidateUris) {
        for (final ticketValue in ticketCandidates) {
          final soapBody = _buildAbContactAddEnvelope(
            ticket: ticketValue,
            contactEmail: contactEmail,
          );
          log?.call('ABCH ABContactAdd -> $uri for $contactEmail');
          final ok = await _sendSoapRequest(
            client: client,
            uri: uri,
            soapBody: soapBody,
            soapAction:
                'http://www.msn.com/webservices/AddressBook/ABContactAdd',
            authTicket: ticketValue,
            passportCookie: passportCookie,
            log: log,
          );
          if (ok) return true;
        }
      }
      return false;
    } finally {
      client.close(force: true);
    }
  }

  /// Generic SOAP POST that returns `true` when status is 2xx and no fault.
  Future<bool> _sendSoapRequest({
    required HttpClient client,
    required Uri uri,
    required String soapBody,
    required String soapAction,
    required String authTicket,
    required String? passportCookie,
    required void Function(String message)? log,
  }) async {
    try {
      final request = await client
          .postUrl(uri)
          .timeout(ServerConfig.authTimeout);
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        'text/xml; charset=utf-8',
      );
      request.headers.set('SOAPAction', soapAction);
      request.headers.set(HttpHeaders.userAgentHeader, 'MSMSGS');
      request.add(utf8.encode(soapBody));

      final response = await request.close().timeout(ServerConfig.authTimeout);
      log?.call('ABCH response <- $uri status=${response.statusCode}');
      final responseBody = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final compact = _compact(responseBody);
        if (compact.isNotEmpty) {
          final preview = compact.length > 260
              ? compact.substring(0, 260)
              : compact;
          log?.call('ABCH non-success payload preview: $preview');
        }
        return false;
      }
      final compact = _compact(responseBody);
      if (compact.contains('<fault') ||
          compact.contains('authenticationfailed')) {
        log?.call('ABCH SOAP fault in response');
        return false;
      }
      return true;
    } on TimeoutException {
      return false;
    } on SocketException {
      return false;
    } catch (_) {
      return false;
    }
  }

  List<Uri> _abchCandidateUris(String host) {
    return <Uri>[
      Uri(
        scheme: 'http',
        host: host,
        port: ServerConfig.abchPort,
        path: '/abservice/abservice.asmx',
      ),
    ];
  }

  Future<String?> _requestRosterXml({
    required HttpClient client,
    required Uri uri,
    required String soapBody,
    required String authTicket,
    required String? passportCookie,
    required void Function(String message)? log,
  }) async {
    try {
      final request = await client
          .postUrl(uri)
          .timeout(ServerConfig.authTimeout);
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        'text/xml; charset=utf-8',
      );
      request.headers.set(
        'SOAPAction',
        'http://www.msn.com/webservices/AddressBook/ABFindAll',
      );
      request.headers.set(HttpHeaders.userAgentHeader, 'MSMSGS');
      request.add(utf8.encode(soapBody));

      final response = await request.close().timeout(ServerConfig.authTimeout);
      log?.call('ABCH response <- $uri status=${response.statusCode}');
      final responseBody = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final compact = _compact(responseBody);
        if (compact.isNotEmpty) {
          final preview = compact.length > 260
              ? compact.substring(0, 260)
              : compact;
          log?.call('ABCH non-success payload preview: $preview');
        }
        return null;
      }

      final compact = _compact(responseBody);
      if (compact.contains('<fault') ||
          compact.contains('authenticationfailed')) {
        final preview = compact.length > 260
            ? compact.substring(0, 260)
            : compact;
        log?.call('ABCH SOAP fault preview: $preview');
      }
      return responseBody;
    } on TimeoutException {
      return null;
    } on SocketException {
      return null;
    } catch (_) {
      return null;
    }
  }

  String _buildAbContactAddEnvelope({
    required String ticket,
    required String contactEmail,
  }) {
    final escapedTicket = _escapeXmlText(ticket);
    final escapedEmail = _escapeXmlText(contactEmail);
    return '''<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/">
    <soap:Header>
        <ABApplicationHeader xmlns="http://www.msn.com/webservices/AddressBook">
            <ApplicationId>CFE80F9D-180F-4399-82AB-413F33A1FA11</ApplicationId>
            <IsMigration>false</IsMigration>
            <PartnerScenario>ContactSave</PartnerScenario>
        </ABApplicationHeader>
        <ABAuthHeader xmlns="http://www.msn.com/webservices/AddressBook">
            <ManagedGroupRequest>false</ManagedGroupRequest>
            <TicketToken>$escapedTicket</TicketToken>
        </ABAuthHeader>
    </soap:Header>
    <soap:Body>
        <ABContactAdd xmlns="http://www.msn.com/webservices/AddressBook">
            <abId>00000000-0000-0000-0000-000000000000</abId>
            <contacts>
                <Contact xmlns="http://www.msn.com/webservices/AddressBook">
                    <contactInfo>
                        <contactType>LivePending</contactType>
                        <passportName>$escapedEmail</passportName>
                        <isMessengerUser>true</isMessengerUser>
                    </contactInfo>
                </Contact>
            </contacts>
            <options>
                <EnableAllowListManagement>true</EnableAllowListManagement>
            </options>
        </ABContactAdd>
    </soap:Body>
</soap:Envelope>
''';
  }

  String _buildAbFindAllEnvelope({required String ticket}) {
    final escapedTicket = _escapeXmlText(ticket);
    return '''<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/">
    <soap:Header>
        <ABApplicationHeader xmlns="http://www.msn.com/webservices/AddressBook">
            <ApplicationId>CFE80F9D-180F-4399-82AB-413F33A1FA11</ApplicationId>
            <IsMigration>false</IsMigration>
            <PartnerScenario>Initial</PartnerScenario>
        </ABApplicationHeader>
        <ABAuthHeader xmlns="http://www.msn.com/webservices/AddressBook">
            <ManagedGroupRequest>false</ManagedGroupRequest>
        <TicketToken>$escapedTicket</TicketToken>
        </ABAuthHeader>
    </soap:Header>
    <soap:Body>
        <ABFindAll xmlns="http://www.msn.com/webservices/AddressBook">
            <abId>00000000-0000-0000-0000-000000000000</abId>
            <abView>Full</abView>
            <deltasOnly>false</deltasOnly>
            <lastChange>0001-01-01T00:00:00.0000000-08:00</lastChange>
        </ABFindAll>
    </soap:Body>
</soap:Envelope>
''';
  }

  String? _buildPassportCookie({
    required String? mspAuth,
    required String? mspProf,
    required String? sid,
  }) {
    final parts = <String>[];
    if (mspAuth != null && mspAuth.isNotEmpty) {
      parts.add('MSPAuth=$mspAuth');
    }
    if (mspProf != null && mspProf.isNotEmpty) {
      parts.add('MSPProf=$mspProf');
    }
    if (sid != null && sid.isNotEmpty) {
      parts.add('sid=$sid');
    }
    if (parts.isEmpty) {
      return null;
    }
    return parts.join('; ');
  }

  List<AbchRosterEntry> _parseRoster(String xml, {required String ownerEmail}) {
    final rosterByEmail = <String, AbchRosterEntry>{};
    final owner = ownerEmail.toLowerCase();

    try {
      final document = XmlDocument.parse(xml);
      final contacts = document.descendants.whereType<XmlElement>().where(
        (e) => e.name.local.toLowerCase() == 'contact',
      );

      for (final contact in contacts) {
        final email = _firstElementText(contact, <String>[
          'passportname',
          'email',
          'contactemail',
          'account',
        ]);
        if (email == null || !_looksLikeEmail(email)) {
          continue;
        }

        final displayName =
            _firstElementText(contact, <String>[
              'displayname',
              'name',
              'nickname',
            ]) ??
            email;

        final safeDisplayName = _isLikelyDisplayName(displayName)
            ? displayName
            : email;

        final normalizedEmail = email.toLowerCase();
        if (normalizedEmail == owner || normalizedEmail.contains('hotmail')) {
          continue;
        }

        rosterByEmail[normalizedEmail] = AbchRosterEntry(
          email: normalizedEmail,
          displayName: safeDisplayName,
        );
      }

      if (rosterByEmail.isNotEmpty) {
        return rosterByEmail.values.toList(growable: false);
      }

      // CrossTalk variants can omit Contact nodes; keep a regex fallback for draft compatibility.
      final fallbackEmailRegex = RegExp(
        r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}',
        caseSensitive: false,
      );
      for (final match in fallbackEmailRegex.allMatches(xml)) {
        final email = (match.group(0) ?? '').trim().toLowerCase();
        if (email.isEmpty) {
          continue;
        }
        if (email == owner || email.contains('hotmail')) {
          continue;
        }
        rosterByEmail[email] = AbchRosterEntry(
          email: email,
          displayName: email,
        );
      }
    } catch (_) {
      return const <AbchRosterEntry>[];
    }

    return rosterByEmail.values.toList(growable: false);
  }

  String? _firstElementText(XmlElement root, List<String> candidateNames) {
    final wanted = candidateNames.map((e) => e.toLowerCase()).toSet();
    for (final element in root.descendants.whereType<XmlElement>()) {
      if (!wanted.contains(element.name.local.toLowerCase())) {
        continue;
      }
      final value = element.innerText.trim();
      if (value.isNotEmpty) {
        return _decodeXmlText(value);
      }
    }
    return null;
  }

  bool _looksLikeEmail(String value) {
    return RegExp(
      r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
    ).hasMatch(value);
  }

  bool _isLikelyDisplayName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    if (RegExp(r'^[0-9]{1,3}$').hasMatch(trimmed)) {
      return false;
    }
    return true;
  }

  String _decodeXmlText(String value) {
    return value
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .trim();
  }

  String _compact(String value) {
    return value
        .replaceAll('\r', ' ')
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();
  }

  String _escapeXmlText(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
