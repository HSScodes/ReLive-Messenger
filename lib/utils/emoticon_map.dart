/// WLM 2009 emoticon short-code → sprite-sheet index mapping.
///
/// Sprite: `assets/images/app/ui/carved_png_9495208.png`
/// Dimensions: 1520×19  (80 cells, each 19×19 px).
library;

const String emoticonSpriteAsset =
    'assets/images/app/ui/carved_png_9495208.png';

const double emoticonCellSize = 19;
const int emoticonCount = 80;

/// Each entry maps one or more short-codes to the 0-based column index in the
/// sprite sheet. The first code in each list is the "canonical" code shown in
/// the picker tooltip.
const List<EmoticonDef> emoticonDefs = [
  // ── Default emoticons (0–46) ──────────────────────────
  // Order matches the WLM 2009 sprite sheet (carved_png_9495208.png)
  // left-to-right, verified against the official picker layout.
  EmoticonDef(0, [':)', ':-)'], 'Smile'),
  EmoticonDef(1, [':D', ':-D', ':d', ':-d'], 'Open-mouthed'),
  EmoticonDef(2, [';)', ';-)'], 'Wink'),
  EmoticonDef(3, [':O', ':-O', ':o', ':-o'], 'Surprised'),
  EmoticonDef(4, [':P', ':-P', ':p', ':-p'], 'Tongue out'),
  EmoticonDef(5, ['(H)', '(h)'], 'Hot'),
  EmoticonDef(6, [':@', ':-@'], 'Angry'),
  EmoticonDef(7, [r':$', r':-$'], 'Embarrassed'),
  EmoticonDef(8, [':S', ':-S', ':s', ':-s'], 'Confused'),
  EmoticonDef(9, [':(', ':-('], 'Sad'),
  EmoticonDef(10, [":'("], 'Crying'),
  EmoticonDef(11, [':|', ':-|'], 'Disappointed'),
  EmoticonDef(12, ['(6)'], 'Devil'),
  EmoticonDef(13, ['(A)', '(a)'], 'Angel'),
  EmoticonDef(14, ['(L)', '(l)'], 'Red heart'),
  EmoticonDef(15, ['(U)', '(u)'], 'Broken heart'),
  EmoticonDef(16, ['(M)', '(m)'], 'MSN Messenger icon'),
  EmoticonDef(17, ['(@)'], 'Cat face'),
  EmoticonDef(18, ['(&)'], 'Dog face'),
  EmoticonDef(19, ['(S)', '(s)'], 'Sleeping half-moon'),
  EmoticonDef(20, ['(*)'], 'Star'),
  EmoticonDef(21, ['(~)'], 'Filmstrip'),
  EmoticonDef(22, ['(8)'], 'Note'),
  EmoticonDef(23, ['(E)', '(e)'], 'E-mail'),
  EmoticonDef(24, ['(F)', '(f)'], 'Red rose'),
  EmoticonDef(25, ['(W)', '(w)'], 'Wilted rose'),
  EmoticonDef(26, ['(O)', '(o)'], 'Clock'),
  EmoticonDef(27, ['(K)', '(k)'], 'Red lips'),
  EmoticonDef(28, ['(G)', '(g)'], 'Gift with a bow'),
  EmoticonDef(29, ['(^)'], 'Birthday cake'),
  EmoticonDef(30, ['(P)', '(p)'], 'Camera'),
  EmoticonDef(31, ['(I)', '(i)'], 'Light bulb'),
  EmoticonDef(32, ['(C)', '(c)'], 'Coffee cup'),
  EmoticonDef(33, ['(T)', '(t)'], 'Telephone receiver'),
  EmoticonDef(34, ['({)'], 'Left hug'),
  EmoticonDef(35, ['(})'], 'Right hug'),
  EmoticonDef(36, ['(B)', '(b)'], 'Beer mug'),
  EmoticonDef(37, ['(D)', '(d)'], 'Martini glass'),
  EmoticonDef(38, ['(Z)', '(z)'], 'Boy'),
  EmoticonDef(39, ['(Y)', '(y)'], 'Thumbs up'),
  EmoticonDef(40, ['(N)', '(n)'], 'Thumbs down'),
  EmoticonDef(41, [':-[', ':['], 'Vampire bat'),
  EmoticonDef(42, ['(nnh)'], 'Nyah-nyah'),
  EmoticonDef(43, ['(#)', '(%)'], 'Handcuffs'),
  EmoticonDef(44, ['(R)', '(r)'], 'Rainbow'),
  EmoticonDef(45, [':-#'], "Don't tell anyone"),
  EmoticonDef(46, ['8o|'], 'Baring teeth'),
  // ── Hidden emoticons (47–79) ──────────────────────────
  EmoticonDef(47, ['8-|'], 'Nerd'),
  EmoticonDef(48, ['^o)'], 'Sarcastic'),
  EmoticonDef(49, [':-*'], 'Secret telling'),
  EmoticonDef(50, ['+o('], 'Sick'),
  EmoticonDef(51, ['(sn)'], 'Snail'),
  EmoticonDef(52, ['(tu)'], 'Turtle'),
  EmoticonDef(53, ['(pl)'], 'Plate'),
  EmoticonDef(54, ['(||)'], 'Bowl'),
  EmoticonDef(55, ['(pi)'], 'Pizza'),
  EmoticonDef(56, ['(so)'], 'Soccer ball'),
  EmoticonDef(57, ['(au)'], 'Auto'),
  EmoticonDef(58, ['(ap)'], 'Airplane'),
  EmoticonDef(59, ['(um)'], 'Umbrella'),
  EmoticonDef(60, ['(ip)'], 'Island with a palm tree'),
  EmoticonDef(61, ['(co)'], 'Computer'),
  EmoticonDef(62, ['(mp)'], 'Mobile Phone'),
  EmoticonDef(63, ['(brb)'], 'Be right back'),
  EmoticonDef(64, ['(st)'], 'Stormy cloud'),
  EmoticonDef(65, ['(h5)'], 'High five'),
  EmoticonDef(66, ['(mo)'], 'Money'),
  EmoticonDef(67, ['(bah)'], 'Black Sheep'),
  EmoticonDef(68, [':^)'], "I don't know"),
  EmoticonDef(69, ['*-)'], 'Thinking'),
  EmoticonDef(70, ['(li)'], 'Lightning'),
  EmoticonDef(71, ['<:o)'], 'Party'),
  EmoticonDef(72, ['8-)'], 'Eye-rolling'),
  EmoticonDef(73, ['|-)'], 'Sleepy'),
  EmoticonDef(74, ["(':)"], 'Shhh'),
  EmoticonDef(75, ['~x('], 'Angry face'),
  EmoticonDef(76, ['(nah)'], 'Nah'),
  EmoticonDef(77, ['(yn)'], 'Fingers crossed'),
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
final Map<String, int> _codeToIndex = () {
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
final List<String> allEmoticonCodes = () {
  final codes = _codeToIndex.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  return codes;
}();
