import 'package:flutter/services.dart' show rootBundle, AssetManifest;

/// Langues de Lexika. `tts` = locale utilisée pour la voix de synthèse.
/// `nativeVoice` = false quand aucune voix native n'existe (voix approchante).
class Lang {
  final String code, name, flag, tts;
  final bool nativeVoice;
  const Lang(this.code, this.name, this.flag, this.tts, {this.nativeVoice = true});
}

const langs = <Lang>[
  Lang('fr', 'Français (France)', '🇫🇷', 'fr-FR'),
  Lang('ln', 'Lingala', '🇨🇩', 'fr-FR', nativeVoice: false),
  Lang('en_US', 'English (US)', '🇺🇸', 'en-US'),
  Lang('en_GB', 'English (UK)', '🇬🇧', 'en-GB'),
  Lang('sw', 'Kiswahili (RDC)', '🇨🇩', 'sw-KE'),
  Lang('lua', 'Tshiluba (RDC)', '🇨🇩', 'fr-FR', nativeVoice: false),
  Lang('kg', 'Kikongo (RDC)', '🇨🇩', 'fr-FR', nativeVoice: false),
  Lang('es', 'Español', '🇪🇸', 'es-ES'),
  Lang('pt', 'Português', '🇵🇹', 'pt-PT'),
  Lang('de', 'Deutsch', '🇩🇪', 'de-DE'),
  Lang('wa', 'Wallon', '🇧🇪', 'fr-BE', nativeVoice: false),
  Lang('nl_BE', 'Vlaams (Flamand)', '🇧🇪', 'nl-BE'),
  Lang('en_SL', 'English Slang', '😎', 'en-US'),
  Lang('fr_SL', 'Argot français', '🥖', 'fr-FR'),
  Lang('af', 'Afrikaans', '🇿🇦', 'af-ZA'),
  Lang('eo', 'Esperanto', '🟢', 'it-IT', nativeVoice: false),
  Lang('ru', 'Русский (Russe)', '🇷🇺', 'ru-RU'),
  Lang('zu', 'isiZulu (Zoulou)', '🇿🇦', 'sw-KE', nativeVoice: false),
];

Lang langOf(String code) => langs.firstWhere((l) => l.code == code, orElse: () => langs.first);

class Entry {
  final String id, cat, emoji, example;
  final Map<String, String> t;
  Entry(this.id, this.cat, this.emoji, this.example, this.t);

