# Table of Commands
This is a list of all known MSNP commands and their originating version.

For negative responses to these commands, read the [Error Code and HRESULTs](errors_and_hresults.md) article.

The list is not sorted by any reasonable metric,
but will likely be sorted by originating version and alphabetically when this project is finished.

| `COMMAND` | Payload (Y/N) | Client to Server (Y/N) | Server to Client (Y/N) | Originating Version | Changed? (version list) |
| ------------------------ | - | - | - | -------------------------- | ---- |
| [`VER`](commands/ver.md) | N | Y | N | [MSNP2](versions/msnp2.md) | every MSNP version, but retaining base syntax, removed in MSNP24 |
| [`INF`](commands/inf.md) | N | Y | N | [MSNP2](versions/msnp2.md) | [MSNP3](versions/msnp3.md) (removed CTP), [MSNP8](versions/msnp8.md) (Removed; automatic disconnect) |
| [`CVR`](commands/cvr.md) | N | Y | N | [MSNP2](versions/msnp2.md) | [MSNP4](versions/msnp4.md) (parameter 7), [MSNP8](versions/msnp8.md) (parameter 8) |
| [`CVQ`](commands/cvq.md) | N | Y | N | [CVR0](versions/cvr0.md) | [MSNP4](versions/msnp4.md) (parameter 7, but always empty), [MSNP8](versions/msnp8.md) (fixed parameter 7 being empty, parameter 8	) |
| [`USR`](commands/usr.md) | N | Y | N | [MSNP2](versions/msnp2.md) | [MSNP3](versions/msnp3.md) (Removed `CTP` security package), [MSNP6](versions/msnp6.md) (Added account verified bit to USR OK), [MSNP8](versions/msnp8.md) (Added account restricted bit to USR OK), [MSNP10](versions/msnp10.md) (removed current friendly name in favour of [PRP](commands/prp.md) MFN), (Removed `MD5` security package, added `TWN` security package, added new unknown bit (parameter 5) to USR OK), [MSNP15](versions/msnp15.md) (Added `SSO` security package.) |
| [`XFR`](commands/xfr.md) | N | Y | Y?| [MSNP2](versions/msnp2.md) | [MSNP3](versions/msnp3.md) (XFR NS: parameter 3), [MSNP7](versions/msnp7.md) (XFR NS: parameter 4), [MSNP13](versions/msnp13.md) (XFR NS: replaced parameters 3 and 4 with `U` and `messenger.msn.com`, XFR SB: added parameters 5 and 6, being always `U` and `messenger.msn.com`) |
| [`OUT`](commands/out.md) | N | Y | Y | [MSNP2](versions/msnp2.md) | [MSNP10](versions/msnp10.md) (MIG and TOU disconnect reasons added), [MSNP11](versions/msnp11.md) (RCT reason added with parameter for amount of minutes until attempted reconnect.) |
| [`FND`](commands/fnd.md) | N | Y | N | [MSNP2](versions/msnp2.md) | [MSNP5](versions/msnp5.md) (uses [SDC](commands/sdc.md) instead of [SND](commands/snd.md)), July 2003 (not really any specific MSNP update, just soft-removed with a 502.) |
| [`BLP`](commands/blp.md) | N | Y | Y\*| [MSNP2](versions/msnp2.md) | [MSNP10](versions/msnp10.md) (Removed List Version if `ABCHMigrated: 1`) |
| [`GTC`](commands/gtc.md) | N | Y | Y\*| [MSNP2](versions/msnp2.md) | [MSNP10](versions/msnp10.md) (Removed List Version if `ABCHMigrated: 1`), [MSNP13](versions/msnp13.md) (removed: automatic disconnect) |
| [`CHG`](commands/chg.md) | N | Y | Y | [MSNP2](versions/msnp2.md) | [MSNP8](versions/msnp8.md) (Added Client Capability flags support as parameter 2), [MSNP9](versions/msnp9.md) (MSNObject support as parameter 3) |
| [`IMS`](commands/ims.md) | N | Y | N | [MSNP3](versions/msnp3.md) | |
| [`ACK`](commands/ack.md) | N | N | Y | [MSNP2](versions/msnp2.md) | [MSNP9](versions/msnp9.md) (Now can happen as a response to [MSG](commands/msg.md) D.) |
| [`NAK`](commands/nak.md) | N | N | Y | [MSNP2](versions/msnp2.md) | |
| [`BYE`](commands/bye.md) | N | N | Y | [MSNP2](versions/msnp2.md) | |
| [`ANS`](commands/ans.md) | N | Y | Y | [MSNP2](versions/msnp2.md) | [MSNP16](versions/msnp16.md) (Added MPOP Machine ID appended to the local user's handle parameter, delimited by a semi-colon) |
| [`MSG`](commands/msg.md) | Y | Y | Y | [MSNP2](versions/msnp2.md) | [MSNP9](versions/msnp9.md) (Added Acknowledgement Type D) |
| [`IRO`](commands/iro.md) | N | N | Y | [MSNP2](versions/msnp2.md) | [MSNP12](versions/msnp12.md) (Added Client Capability flags support as parameter 5) |
| [`JOI`](commands/joi.md) | N | N | Y | [MSNP2](versions/msnp2.md) | [MSNP12](versions/msnp12.md) (Added Client Capability flags support as parameter 3) |
| [`CAL`](commands/cal.md) | N | Y | N | [MSNP2](versions/msnp2.md) | |
| [`PRP`](commands/prp.md) | N | Y | N | [MSNP5](versions/msnp5.md) | [MSNP8](versions/msnp8.md) (Removed List Version in [SYN](commands/syn.md)), [MSNP10](versions/msnp10.md) (Removed List Version outside of [SYN](commands/syn.md) if `ABCHMigrated: 1`) |
| [`BPR`](commands/bpr.md) | N | N | Y | [MSNP5](versions/msnp5.md) | [MSNP8](versions/msnp8.md) (Removed List Version and user handle in [SYN](commands/syn.md)), [MSNP10](versions/msnp10.md) (Removed List Version outside of SYN if `ABCHMigrated: 1`) |
| [`RNG`](commands/rng.md) | N | N | Y | [MSNP2](versions/msnp2.md) | [MSNP13](versions/msnp13.md) (Added parameters 8 and 9, one always `U`, one always `messenger.hotmail.com`.) |
| [`LST`](commands/lst.md) | N | Y | Y\*| [MSNP2](versions/msnp2.md) | [MSNP7](versions/msnp7.md) (Added groups support), [MSNP8](versions/msnp8.md) ([SYN](commands/syn.md): removed iterator parameters, condensed all lists into a single parameter, removed List Version), [MSNP10](versions/msnp10.md) (Added prefixes to contact's handle and friendly name, and added a GUID parameter if `ABCHMigrated: 1`. Also changed group IDs to GUIDs.), [MSNP12](versions/msnp12.md) (Added network IDs), [MSNP13](versions/msnp13.md) (Removed; automatic disconnect, use [Address Book Service](services/abservice.md)'s [`ABFindAll`](services/abservice/abfindall.md) and [Contact Sharing Service](services/sharingservice.md)'s [`FindMembership`](services/sharingservice/findmembership.md) instead.), November 2003 (Removed outside of [SYN](commands/syn.md), not really any specific MSNP update, just hard removed with an automatic disconnect.) |
| [`ADD`](commands/add.md) | N | Y | Y | [MSNP2](versions/msnp2.md) | [MSNP7](versions/msnp7.md) (Added groups support), [MSNP10](versions/msnp10.md) (Removed; automatic disconnect, use [ADC](commands/adc.md) instead) |
| [`REM`](commands/rem.md) | N | Y | Y | [MSNP2](versions/msnp2.md) | [MSNP7](versions/msnp7.md) (Added groups support), [MSNP10](versions/msnp10.md) (Replaced user handles with GUIDs if list is the Forward List (FL), and removed list versions from all responses), [MSNP13](versions/msnp13.md) (Removed; automatic disconnect, replaced with RML and [Address Book Service](services/abservice.md)'s [`ABContactDelete`](services/abservice/abcontactdelete.md) and [Contact Sharing Service](services/sharingservice.md)'s [`DeleteMember`](services/sharingservice/deletemember.md) instead) |
| [`FLN`](commands/fln.md) | N | N | Y | [MSNP2](versions/msnp2.md) | [MSNP14](versions/msnp14.md) (Added Network ID parameter, Client Capabilities parameter and optional Presence Icon URL parameter), [MSNP16](versions/msnp16.md) (Added support for the Extended Client Capabilities, changing the original Client Capabilities parameter to now be delimited by a colon) |
| [`PNG`](commands/png.md) | N | Y | N | [MSNP2](versions/msnp2.md) | |
| [`QNG`](commands/qng.md) | N | N | Y | [MSNP2](versions/msnp2.md) | [MSNP9](versions/msnp9.md) (Added next seconds parameter) |
| [`URL`](commands/url.md) | N | Y | N | [MSNP2](versions/msnp2.md) | [MSNP3](versions/msnp3.md) (Added Passport Site ID support as parameter 3), removed `PASSWORD` service), [MSNP5](versions/msnp5.md) (Added `MOBILE` and `CHGMOB` services), [MSNP6](versions/msnp6.md) (Added `PROFILE`, `N2PACCOUNT` and `N2PFUND` services), [MSNP7](versions/msnp7.md) (Added `CHAT` service), [MSNP8](versions/msnp8.md) (Added `ADDRBOOK`, `ADVSEARCH` and `INTSEARCH` services) |
| [`LSG`](commands/lsg.md) | N | Y | Y\*| [MSNP7](versions/msnp7.md) | [MSNP8](versions/msnp8.md) (Removed iterator and List Version parameters from [SYN](commands/syn.md) version), [MSNP10](versions/msnp10.md) (Removed unused parameter, and replaced Group IDs with Group GUIDs if `ABCHMigrated: 1`.), [MSNP13](versions/msnp13.md) (Removed; automatic disconnect, use [Address Book Service](services/abservice.md)'s [`ABFindAll`](services/abservice/abfindall.md) instead.) November 2003 (Removed outside of [SYN](commands/syn.md), not really any specific MSNP update, just hard removed with an automatic disconnect.) |
| [`ADG`](commands/adg.md) | N | Y | N | [MSNP7](versions/msnp7.md) | [MSNP10](versions/msnp10.md) (Removed unused `0` and List Version parameters, and replaced Group IDs with Group GUIDs if `ABCHMigrated: 1`), [MSNP13](versions/msnp13.md) (Removed; automatic disconnect?, use [Address Book Service](services/abservice.md) [`ABGroupAdd`](services/abservice/abgroupadd.md) instead.) |
| [`ILN`](commands/iln.md) | N | N | Y | [MSNP2](versions/msnp2.md) | [MSNP8](versions/msnp8.md) (Added support for Client Capabilities), [MSNP9](versions/msnp9.md) (Added optional MSNObject parameter), [MSNP14](versions/msnp14.md) (Added Network ID parameter and optional Presence Icon URL parameter), [MSNP16](versions/msnp16.md) (Added support for the Extended Client Capabilities, changing the original Client Capabilities parameter to now be delimited by a colon) |
| [`NLN`](commands/nln.md) | N | N | Y | [MSNP2](versions/msnp2.md) | [MSNP8](versions/msnp8.md) (Added support for Client Capabilities), [MSNP9](versions/msnp9.md) (Added optional MSNObject parameter), [MSNP14](versions/msnp14.md) (Added Network ID parameter and optional Presence Icon URL parameter), [MSNP16](versions/msnp16.md) (Added support for the Extended Client Capabilities, changing the original Client Capabilities parameter to now be delimited by a colon) |
| [`REA`](commands/rea.md) | N | Y | N | [MSNP2](versions/msnp2.md) | [MSNP10](versions/msnp10.md) (Removed; automatic disconnect) |
| [`SND`](commands/snd.md) | N | Y | N | [MSNP2](versions/msnp2.md) | [MSNP3](versions/msnp3.md) (parameters 2 and 3), [MSNP4](versions/msnp4.md) (parameter 4), [MSNP5](versions/msnp5.md) (obsoleted by [SDC](commands/sdc.md)) |
| [`SDC`](commands/sdc.md) | Y | Y | N | [MSNP5](versions/msnp5.md) | |
| [`ADC`](commands/adc.md) | N | Y | Y | [MSNP10](versions/msnp10.md) | [MSNP10](versions/msnp10.md) (`ABCHMigrated: 1`: Contact user handles and Group IDs are now both GUIDs.), [MSNP13](versions/msnp13.md) (Removed; automatic disconnect, use ADL and the [Address Book Service](services/abservice.md)'s [`ABContactAdd`](services/abservice/abcontactadd.md) and [Contact Sharing Service](services/sharingservice.md)'s [`AddMember`](services/sharingservice/addmember.md) instead) |
| [`PAG`](commands/pag.md) | Y | Y | N | [MSNP5](versions/msnp5.md) | [MSNP9](versions/msnp9.md) (Removed; error 715, use [PGD](commands/pgd.md) instead.) |
| [`PGD`](commands/pgd.md) | Y | Y | N | [MSNP9](versions/msnp9.md) | |
| [`SBP`](commands/sbp.md) | N | Y | N | [MSNP10](versions/msnp10.md) | [MSNP10](versions/msnp10.md) (`ABCHMigrated: 1`: Contact user handles are now GUIDs.), [MSNP11](versions/msnp11.md) (Added property `HSB`, for Has Blog. Set by the relevant Client Capability.), [MSNP13](versions/msnp13.md) (Removed; automatic disconnect, use [Address Book Service](services/abservice.md)'s [`ABContactUpdate`](services/abservice/abcontactupdate.md) action instead.) |
| [`CHL`](commands/chl.md) | N | Y | Y | [MSNP6](versions/msnp6.md) | [MSNP10](versions/msnp10.md) (Changed challenge response ([QRY](commands/qry.md) commands) generation algorithm drastically.) |
| [`GCF`](commands/gcf.md) | Y | Y | Y | [MSNP11](versions/msnp11.md) | [MSNP13](versions/msnp13.md) (Command is now always asynchronous and always returns `Shields.xml` in a new container.) |
| [`SYN`](commands/syn.md) | N | Y | N | [MSNP2](versions/msnp2.md) | [MSNP5](versions/msnp5.md) (Added [BPR](commands/bpr.md) and [PRP](commands/prp.md) to response.), [MSNP7](versions/msnp7.md) (Added [LSG](commands/lsg.md) support and groups in [LST](commands/lst.md).), [MSNP8](versions/msnp8.md) (Unset properties are now omitted, new response parameters to replace [LSG](commands/lsg.md) and [LST](commands/lst.md) iterator parameters, Transaction IDs and List Version was removed from used commands), [MSNP10](versions/msnp10.md) (Added new parameters for the settings version. With `ABCHMigrated: 1`, both versions are now timestamps), [MSNP12](versions/msnp12.md) (Added Network IDs to [LST](commands/lst.md).), [MSNP13](versions/msnp13.md) (Removed; automatic disconnect, use the [Address Book Service](services/abservice.md) and the [Contact Sharing Service](services/sharingservice.md) instead.) |
| [`NOT`](commands/not.md) | Y | N | Y | [MSNP5](versions/msnp5.md) | [MSNP9](versions/msnp9.md) (Added support for extended notifications using the `<TEXTX>` element), [MSNP11](versions/msnp11.md) (Added support for the `<NotificationData>` sub-document, and live blog updates use the new sub-document.), [MSNP13](versions/msnp13.md) (Added live contact list updates using the `<NotificationData>` subdocument.), [MSNP18](versions/msnp18.md) (Added live persistent chat group updates using the `<NotificationData>` subdocument.) |
| [`IPG`](commands/ipg.md) | Y | N | Y | [MSNP6](versions/msnp6.md) | |
| [`REG`](commands/reg.md) | N | Y | N | [MSNP7](versions/msnp7.md) | [MSNP10](versions/msnp10.md) (Removed unused `0` and List Version parameters, with `ABCHMigrated: 1`, group IDs are instead group GUIDs), [MSNP13](versions/msnp13.md) (Removed; automatic disconnect, use [Address Book Service](services/abservice.md)'s [`ABGroupUpdate`](services/abservice/abgroupupdate.md) instead.) |
| [`RMG`](commands/rmg.md) | N | Y | N | [MSNP7](versions/msnp7.md) | [MSNP10](versions/msnp10.md) (Removed List Version parameter, with `ABCHMigrated: 1`, group IDs are instead group GUIDs), [MSNP13](versions/msnp13.md) (Removed; automatic disconnect, use [Address Book Service](services/abservice.md)'s [`ABGroupDelete`](services/abservice/abgroupdelete.md) instead.) |
| [`QRY`](commands/qry.md) | Y | Y | N | [MSNP6](versions/msnp6.md) | [MSNP10](versions/msnp10.md) (Changed challenge response generation algorithm drastically.) |
| [`UBX`](commands/ubx.md) | Y | N | Y | [MSNP11](versions/msnp11.md) | [MSNP13](versions/msnp13.md) (Added `<MachineGuid>` to the default list of elements.) |
| [`UUX`](commands/uux.md) | Y | Y | N | [MSNP11](versions/msnp11.md) | [MSNP13](versions/msnp13.md) (Added `<MachineGuid>` to the default list of elements.), [MSNP14](versions/msnp14.md) (Added support for Network IDs.) |
| [`ADL`](commands/adl.md) | Y | Y | Y | [MSNP13](versions/msnp13.md) | [MSNP17](versions/msnp17.md) (Now can manage circles.) |
| [`RML`](commands/rml.md) | Y | Y | Y | [MSNP13](versions/msnp13.md) | [MSNP17](versions/msnp17.md) (Now can manage circles.) |
| [`FQY`](commands/fqy.md) | Y | Y | N | [MSNP14](versions/msnp14.md) | |

# What's Missing Right Now

## In general
* [MSNP11](versions/msnp11.md): GSB
* [MSNP11](versions/msnp11.md): SBS
* [MSNP12](versions/msnp12.md): LKP
* [MSNP13](versions/msnp13.md): RFS
* [MSNP13](versions/msnp13.md): UBN
* [MSNP13](versions/msnp13.md): UUN
* [MSNP14](versions/msnp14.md): UBM
* [MSNP14](versions/msnp14.md): UUM

# Modifiers
* `*`: Only in [SYN](commands/syn.md).
* `?`: Unconfirmed, but not impossible, or needs verification.
