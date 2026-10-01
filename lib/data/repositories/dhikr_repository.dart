import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/dhikr_definition.dart';

/// Repository interface for Dhikr definitions.
abstract interface class DhikrRepository {
  List<DhikrDefinition> getAll();
  DhikrDefinition? getById(String id);
  List<DhikrDefinition> getByCategory(String category);
  List<DhikrDefinition> getFavorites();
  List<String> getCategories();
  Future<void> toggleFavorite(String id);
  Future<void> addCustomDhikr(DhikrDefinition dhikr);
  Future<void> removeCustomDhikr(String id);
}

/// Baseline canonical short adhkar catalogue.
const List<DhikrDefinition> kCanonicalAdhkar = [
  DhikrDefinition(
    id: 'astaghfirullah',
    arabic: 'أَسْتَغْفِرُ ٱللَّٰهَ',
    transliteration: 'Astaghfirullah',
    translation: 'I seek forgiveness from Allah',
    category: 'Forgiveness',
    defaultTarget: 100,
    aliases: ['أستغفر بالله', 'استغفرالله', 'أستغفر الله', 'astaghfirullah', 'astaghfirullahal adheem'],
    normalizedArabic: 'استغفر الله',
    isFavorite: true,
  ),
  DhikrDefinition(
    id: 'subhanallah',
    arabic: 'سُبْحَانَ ٱللَّٰهِ',
    transliteration: 'SubhanAllah',
    translation: 'Glory be to Allah',
    category: 'Tasbih',
    defaultTarget: 33,
    aliases: ['سبحانالله', 'subhanallah', 'subhan allah'],
    normalizedArabic: 'سبحان الله',
    isFavorite: true,
  ),
  DhikrDefinition(
    id: 'alhamdulillah',
    arabic: 'ٱلْحَمْدُ لِلَّٰهِ',
    transliteration: 'Alhamdulillah',
    translation: 'All praise is due to Allah',
    category: 'Tahmid',
    defaultTarget: 33,
    aliases: ['الحمدلله', 'alhamdulillah', 'alhamdu lillah'],
    normalizedArabic: 'الحمد لله',
    isFavorite: true,
  ),
  DhikrDefinition(
    id: 'allahu_akbar',
    arabic: 'ٱللَّٰهُ أَكْبَرُ',
    transliteration: 'Allahu Akbar',
    translation: 'Allah is the Greatest',
    category: 'Takbir',
    defaultTarget: 33,
    aliases: ['الله أكبر', 'allahu akbar', 'allah akbar'],
    normalizedArabic: 'الله اكبر',
    isFavorite: true,
  ),
  DhikrDefinition(
    id: 'la_ilaha_illallah',
    arabic: 'لَا إِلَٰهَ إِلَّا ٱللَّٰهُ',
    transliteration: 'La ilaha illallah',
    translation: 'There is no god but Allah',
    category: 'Tahlil',
    defaultTarget: 100,
    aliases: ['لا إله إلا الله', 'la ilaha illallah', 'la ilaha illa allah'],
    normalizedArabic: 'لا اله الا الله',
    isFavorite: false,
  ),
  DhikrDefinition(
    id: 'subhanallahi_wa_bihamdihi',
    arabic: 'سُبْحَانَ ٱللَّٰهِ وَبِحَمْدِهِ',
    transliteration: 'SubhanAllahi wa bihamdihi',
    translation: 'Glory be to Allah and His is the praise',
    category: 'Tasbih',
    defaultTarget: 100,
    aliases: ['سبحان الله وبحمده', 'subhanallahi wa bihamdihi'],
    normalizedArabic: 'سبحان الله وبحمده',
    isFavorite: false,
  ),
  DhikrDefinition(
    id: 'subhanallahil_azeem',
    arabic: 'سُبْحَانَ ٱللَّٰهِ ٱلْعَظِيمِ',
    transliteration: 'SubhanAllahil Azeem',
    translation: 'Glory be to Allah, the Magnificent',
    category: 'Tasbih',
    defaultTarget: 100,
    aliases: ['سبحان الله العظيم', 'subhanallahil azeem'],
    normalizedArabic: 'سبحان الله العظيم',
    isFavorite: false,
  ),
  DhikrDefinition(
    id: 'la_hawla',
    arabic: 'لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِٱللَّٰهِ',
    transliteration: 'La hawla wa la quwwata illa billah',
    translation: 'There is no power nor strength except with Allah',
    category: 'Hawqalah',
    defaultTarget: 100,
    aliases: ['لا حول ولا قوة إلا بالله', 'la hawla wa la quwwata illa billah'],
    normalizedArabic: 'لا حول ولا قوه الا بالله',
    isFavorite: false,
  ),
  DhikrDefinition(
    id: 'hasbunallahu_wa_nimal_wakeel',
    arabic: 'حَسْبُنَا ٱللَّٰهُ وَنِعْمَ ٱلْوَكِيلُ',
    transliteration: "HasbunAllahu wa ni'mal wakeel",
    translation:
        'Sufficient for us is Allah, and He is the best Disposer of affairs',
    category: 'Trust',
    defaultTarget: 100,
    aliases: ['حسبنا الله ونعم الوكيل', "hasbunallahu wa ni'mal wakeel"],
    normalizedArabic: 'حسبنا الله ونعم الوكيل',
    isFavorite: false,
  ),
  DhikrDefinition(
    id: 'allahumma_salli_ala_muhammad',
    arabic: 'ٱللَّٰهُمَّ صَلِّ عَلَىٰ مُحَمَّدٍ',
    transliteration: "Allahumma salli 'ala Muhammad",
    translation: 'O Allah, bestow peace and blessings upon Muhammad',
    category: 'Salawat',
    defaultTarget: 100,
    aliases: ['اللهم صل على محمد', "allahumma salli 'ala muhammad", 'allahumma salli ala muhammad'],
    normalizedArabic: 'اللهم صل علي محمد',
    isFavorite: false,
  ),
];