  /// Le mot dans une langue, ou null s'il n'est pas encore disponible.
  String? w(String code) {
    final v = t[code]?.trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  /// Prononciation et phrase d'exemple dans une langue, si disponibles.
  Extra? x(String code) => extras['$code/$id'];

  /// Définition (en français), si disponible.
  String? get definition => definitions[id];

  /// Définition anglaise (Webster), si disponible.
  String? get definitionEn => definitionsEn[id];

  /// Maana ya Kiswahili (kamusi), si disponible.
  String? get definitionSw => definitionsSw[id];
}

/// Prononciation figurée et phrase d'exemple (avec sa traduction française) d'un mot dans une langue.
class Extra {
  final String pron, example, exampleFr;
  const Extra(this.pron, this.example, this.exampleFr);
}

List<Entry> entries = [];
Map<String, Extra> extras = {};
Map<String, String> definitions = {};
Map<String, String> definitionsEn = {};
Map<String, String> definitionsSw = {};
final Map<String, String> _audio = {};

/// Chemin de l'enregistrement natif (assets/audio/<langue>/<id>.mp3), ou null.
String? audioPath(String lang, String id) => _audio['$lang/$id'];
bool hasAudio(String lang, String id) => _audio.containsKey('$lang/$id');

/// Charge le dictionnaire, les définitions et la liste des enregistrements.
Future<void> loadEntries() async {
  final raw = await rootBundle.loadString('assets/dictionary.txt');
  final out = <Entry>[];
  for (final line in raw.split('\n')) {
    final l = line.trim();
    if (l.isEmpty || l.startsWith('#')) continue;
    final p = _pad(l.split('|'));
    if (p.length != _cols) continue;
    out.add(_make(p));
  }
  entries = out;

  final defs = <String, String>{};
  try {
    final d = await rootBundle.loadString('assets/definitions.txt');
    for (final line in d.split('\n')) {
      final l = line.trim();
      if (l.isEmpty || l.startsWith('#')) continue;
      final i = l.indexOf('|');
      if (i > 0) defs[l.substring(0, i)] = l.substring(i + 1).trim();
    }
  } catch (_) {}
  definitions = defs;

  final en = <String, String>{};
  try {
    final d = await rootBundle.loadString('assets/definitions_en.txt');
    for (final line in d.split('\n')) {
      final l = line.trim();
      if (l.isEmpty || l.startsWith('#')) continue;
      final i = l.indexOf('|');
      if (i > 0) en[l.substring(0, i)] = l.substring(i + 1).trim();
    }
  } catch (_) {}
  definitionsEn = en;

  final sw = <String, String>{};
  try {
    final d = await rootBundle.loadString('assets/definitions_sw.txt');
    for (final line in d.split('\n')) {
      final l = line.trim();
      if (l.isEmpty || l.startsWith('#')) continue;
      final i = l.indexOf('|');
      if (i > 0) sw[l.substring(0, i)] = l.substring(i + 1).trim();
    }
  } catch (_) {}
  definitionsSw = sw;

  final ex = <String, Extra>{};
  try {
    final d = await rootBundle.loadString('assets/extras.txt');
    for (final line in d.split('\n')) {
      final l = line.trim();
      if (l.isEmpty || l.startsWith('#')) continue;
      final p = l.split('|');
      if (p.length < 5) continue;
      ex['${p[1]}/${p[0]}'] = Extra(p[2].trim(), p[3].trim(), p[4].trim());
    }
  } catch (_) {}
  extras = ex;

  _audio.clear();
  try {
    final m = await AssetManifest.loadFromAssetBundle(rootBundle);
    for (final k in m.listAssets()) {
      if (!k.startsWith('assets/audio/')) continue;
      final rest = k.substring('assets/audio/'.length);
      final slash = rest.indexOf('/');
      if (slash < 0) continue;
      final name = rest.substring(slash + 1);
      final dot = name.lastIndexOf('.');
      if (dot <= 0) continue;
      _audio['${rest.substring(0, slash)}/${name.substring(0, dot)}'] = k;
    }
  } catch (_) {}
}

int get _cols => 4 + langs.length;

/// Ancien format (14 langues) : complété par des cases vides pour les langues ajoutées depuis.
const _legacyCols = 18;
List<String> _pad(List<String> p) =>
    p.length == _legacyCols ? [...p, for (var i = _legacyCols; i < _cols; i++) ''] : p;

Entry _make(List<String> p) => Entry(p[0], p[1], p[2], p[3], {
      for (var i = 0; i < langs.length; i++) langs[i].code: p[4 + i].trim(),
    });

// ───────────────────────── Import de mots ─────────────────────────
class ImportResult {
  final int added, updated, skipped;
  final List<String> lines; // lignes valides (format « | »), à mémoriser
  ImportResult(this.added, this.updated, this.skipped, this.lines);
}

/// Fusionne une ligne : ajoute l'entrée, ou complète les cases vides/modifie les mots d'une entrée existante.
/// Retourne 1 si ajout, 2 si mise à jour, 0 sinon.
int _merge(List<String> p) {
  final id = p[0].trim().toLowerCase().replaceAll(' ', '_');
  if (id.isEmpty) return 0;
  for (final e in entries) {
    if (e.id == id) {
      var changed = false;
      for (var i = 0; i < langs.length; i++) {
        final v = p[4 + i].trim();
        if (v.isNotEmpty && e.t[langs[i].code] != v) {
          e.t[langs[i].code] = v;
          changed = true;
        }
      }
      return changed ? 2 : 0;
    }
  }
  final q = [...p]..[0] = id;
  entries.add(_make(q));
  return 1;
}

List<String>? _split(String line) {
  for (final d in ['|', ';', '\t', ',']) {
    final p = _pad(line.split(d));
    if (p.length == _cols) {
      return p.map((s) {
        var v = s.trim();
        if (v.length >= 2 && v.startsWith('"') && v.endsWith('"')) v = v.substring(1, v.length - 1);
        return v.replaceAll('|', '/');
      }).toList();
    }
  }
  return null;
}

/// Importe du texte CSV / TXT. Formats acceptés :
///  • le format interne (id, catégorie, emoji, exemple + un mot par langue) ;
///  • tout CSV avec une ligne d'en-tête nommant les colonnes : « Français;Lingala », « lingala;prononciation;
///    francais;theme;exemple_phrase », « Code langue;Langue;Français;Traduction »… (séparateur | ; tabulation ou virgule) ;
///  • sans en-tête : « français ; traduction » avec la langue choisie dans [defaultLang].
ImportResult importText(String text, {String? defaultLang}) {
  final clean = text.replaceAll('\uFEFF', '');
  final lines = clean
      .split(RegExp(r'\r?\n'))
      .where((l) => l.trim().isNotEmpty && !l.trim().startsWith('#'))
      .toList();
  if (lines.isEmpty) return ImportResult(0, 0, 0, []);
  final delim = _detectDelim(lines.first);
  final rows = _parseCsv(lines.join('\n'), delim);
  if (rows.isEmpty) return ImportResult(0, 0, 0, []);
  final spec = _headerSpec(rows.first);
  if (spec != null) return _importTable(rows.skip(1).toList(), spec, defaultLang);
  return _importNative(lines, defaultLang);
}

/// Ancien import ligne à ligne (format interne, 22 ou 18 colonnes).
ImportResult _importNative(List<String> lines, String? defaultLang) {
  var added = 0, updated = 0, skipped = 0;
  final keep = <String>[];
  final loose = <List<String>>[];
  for (final l in lines) {
    final p = _split(l.trim());
    if (p == null) {
      if (defaultLang != null) {
        final r = _parseCsv(l, _detectDelim(l));
        if (r.isNotEmpty && r.first.length >= 2) {
          loose.add(r.first);
          continue;
        }
      }
      skipped++;
      continue;
    }
    if (p[0].toLowerCase() == 'id') continue; // ligne d'en-tête
    final r = _merge(p);
    if (r == 1) added++;
    if (r == 2) updated++;
    if (r == 0) {
      skipped++;
      continue;
    }
    keep.add(p.join('|'));
  }
  if (loose.isNotEmpty) {
    final spec = _Spec();
    spec.fr = 0;
    spec.tr = 1;
    final t = _importTable(loose, spec, defaultLang);
    added += t.added;
    updated += t.updated;
    skipped += t.skipped;
    keep.addAll(t.lines);
  }
  return ImportResult(added, updated, skipped, keep);
}

/// Réapplique au démarrage les lignes déjà importées.
void applyCustom(List<String> lines) {
  for (final l in lines) {
    if (l.startsWith('@x|')) {
      final p = l.split('|');
      if (p.length >= 6) extras['${p[2]}/${p[1]}'] = Extra(p[3], p[4], p[5]);
      continue;
    }
    final p = _pad(l.split('|'));
    if (p.length == _cols) _merge(p);
  }
}

// ── Import intelligent : lecture de l'en-tête ──

/// Clé de comparaison : minuscules, sans accents ni ponctuation.
String _key(String s) =>
    norm(s).replaceAll(RegExp(r'[^a-z0-9 ]+'), '').replaceAll(RegExp(r'\s+'), ' ').trim();

const _langAliases = <String, String>{
  'fr': 'fr', 'francais': 'fr', 'french': 'fr',
  'ln': 'ln', 'lingala': 'ln',
  'enus': 'en_US', 'en': 'en_US', 'anglais': 'en_US', 'english': 'en_US',
  'engb': 'en_GB', 'anglaisuk': 'en_GB', 'englishuk': 'en_GB', 'britannique': 'en_GB',
  'sw': 'sw', 'swahili': 'sw', 'kiswahili': 'sw',
  'lua': 'lua', 'tshiluba': 'lua', 'chiluba': 'lua', 'luba': 'lua',
  'kg': 'kg', 'kikongo': 'kg', 'kituba': 'kg', 'kongo': 'kg',
  'es': 'es', 'espagnol': 'es', 'espanol': 'es', 'spanish': 'es',
  'pt': 'pt', 'portugais': 'pt', 'portugues': 'pt', 'portuguese': 'pt',
  'de': 'de', 'allemand': 'de', 'deutsch': 'de', 'german': 'de',
  'wa': 'wa', 'wallon': 'wa',
  'nlbe': 'nl_BE', 'nl': 'nl_BE', 'flamand': 'nl_BE', 'neerlandais': 'nl_BE', 'vlaams': 'nl_BE', 'dutch': 'nl_BE',
  'ensl': 'en_SL', 'frsl': 'fr_SL',
  'af': 'af', 'afrikaans': 'af',
  'eo': 'eo', 'esperanto': 'eo',
  'ru': 'ru', 'russe': 'ru', 'russian': 'ru',
  'zu': 'zu', 'zoulou': 'zu', 'zulu': 'zu', 'isizulu': 'zu',
};

/// Code de langue d'un intitulé (« Lingala », « kg », « Kikongo (Kituba) », « English (UK) »…), ou null.
String? _langOf(String raw) {
  final k = _key(raw);
  if (k.isEmpty) return null;
  final compact = k.replaceAll(' ', '');
  final direct = _langAliases[compact];
  if (direct != null) return direct;
  if (k.contains('slang') || k.startsWith('argot')) {
    return (k.contains('angl') || k.startsWith('english')) ? 'en_SL' : 'fr_SL';
  }
  if (RegExp(r'\b(uk|gb)\b').hasMatch(k) || k.contains('britan')) return 'en_GB';
  return _langAliases[k.split(' ').first];
}

class _Spec {
  int fr = -1, id = -1, cat = -1, theme = -1, pron = -1, ex = -1, tr = -1, langCol = -1;
  final Map<int, String> langCols = {};
}

/// Analyse une ligne d'en-tête ; null si ce n'est pas un en-tête reconnu.
_Spec? _headerSpec(List<String> h) {
  if (h.length >= _legacyCols) return null; // format interne
  final s = _Spec();
  for (var i = 0; i < h.length; i++) {
    final k = _key(h[i]).replaceAll(' ', '');
    if (k == 'id') {
      s.id = i;
    } else if (k == 'categorie' || k == 'category' || k == 'cat') {
      s.cat = i;
    } else if (k == 'theme') {
      s.theme = i;
    } else if (k.startsWith('pronon') || k == 'phonetique' || k == 'pron') {
      s.pron = i;
    } else if (k.startsWith('exemple') || k.startsWith('example')) {
      s.ex = i;
    } else if (k == 'traduction' || k == 'translation') {
      s.tr = i;
    } else if (k == 'codelangue' || k == 'langcode') {
      s.langCol = i;
    } else if (k == 'langue' || k == 'language' || k == 'lang') {
      if (s.langCol < 0) s.langCol = i;
    } else {
      final l = _langOf(h[i]);
      if (l == 'fr') {
        if (s.fr < 0) s.fr = i;
      } else if (l != null) {
        s.langCols[i] = l;
      }
    }
  }
  if (s.fr < 0) return null;
  if (s.langCols.isEmpty && s.tr < 0) return null;
  return s;
}

// ── Import intelligent : lecture du CSV ──

String _detectDelim(String line) {
  var best = '|', bestN = 0;
  for (final d in ['|', ';', '\t', ',']) {
    var n = 0;
    var inQ = false;
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        inQ = !inQ;
      } else if (!inQ && c == d) {
        n++;
      }
    }
    if (n > bestN) {
      best = d;
      bestN = n;
    }
  }
  return best;
}

