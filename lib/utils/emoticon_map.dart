/// WLM 2009 emoticon short-code → sprite-sheet index mapping.
///
/// Sprite: `assets/images/extracted/msgsres/carved_png_9495208.png`
/// Dimensions: 1520×19  (80 cells, each 19×19 px).
library;

const String emoticonSpriteAsset =
    'assets/images/extracted/msgsres/carved_png_9495208.png';

const double emoticonCellSize = 19;
const int emoticonCount = 80;

/// Each entry maps one or more short-codes to the 0-based column index in the
/// sprite sheet. The first code in each list is the "canonical" code shown in
/// the picker tooltip.
const List<EmoticonDef> emoticonDefs = [
  // ── Face emoticons (0–24) ─────────────────────────────
  // Order matches the official Microsoft emoticons page
  // (messenger.msn.com/Resource/Emoticons.aspx) and the
  // WLM 2009 sprite sheet cell layout left-to-right.
  EmoticonDef(0, [':)', ':-)'], 'Smile'),
  EmoticonDef(1, [':D', ':-D', ':d', ':-d'], 'Open-mouthed'),
  EmoticonDef(2, [':O', ':-O', ':o', ':-o'], 'Surprised'),
  EmoticonDef(3, [':P', ':-P', ':p', ':-p'], 'Tongue out'),
  EmoticonDef(4, [';)', ';-)'], 'Wink'),
  EmoticonDef(5, [':(', ':-('], 'Sad'),
  EmoticonDef(6, [':S', ':-S', ':s', ':-s'], 'Confused'),
  EmoticonDef(7, [':|', ':-|'], 'Disappointed'),
  EmoticonDef(8, [":'("], 'Crying'),
  EmoticonDef(9, [r':$', r':-$'], 'Embarrassed'),
  EmoticonDef(10, ['(H)', '(h)'], 'Hot'),
  EmoticonDef(11, [':@', ':-@'], 'Angry'),
  EmoticonDef(12, ['(A)', '(a)'], 'Angel'),
  EmoticonDef(13, ['(6)'], 'Devil'),
  EmoticonDef(14, [':-#'], "Don't tell anyone"),
  EmoticonDef(15, ['8o|'], 'Baring teeth'),
  EmoticonDef(16, ['8-|'], 'Nerd'),
  EmoticonDef(17, ['^o)'], 'Sarcastic'),
  EmoticonDef(18, [':-*'], 'Secret telling'),
  EmoticonDef(19, ['+o('], 'Sick'),
  EmoticonDef(20, [':^)'], "I don't know"),
  EmoticonDef(21, ['*-)'], 'Thinking'),
  EmoticonDef(22, ['<:o)'], 'Party'),
  EmoticonDef(23, ['8-)'], 'Eye-rolling'),
  EmoticonDef(24, ['|-)'], 'Sleepy'),
  // ── Object / symbol emoticons (25–68) ─────────────────
  EmoticonDef(25, ['(C)', '(c)'], 'Coffee cup'),
  EmoticonDef(26, ['(Y)', '(y)'], 'Thumbs up'),
  EmoticonDef(27, ['(N)', '(n)'], 'Thumbs down'),
  EmoticonDef(28, ['(B)', '(b)'], 'Beer mug'),
  EmoticonDef(29, ['(D)', '(d)'], 'Martini glass'),
  EmoticonDef(30, ['(X)', '(x)'], 'Girl'),
  EmoticonDef(31, ['(Z)', '(z)'], 'Boy'),
  EmoticonDef(32, ['({)'], 'Left hug'),
  EmoticonDef(33, ['(})'], 'Right hug'),
  EmoticonDef(34, [':-[', ':['], 'Vampire bat'),
  EmoticonDef(35, ['(^)'], 'Birthday cake'),
  EmoticonDef(36, ['(L)', '(l)'], 'Red heart'),
  EmoticonDef(37, ['(U)', '(u)'], 'Broken heart'),
  EmoticonDef(38, ['(K)', '(k)'], 'Red lips'),
  EmoticonDef(39, ['(G)', '(g)'], 'Gift with a bow'),
  EmoticonDef(40, ['(F)', '(f)'], 'Red rose'),
  EmoticonDef(41, ['(W)', '(w)'], 'Wilted rose'),
  EmoticonDef(42, ['(P)', '(p)'], 'Camera'),
  EmoticonDef(43, ['(~)'], 'Filmstrip'),
  EmoticonDef(44, ['(@)'], 'Cat face'),
  EmoticonDef(45, ['(&)'], 'Dog face'),
  EmoticonDef(46, ['(T)', '(t)'], 'Telephone receiver'),
  EmoticonDef(47, ['(I)', '(i)'], 'Light bulb'),
  EmoticonDef(48, ['(8)'], 'Note'),
  EmoticonDef(49, ['(S)', '(s)'], 'Sleeping half-moon'),
  EmoticonDef(50, ['(*)'], 'Star'),
  EmoticonDef(51, ['(E)', '(e)'], 'E-mail'),
  EmoticonDef(52, ['(O)', '(o)'], 'Clock'),
  EmoticonDef(53, ['(M)', '(m)'], 'MSN Messenger icon'),
  EmoticonDef(54, ['(sn)'], 'Snail'),
  EmoticonDef(55, ['(bah)'], 'Black Sheep'),
  EmoticonDef(56, ['(pl)'], 'Plate'),
  EmoticonDef(57, ['(||)'], 'Bowl'),
  EmoticonDef(58, ['(pi)'], 'Pizza'),
  EmoticonDef(59, ['(so)'], 'Soccer ball'),
  EmoticonDef(60, ['(au)'], 'Auto'),
  EmoticonDef(61, ['(ap)'], 'Airplane'),
  EmoticonDef(62, ['(um)'], 'Umbrella'),
  EmoticonDef(63, ['(ip)'], 'Island with a palm tree'),
  EmoticonDef(64, ['(co)'], 'Computer'),
  EmoticonDef(65, ['(mp)'], 'Mobile Phone'),
  EmoticonDef(66, ['(st)'], 'Stormy cloud'),
  EmoticonDef(67, ['(li)'], 'Lightning'),
  EmoticonDef(68, ['(mo)'], 'Money'),
  // ── Hidden emoticons (69–79) ──────────────────────────
  EmoticonDef(69, ['(brb)'], 'Be right back'),
  EmoticonDef(70, ['(yn)'], 'Fingers crossed'),
  EmoticonDef(71, ['(h5)'], 'High five'),
  EmoticonDef(72, ['(tu)'], 'Turtle'),
  EmoticonDef(73, ['(%)'], 'Handcuffs'),
  EmoticonDef(74, ['(R)', '(r)'], 'Rainbow'),
  EmoticonDef(75, ['~x('], 'Angry face'),
  EmoticonDef(76, ['(nah)'], 'Nah'),
  EmoticonDef(77, ['(ci)'], 'Cigarette'),
  EmoticonDef(78, ['(xx)'], 'Xbox'),
  EmoticonDef(79, ['(pp)'], 'Paw print'),
];

class EmoticonDef {
  const EmoticonDef(this.index, this.codes, this.name);
  final int index;
  final List<String> codes;
  final String name;
}

/// Lazily built shortcode → index lookup (case-sensitive because WLM codes
/// are case-sensitive between e.g. (L) / (l)).
late final Map<String, int> _codeToIndex = () {
  final map = <String, int>{};
  for (final def in emoticonDefs) {
    for (final code in def.codes) {
      map[code] = def.index;
    }
  }
  return map;
}();

/// Returns the sprite index for [code], or null if not a known emoticon.
int? emoticonIndex(String code) => _codeToIndex[code];

/// All known shortcodes sorted longest-first (for greedy matching).
late final List<String> allEmoticonCodes = () {
  final codes = _codeToIndex.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  return codes;
}();
