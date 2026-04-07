# Introduction
MSNP2 is the first released version of the Mobile Status Notification Protocol.  
It was introduced officially in Client Version 1.0.0863, along with [CVR0](cvr0.md).

# Command information
It introduces the dispatch service commands:
* [INF](../commands/inf.md)
* [OUT](../commands/out.md)
* [USR](../commands/usr.md)
* [VER](../commands/ver.md)
* [XFR](../commands/xfr.md)

It introduces the notification service commands:
* [ADD](../commands/add.md)
* [BLP](../commands/blp.md)
* [CHG](../commands/chg.md)
* [CVR](../commands/cvr.md) (not in draft, [deliberate omission](https://datatracker.ietf.org/doc/html/draft-movva-msn-messenger-protocol-00#section-3))
* [FND](../commands/fnd.md) (not in draft, [deliberate omission](https://datatracker.ietf.org/doc/html/draft-movva-msn-messenger-protocol-00#section-3))
* [FLN](../commands/fln.md)
* [GTC](../commands/gtc.md)
* [INF](../commands/inf.md)
* [ILN](../commands/iln.md)
* [LST](../commands/lst.md)
* [MSG](../commands/msg.md)
* [NLN](../commands/nln.md)
* [OUT](../commands/out.md)
* [PNG](../commands/png.md) (not in draft)
* [QNG](../commands/qng.md) (not in draft)
* [REA](../commands/rea.md) (not in draft, [despite alluding to it](https://datatracker.ietf.org/doc/html/draft-movva-msn-messenger-protocol-00#section-5.5))
* [REM](../commands/rem.md)
* [RNG](../commands/rng.md)
* [SND](../commands/snd.md) (not in draft)
* [SYN](../commands/syn.md)
* [URL](../commands/url.md) (not in draft)
* [USR](../commands/usr.md)
* [VER](../commands/ver.md)
* [XFR](../commands/xfr.md)

It introduces the switchboard service commands:
* [ACK](../commands/ack.md)
* [ANS](../commands/ans.md)
* [BYE](../commands/bye.md)
* [CAL](../commands/cal.md)
* [IRO](../commands/iro.md)
* [JOI](../commands/joi.md)
* [MSG](../commands/msg.md)
* [NAK](../commands/nak.md)
* [OUT](../commands/out.md)
* [USR](../commands/usr.md)

*No commands were known to be removed in this version.*

# Known changes
(from Beta 2)
* Dispatch Servers now go through the normal logon procedure until `USR TrID MD5 I user-handle`.

# Client-server communication example
```msnp
C: VER 1 MSNP2 CVR0
S: VER 1 MSNP2
C: INF 2
S: INF 2 MD5
C: USR 3 MD5 I example@hotmail.com
S: XFR 3 NS 10.0.0.5:1863
```
Client disconnects from server.

Client opens a connection to `10.0.0.5:1863`.
```msnp
C: VER 4 MSNP2 CVR0
S: VER 4 MSNP2
C: INF 5
S: INF 5 MD5
C: USR 6 MD5 I example@hotmail.com
S: USR 6 MD5 S prefix
C: USR 7 MD5 S $md5(prefix + password)
S: USR 7 OK example@hotmail.com example%40hotmail.com
S: MSG Hotmail Hotmail 95
MIME-Version: 1.0
Content-Type: text/x-msmsgsprofile; charset=UTF-8
LoginTime: 1726321960

C: SYN 8 0
S: SYN 8 1
S: GTC 8 1 A
S: BLP 8 1 AL
S: LST 8 FL 1 0 0
S: LST 8 AL 1 0 0
S: LST 8 BL 1 0 0
S: LST 8 RL 1 0 0
C: CHG 9 NLN
S: CHG 9 NLN
C: ADD 10 AL anotheruser@hotmail.com anotheruser%40hotmail.com
S: ADD 10 AL 2 anotheruser@hotmail.com anotheruser%40hotmail.com
C: ADD 11 FL anotheruser@hotmail.com anotheruser%40hotmail.com
S: ADD 11 FL 3 anotheruser@hotmail.com anotheruser%40hotmail.com
S: NLN NLN anotheruser@hotmail.com another%20user
C: REA 12 anotheruser@hotmail.com another%20user
S: REA 12 4 anotheruser@hotmail.com another%20user
C: REA 13 example@hotmail.com example%20user
S: REA 13 5 example@hotmail.com example%20user
S: FLN anotheruser@hotmail.com
C: OUT
```
Client disconnects from server.  
Server disconnects client.