/// Lecteur CSV : guillemets, guillemets doublés, retours à la ligne dans une cellule.
List<List<String>> _parseCsv(String text, String d) {
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var inQ = false;
  void endCell() {
    row.add(cell.toString());
    cell.clear();
  }

  void endRow() {
    endCell();
    if (row.any((c) => c.trim().isNotEmpty)) rows.add(row);
    row = <String>[];
  }

  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (inQ) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          inQ = false;
        }
      } else {
        cell.write(c);
      }
    } else if (c == '"' && cell.isEmpty) {
      inQ = true;
    } else if (c == d) {
      endCell();
    } else if (c == '\n') {
      endRow();
    } else if (c != '\r') {
      cell.write(c);
    }
  }
  endRow();
  return rows;
}

// ── Import intelligent : nettoyage des cellules ──

const _catMap = <String, String>{
  'calendrier et temps': 'Temps', 'temps et calendrier': 'Temps', 'nature et temps': 'Temps', 'temps': 'Temps',
  'salutations et politesse': 'Salutations', 'salutations': 'Salutations', 'salutation': 'Salutations',
  'politesse': 'Salutations',
  'vie quotidienne et maison': 'Vie', 'vie quotidienne': 'Vie', 'courant': 'Vie', 'maison': 'Vie', 'divers': 'Vie',
  'corps humain et sante': 'Corps', 'corps et sante': 'Corps', 'corps': 'Corps', 'sante': 'Santé', 'urgences': 'Santé',
  'alimentation et boissons': 'Nourriture', 'alimentation': 'Nourriture', 'restaurant': 'Nourriture',
  'nourriture': 'Nourriture',
  'voyage et direction': 'Orientation', 'voyage': 'Orientation', 'orientation': 'Orientation',
  'nombres': 'Nombres', 'nombre': 'Nombres',
  'verbes courants': 'Verbes', 'actions': 'Verbes', 'verbes': 'Verbes', 'verbe': 'Verbes',
  'conjugaison de base': 'Conjugaison', 'conjugaison': 'Conjugaison',
  'famille et personnes': 'Famille', 'famille': 'Famille', 'personnes': 'Famille',
  'commerce et marche': 'Achats', 'commerce': 'Achats', 'achats': 'Achats',
  'vocabulaire administratif et social': 'Société', 'administratif et social': 'Société', 'societe': 'Société',
  'education': 'Société', 'travail': 'Société',
  'lexique religieux et spirituel': 'Spiritualité', 'religieux et spirituel': 'Spiritualité',
  'adjectifs': 'Adjectifs', 'adjectif': 'Adjectifs',
  'communication': 'Phrases', 'expressions': 'Phrases', 'expression': 'Phrases', 'phrases': 'Phrases',
  'phrase': 'Phrases',
  'pronoms': 'Pronoms', 'lieux': 'Lieux', 'transport': 'Transports', 'transports': 'Transports',
  'couleurs': 'Couleurs', 'animaux': 'Animaux', 'nature': 'Nature', 'technologie': 'Technologie',
  'identite': 'Identité', 'hebergement': 'Hébergement',
};