/// Persistent implementation of [DhikrRepository] backed by SharedPreferences.
class LocalDhikrRepository implements DhikrRepository {
  static const _keyFavorites = 'dhikr_favorites_ids';
  static const _keyCustomAdhkar = 'dhikr_custom_definitions_json';

  final SharedPreferences? _prefs;
  final Map<String, DhikrDefinition> _items = {};
  Set<String> _favoriteIds = {};

  LocalDhikrRepository([this._prefs]) {
    _initialize();
  }

  void _initialize() {
    // 1. Seed canonical items
    for (final item in kCanonicalAdhkar) {
      _items[item.id] = item;
    }

    // 2. Load custom definitions from storage
    final customListJson = _prefs?.getStringList(_keyCustomAdhkar);
    if (customListJson != null) {
      for (final itemStr in customListJson) {
        try {
          final map = jsonDecode(itemStr) as Map<String, dynamic>;
          final customDhikr = DhikrDefinition.fromJson(map);
          _items[customDhikr.id] = customDhikr;
        } catch (_) {
          // Ignore corrupt entry
        }
      }
    }

    // 3. Load favorites
    final storedFavorites = _prefs?.getStringList(_keyFavorites);
    if (storedFavorites != null) {
      _favoriteIds = storedFavorites.toSet();
    } else {
      _favoriteIds = _items.values
          .where((d) => d.isFavorite)
          .map((d) => d.id)
          .toSet();
    }

    // Update isFavorite flag on all loaded items
    for (final id in _items.keys) {
      final isFav = _favoriteIds.contains(id);
      _items[id] = _items[id]!.copyWith(isFavorite: isFav);
    }
  }

  @override
  List<DhikrDefinition> getAll() => _items.values.toList();

  @override
  DhikrDefinition? getById(String id) => _items[id];

  @override
  List<DhikrDefinition> getByCategory(String category) {
    return _items.values.where((d) => d.category == category).toList();
  }

  @override
  List<DhikrDefinition> getFavorites() {
    return _items.values.where((d) => _favoriteIds.contains(d.id)).toList();
  }

  @override
  List<String> getCategories() {
    return _items.values.map((d) => d.category).toSet().toList();
  }

  @override
  Future<void> toggleFavorite(String id) async {
    final item = _items[id];
    if (item == null) return;

    if (_favoriteIds.contains(id)) {
      _favoriteIds.remove(id);
      _items[id] = item.copyWith(isFavorite: false);
    } else {
      _favoriteIds.add(id);
      _items[id] = item.copyWith(isFavorite: true);
    }

    await _prefs?.setStringList(_keyFavorites, _favoriteIds.toList());
  }

  @override
  Future<void> addCustomDhikr(DhikrDefinition dhikr) async {
    _items[dhikr.id] = dhikr;
    await _persistCustomAdhkar();
  }

  @override
  Future<void> removeCustomDhikr(String id) async {
    _items.remove(id);
    _favoriteIds.remove(id);
    await _persistCustomAdhkar();
    await _prefs?.setStringList(_keyFavorites, _favoriteIds.toList());
  }

  Future<void> _persistCustomAdhkar() async {
    final customItems = _items.values
        .where((d) => !kCanonicalAdhkar.any((c) => c.id == d.id))
        .map((d) => jsonEncode(d.toJson()))
        .toList();
    await _prefs?.setStringList(_keyCustomAdhkar, customItems);
  }
}
