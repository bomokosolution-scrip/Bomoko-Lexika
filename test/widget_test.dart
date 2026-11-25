import 'package:flutter_test/flutter_test.dart';
import 'package:lexika/data.dart';

void main() {
  test('norm retire accents et ligatures', () {
    expect(norm('Éléphant'), 'elephant');
    expect(norm('Œil'), 'oeil');
    expect(norm('Straße'), 'strasse');
  });

  test('Entry.w ignore les cases vides', () {
    final e = Entry('x', 'c', '🙂', 'ex', {'fr': 'Bonjour', 'ln': ''});
    expect(e.w('fr'), 'Bonjour');
    expect(e.w('ln'), isNull);
    expect(e.w('zz'), isNull);
  });

  test('les 18 langues sont déclarées, y compris afrikaans, espéranto, russe et zoulou', () {
    expect(langs.length, 18);
    for (final c in ['af', 'eo', 'ru', 'zu']) {
      expect(langs.any((l) => l.code == c), isTrue);
    }
  });

  test('import CSV avec en-tête : complète un mot existant et ajoute les nouveaux', () {
    entries = [
      Entry('bonjour', 'Salutations', '👋', '', {for (final l in langs) l.code: l.code == 'fr' ? 'Bonjour' : ''}),
    ];
    final r = importText('Français;Lingala\nbonjour;mbote\nmerci;matondi\n');
    expect(r.added, 1);
    expect(r.updated, 1);
    expect(entries.first.w('ln'), 'Mbote');
    expect(entries.length, 2);
  });

  test('import CSV dictionnaire « langue → français » avec prononciation', () {
    entries = [];
    final r = importText('lingala;prononciation;francais;categorie;theme;exemple_phrase\n'
        'Mbote;mbo-té;Bonjour / Salut;salutation;Salutations et politesse;Mbote na yo. (Bonjour à toi.)\n');
    expect(r.added, 1);
    expect(entries.first.w('ln'), 'Mbote');
    expect(entries.first.cat, 'Salutations');
    expect(entries.first.x('ln')?.pron, 'mbo-té');
  });
}