const _catEmoji = <String, String>{
  'Salutations': '👋', 'Nourriture': '🍽️', 'Verbes': '🔤', 'Adjectifs': '✨', 'Temps': '⏳', 'Phrases': '💬',
  'Société': '🏛️', 'Nombres': '🔢', 'Lieux': '📍', 'Corps': '🫀', 'Orientation': '🧭', 'Transports': '🚆',
  'Achats': '🛍️', 'Nature': '🌿', 'Vie': '🏠', 'Animaux': '🐾', 'Identité': '🪪', 'Couleurs': '🎨',
  'Famille': '👨‍👩‍👧', 'Technologie': '💻', 'Pronoms': '👤', 'Santé': '🩺', 'Hébergement': '🛏️',
  'Conjugaison': '🧩', 'Proverbes': '📜', 'Spiritualité': '⛪', 'Divers': '🔤',
};

String? _catOf(String raw) {
  final k = _key(raw);
  if (k.isEmpty) return null;
  if (k.startsWith('proverbes')) return 'Proverbes';
  return _catMap[k];
}

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

class _Fr {
  final String label, base;
  final bool gloss, keep;
  const _Fr(this.label, this.base, this.gloss, this.keep);
}

/// Cellule française : « Bonjour / Salut », « Bonjour (le matin) », « Sept (7) »…
_Fr? _parseFr(String raw) {
  var s = raw.replaceAll('|', '/').replaceAll(RegExp(r'\s+'), ' ').trim();
  if (s.isEmpty) return null;
  String? gloss;
  for (final m in RegExp(r'\(([^()]*)\)').allMatches(s)) {
    final g = (m.group(1) ?? '').trim();
    final letters = g.replaceAll(RegExp(r'[\s\p{P}\p{S}\d]', unicode: true), '');
    if (letters.length > 2 && !g.contains(':')) {
      gloss = g.replaceAll(RegExp(r'\s+/\s+'), ', ').toLowerCase();
      break;
    }
  }
  s = s.replaceAll(RegExp(r'\s*\([^()]*\)'), '').trim();
  final alts = s.split(RegExp(r'\s+/\s+')).map((a) => a.trim()).where((a) => a.isNotEmpty).toList();
  if (alts.isEmpty) return null;
  var base = alts.first;
  final art = RegExp(r"^(?:(?:le|la|les)\s+|l['’])", caseSensitive: false).firstMatch(base);
  if (art != null && base.split(' ').length <= 2 && base.substring(art.end).trim().isNotEmpty) {
    base = base.substring(art.end).trim();
  }
  final keep = RegExp(r'[?!.…]$').hasMatch(base) && base.split(' ').length >= 2;
  if (!keep) base = base.replaceAll(RegExp(r'\s*[?!.…]+$'), '').trim();
  if (base.isEmpty) return null;
  final label = _cap(base) + (gloss != null ? ' ($gloss)' : '');
  return _Fr(label, base, gloss != null, keep);
}

/// Clés sous lesquelles un libellé français existant peut être retrouvé.
Set<String> _frKeys(String label) {
  final keys = <String>{_key(label)};
  if (!label.contains('(')) {
    for (final tok in label.split(' / ')) {
      final k = _key(tok);
      if (k.isNotEmpty) keys.add(k);
    }
  }
  keys.remove('');
  return keys;
}

String _cleanTarget(String raw, bool keep) {
  final s = raw
      .replaceAll('|', '/')
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'\s*\([^()]*\)'), '')
      .trim();
  final toks = <String>[];
  for (final part in s.split(RegExp(r'\s+/\s+'))) {
    var tok = part.trim();
    if (!keep) {
      tok = tok.replaceAll(RegExp(r'^[¡¿]+'), '').replaceAll(RegExp(r'\s*[!?.…]+$'), '').trim();
    }
    if (tok.isNotEmpty) toks.add(_cap(tok));
  }
  return toks.join(' / ');
}

/// Nouveau mot en premier, anciennes variantes conservées (4 au maximum).
String _mergeTokens(String a, String b) {
  final seen = <String>{};
  final out = <String>[];
  for (final g in [a, b]) {
    for (final t in g.split(' / ')) {
      final x = t.trim();
      if (x.isNotEmpty && seen.add(x.toLowerCase())) out.add(x);
    }
  }
  return out.take(4).join(' / ');
}

class _Ex {
  final String t, fr;
  const _Ex(this.t, this.fr);
}

/// « Hola, ¿cómo estás? (Bonjour, comment vas-tu ?) » ou « Hujambo mama? = Bonjour maman ? ».
_Ex _splitExample(String raw) {
  final s = raw.replaceAll('|', '/').replaceAll(RegExp(r'\s+'), ' ').trim();
  if (s.isEmpty) return const _Ex('', '');
  final eq = s.indexOf(' = ');
  if (eq > 0) return _Ex(s.substring(0, eq).trim(), s.substring(eq + 3).trim());
  if (s.endsWith(')')) {
    var depth = 0;
    for (var i = s.length - 1; i >= 0; i--) {
      if (s[i] == ')') {
        depth++;
      } else if (s[i] == '(') {
        depth--;
        if (depth == 0) return _Ex(s.substring(0, i).trim(), s.substring(i + 1, s.length - 1).trim());
      }
    }
  }
  return _Ex(s, '');
}

String _slug(String label) {
  var s = _key(label).replaceAll(' ', '_');
  s = s.replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_|_$'), '');
  if (s.isEmpty) s = 'mot';
  if (s.length > 40) {
    s = s.substring(0, 40);
    final i = s.lastIndexOf('_');
    if (i > 0) s = s.substring(0, i);
  }
  return s;
}

String _cellAt(List<String> r, int i) => (i >= 0 && i < r.length) ? r[i].trim() : '';

/// Importe les lignes d'un tableau dont l'en-tête a été reconnu.
ImportResult _importTable(List<List<String>> rows, _Spec s, String? defaultLang) {
  var added = 0, updated = 0, skipped = 0;
  final touched = <String, Set<String>>{}; // id -> langues modifiées
  final xs = <String, String>{}; // lignes « @x| » (prononciations) à mémoriser
  final byFr = <String, Entry>{};
  for (final e in entries) {
    for (final k in _frKeys(e.t['fr'] ?? '')) {
      byFr.putIfAbsent(k, () => e);
    }
  }
  final usedIds = <String>{for (final e in entries) e.id};

  for (final r in rows) {
    final fr = _parseFr(_cellAt(r, s.fr));
    if (fr == null) {
      skipped++;
      continue;
    }
    // Mots à placer : langue -> texte brut
    final targets = <String, String>{};
    s.langCols.forEach((i, l) {
      final v = _cellAt(r, i);
      if (v.isNotEmpty) targets[l] = v;
    });
    if (s.tr >= 0) {
      var l = defaultLang;
      if (s.langCol >= 0) l = _langOf(_cellAt(r, s.langCol)) ?? l;
      final v = _cellAt(r, s.tr);
      if (l != null && l != 'fr' && v.isNotEmpty) targets[l] = v;
    }
    if (targets.isEmpty) {
      skipped++;
      continue;
    }
    // Entrée existante ou nouvelle
    final found = byFr[fr.gloss ? _key(fr.label) : _key(fr.base)];
    final Entry ent;
    var isNew = false;
    if (found != null) {
      ent = found;
    } else {
      final cat = _catOf(_cellAt(r, s.theme)) ?? _catOf(_cellAt(r, s.cat)) ?? 'Divers';
      final base = _slug(fr.label);
      var id = base;
      var n = 2;
      while (usedIds.contains(id)) {
        id = '${base}_$n';
        n++;
      }
      usedIds.add(id);
      final exFr = s.ex >= 0 ? _splitExample(_cellAt(r, s.ex)).fr : '';
      ent = Entry(id, cat, _catEmoji[cat] ?? '🔤', exFr, {for (final l in langs) l.code: ''});
      ent.t['fr'] = fr.label;
      entries.add(ent);
      for (final k in _frKeys(fr.label)) {
        byFr.putIfAbsent(k, () => ent);
      }
      isNew = true;
      touched.putIfAbsent(id, () => <String>{}).add('fr');
    }
    var changed = isNew;
    for (final t in targets.entries) {
      final v = _cleanTarget(t.value, fr.keep);
      if (v.isEmpty) continue;
      final old = ent.t[t.key] ?? '';
      final merged = _mergeTokens(v, old);
      if (merged != old) {
        ent.t[t.key] = merged;
        changed = true;
        touched.putIfAbsent(ent.id, () => <String>{}).add(t.key);
      }
    }
    // Prononciation et phrase d'exemple (un seul mot par ligne)
    final pron = _cellAt(r, s.pron).replaceAll('|', '/');
    final ex = _splitExample(_cellAt(r, s.ex));
    if (targets.length == 1 && (pron.isNotEmpty || ex.t.isNotEmpty)) {
      final lang = targets.keys.first;
      final first = _key(_cleanTarget(targets[lang]!, fr.keep).split(' / ').first);
      final cur = _key((ent.t[lang] ?? '').split(' / ').first);
      if (first.isNotEmpty && first == cur) {
        final k = '$lang/${ent.id}';
        final old = extras[k];
        if (old == null || old.pron != pron || old.example != ex.t || old.exampleFr != ex.fr) {
          extras[k] = Extra(pron, ex.t, ex.fr);
          xs[k] = '@x|${ent.id}|$lang|$pron|${ex.t}|${ex.fr}';
          changed = true;
        }
      }
    }
    if (isNew) {
      added++;
    } else if (changed) {
      updated++;
    } else {
      skipped++;
    }
  }

  // Lignes à mémoriser : uniquement les langues touchées (le reste du dictionnaire reste modifiable par mise à jour)
  final keep = <String>[];
  touched.forEach((id, ls) {
    final e = entries.firstWhere((x) => x.id == id);
    final p = <String>[id, e.cat, e.emoji, e.example];
    for (final l in langs) {
      p.add(ls.contains(l.code) ? (e.t[l.code] ?? '') : '');
    }
    keep.add(p.join('|'));
  });
  keep.addAll(xs.values);
  return ImportResult(added, updated, skipped, keep);
}

/// Minuscules sans accents, pour la recherche.
String norm(String s) {
  const a = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿ';
  const b = 'aaaaaaceeeeiiiinooooouuuuyy';
  var r = s.toLowerCase().replaceAll('œ', 'oe').replaceAll('ß', 'ss').replaceAll('ɛ', 'e');
  for (var i = 0; i < a.length; i++) {
    r = r.replaceAll(a[i], b[i]);
  }
  return r;
}
