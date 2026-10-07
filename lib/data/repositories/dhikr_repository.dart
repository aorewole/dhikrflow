import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/dhikr_definition.dart';
import '../../recognition/text/arabic_normalizer.dart';

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

/// Baseline canonical authentic Sunnah adhkar catalogue with liturgical waqf codas.
const List<DhikrDefinition> kCanonicalAdhkar = [
  // ── Praise & Tasbih (تسبيح وتحميد) ──────────────────────────────────────
  DhikrDefinition(
    id: "subhanallah",
    arabic: "سُبْحَانَ ٱللّٰهْ",
    transliteration: "SubhanAllah",
    translation: "Glory be to Allah",
    category: "Praise & Tasbih",
    defaultTarget: 33,
    aliases: ["سبحان الله", "سبحانالله", "subhanallah", "subhan allah"],
    normalizedArabic: "سبحان الله",
    isFavorite: true,
  ),
  DhikrDefinition(
    id: "alhamdulillah",
    arabic: "ٱلْحَمْدُ لِلّٰهْ",
    transliteration: "Alhamdulillah",
    translation: "All praise is due to Allah",
    category: "Praise & Tasbih",
    defaultTarget: 33,
    aliases: ["الحمد لله", "الحمدلله", "alhamdulillah", "alhamdu lillah"],
    normalizedArabic: "الحمد لله",
    isFavorite: true,
  ),
  DhikrDefinition(
    id: "allahu_akbar",
    arabic: "ٱللّٰهُ أَكْبَرْ",
    transliteration: "Allahu Akbar",
    translation: "Allah is the Greatest",
    category: "Praise & Tasbih",
    defaultTarget: 33,
    aliases: ["الله أكبر", "الله اكبر", "allahu akbar", "allah akbar"],
    normalizedArabic: "الله اكبر",
    isFavorite: true,
  ),
  DhikrDefinition(
    id: "subhanallahi_wa_bihamdihi",
    arabic: "سُبْحَانَ ٱللّٰهِ وَبِحَمْدِهْ",
    transliteration: "SubhanAllahi wa bihamdih",
    translation: "Glory be to Allah and His is the praise",
    category: "Praise & Tasbih",
    defaultTarget: 100,
    aliases: ["سبحان الله وبحمده", "subhanallahi wa bihamdihi", "subhan allah wa bihamdihi"],
    normalizedArabic: "سبحان الله وبحمده",
    isFavorite: false,
  ),
  DhikrDefinition(
    id: "subhanallahil_azeem",
    arabic: "سُبْحَانَ ٱللّٰهِ ٱلْعَظِيمْ",
    transliteration: "SubhanAllahil 'Azeem",
    translation: "Glory be to Allah, the Magnificent",
    category: "Praise & Tasbih",
    defaultTarget: 100,
    aliases: ["سبحان الله العظيم", "subhanallahil azeem", "subhan allahil azeem"],
    normalizedArabic: "سبحان الله العظيم",
    isFavorite: false,
  ),
  DhikrDefinition(
    id: "subhana_rabbiyal_ala",
    arabic: "سُبْحَانَ رَبِّيَ ٱلْأَعْلَىٰ",
    transliteration: "Subhana Rabbiyal A'la",
    translation: "Glory be to my Lord, the Most High",
    category: "Praise & Tasbih",
    defaultTarget: 33,
    aliases: ["سبحان ربي الاعلى", "سبحان ربي الأعلى", "subhana rabbiyal ala"],
    normalizedArabic: "سبحان ربي الاعلي",
    isFavorite: false,
  ),
  DhikrDefinition(
    id: "subhana_rabbiyal_azeem",
    arabic: "سُبْحَانَ رَبِّيَ ٱلْعَظِيمْ",
    transliteration: "Subhana Rabbiyal 'Azeem",
    translation: "Glory be to my Lord, the Magnificent",
    category: "Praise & Tasbih",
    defaultTarget: 33,
    aliases: ["سبحان ربي العظيم", "subhana rabbiyal azeem"],
    normalizedArabic: "سبحان ربي العظيم",
    isFavorite: false,
  ),

  // ── Forgiveness & Repentance (استغفار وتوبة) ───────────────────────────
  DhikrDefinition(
    id: "astaghfirullah",
    arabic: "أَسْتَغْفِرُ ٱللّٰهْ",
    transliteration: "Astaghfirullah",
    translation: "I seek forgiveness from Allah",
    category: "Forgiveness",
    defaultTarget: 100,
    aliases: ["أستغفر الله", "استغفر الله", "استغفرالله", "astaghfirullah", "astagfirullah"],
    normalizedArabic: "استغفر الله",
    isFavorite: true,
  ),
  DhikrDefinition(
    id: "astaghfirullah_wa_atubu_ilayh",
    arabic: "أَسْتَغْفِرُ ٱللّٰهَ وَأَتُوبُ إِلَيْهْ",
    transliteration: "Astaghfirullah wa atubu ilayh",
    translation: "I seek forgiveness from Allah and repent to Him",
    category: "Forgiveness",
    defaultTarget: 100,
    aliases: ["استغفر الله واتوب اليه", "أستغفر الله وأتوب إليه", "astaghfirullah wa atubu ilayh"],
    normalizedArabic: "استغفر الله واتوب اليه",
    isFavorite: false,
  ),
  DhikrDefinition(
    id: "rabbighfir_li_wa_tub_alayya",
    arabic: "رَبِّ ٱغْفِرْ لِي وَتُبْ عَلَيَّ إِنَّكَ أَنْتَ ٱلتَّوَّابُ ٱلرَّحِيمْ",
    transliteration: "Rabbighfir li wa tub 'alayya innaka Antat-Tawwabur-Raheem",
    translation: "My Lord, forgive me and accept my repentance, truly You are the Oft-Returning, Most Merciful",
    category: "Forgiveness",
    defaultTarget: 100,
    aliases: ["رب اغفر لي وتب علي انك انت التواب الرحيم", "rabbighfir li wa tub alayya"],
    normalizedArabic: "رب اغفر لي وتب علي انك انت التواب الرحيم",
    isFavorite: false,
  ),
  DhikrDefinition(
    id: "sayyid_al_istighfar",
    arabic: "اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَٰهَ إِلَّا أَنْتَ خَلَقْتَنِي وَأَنَا عَبْدُكْ",
    transliteration: "Allahumma Anta Rabbi la ilaha illa Ant, khalaqtani wa ana 'abduk",
    translation: "O Allah, You are my Lord, there is no god but You, You created me and I am Your servant",
    category: "Forgiveness",
    defaultTarget: 3,
    aliases: ["اللهم انت ربي لا اله الا انت خلقتني وانا عبدك", "sayyid al istighfar"],
    normalizedArabic: "اللهم انت ربي لا اله الا انت خلقتني وانا عبدك",
    isFavorite: false,
  ),
  DhikrDefinition(
    id: "yunus_dhikr",
    arabic: "لَا إِلَٰهَ إِلَّا أَنْتَ سُبْحَانَكَ إِنِّي كُنْتُ مِنَ ٱلظَّالِمِينَ",
    transliteration: "La ilaha illa Anta subhanaka inni kuntu minaz-zalimeen",
    translation: "There is no god but You; glory be to You, truly I have been of the wrongdoers",
    category: "Forgiveness",
    defaultTarget: 40,
    aliases: ["لا اله الا انت سبحانك اني كنت من الظالمين", "la ilaha illa anta subhanaka inni kuntu minaz zalimeen"],
    normalizedArabic: "لا اله الا انت سبحانك اني كنت من الظالمين",
    isFavorite: false,
  ),

  // ── Tahlil & Tawhid (توحيد وتهليل) ────────────────────────────────────
  DhikrDefinition(
    id: "la_ilaha_illallah",
    arabic: "لَا إِلَٰهَ إِلَّا ٱللّٰهْ",
    transliteration: "La ilaha illallah",
    translation: "There is no god but Allah",
    category: "Tahlil & Tawhid",
    defaultTarget: 100,
    aliases: ["لا إله إلا الله", "لا اله الا الله", "la ilaha illallah"],
    normalizedArabic: "لا اله الا الله",
    isFavorite: false,
  ),
  DhikrDefinition(
    id: "la_ilaha_illallah_wahdahu",
    arabic: "لَا إِلَٰهَ إِلَّا ٱللّٰهُ وَحْدَهُ لَا شَرِيكَ لَهْ",
    transliteration: "La ilaha illallahu wahdahu la sharika lah",
    translation: "There is no god but Allah alone, having no partner",
    category: "Tahlil & Tawhid",
    defaultTarget: 100,
    aliases: ["لا اله الا الله وحده لا شريك له", "la ilaha illallahu wahdahu la sharika lah"],
    normalizedArabic: "لا اله الا الله وحده لا شريك له",
    isFavorite: false,
  ),
  DhikrDefinition(
    id: "tahlil_tamam",
    arabic: "لَا إِلَٰهَ إِلَّا ٱللّٰهُ وَحْدَهُ لَا شَرِيكَ لَهُ لَهُ ٱلْمُلْكُ وَلَهُ ٱلْحَمْدُ وَهُوَ عَلَىٰ كُلِّ شَيْءٍ قَدِيرْ",
    transliteration: "La ilaha illallahu wahdahu la sharika lah, lahul-mulku wa lahul-hamdu wa Huwa 'ala kulli shay'in qadeer",
    translation: "There is no god but Allah alone without partner, to Him belongs dominion and praise, and He is over all things capable",
    category: "Tahlil & Tawhid",
    defaultTarget: 100,
    aliases: ["لا اله الا الله وحده لا شريك له له الملك وله الحمد وهو على كل شيء قدير", "la ilaha illallah wahdahu la sharika lahu"],
    normalizedArabic: "لا اله الا الله وحده لا شريك له له الملك وله الحمد وهو علي كل شيء قدير",
    isFavorite: false,
  ),
  DhikrDefinition(
    id: "la_hawla",
    arabic: "لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِٱللّٰهْ",
    transliteration: "La hawla wa la quwwata illa billah",
    translation: "There is no power nor strength except with Allah",
    category: "Tahlil & Tawhid",
    defaultTarget: 100,
    aliases: ["لا حول ولا قوة إلا بالله", "لا حول ولا قوه الا بالله", "la hawla wa la quwwata illa billah"],
    normalizedArabic: "لا حول ولا قوه الا بالله",
    isFavorite: false,
  ),

  // ── Morning & Evening (أذكار الصباح والمساء) ───────────────────────────
  DhikrDefinition(
    id: "raditu_billah",
    arabic: "رَضِيتُ بِٱللّٰهِ رَبًّا وَبِٱلْإِسْلَامِ دِينًا وَبِمُحَمَّدٍ نَبِيًّا",
    transliteration: "Raditu billahi Rabba, wa bil-Islami deena, wa bi-Muhammadin Nabiyya",
    translation: "I am pleased with Allah as my Lord, Islam as my religion, and Muhammad as my Prophet",
    category: "Morning & Evening",
    defaultTarget: 3,
    aliases: ["رضيت بالله ربا وبالاسلام دينا وبمحمد نبيا", "raditu billahi rabba"],
    normalizedArabic: "رضيت بالله ربا وبالاسلام دينا وبمحمد نبيا",
    isFavorite: false,
  ),
  DhikrDefinition(
    id: "hasbiyallahu_la_ilaha",
    arabic: "حَسْبِيَ ٱللّٰهُ لَا إِلَٰهَ إِلَّا هُوَ عَلَيْهِ تَوَكَّلْتُ وَهُوَ رَبُّ ٱلْعَرْشِ ٱلْعَظِيمْ",
    transliteration: "Hasbiyallahu la ilaha illa Huwa, 'alayhi tawakkaltu wa Huwa Rabbul-'Arshil-'Azeem",
    translation: "Sufficient for me is Allah; there is no god but He. On Him I rely, and He is the Lord of the Mighty Throne",
    category: "Morning & Evening",
    defaultTarget: 7,
    aliases: ["حسبي الله لا اله الا هو عليه توكلت وهو رب العرش العظيم", "hasbiyallahu la ilaha illa huwa"],
    normalizedArabic: "حسبي الله لا اله الا هو عليه توكلت وهو رب العرش العظيم",
    isFavorite: false,
  ),
  DhikrDefinition(
    id: "ya_hayyu_ya_qayyum",
    arabic: "يَا حَيُّ يَا قَيُّومُ بِرَحْمَتِكَ أَسْتَغِيثْ",
    transliteration: "Ya Hayyu Ya Qayyoomu bi-rahmatika astagheeth",
    translation: "O Ever-Living, O Self-Sustaining, by Your mercy I seek assistance",
    category: "Morning & Evening",
    defaultTarget: 3,
    aliases: ["يا حي يا قيوم برحمتك استغيث", "ya hayyu ya qayyum bi rahmatika astagheeth"],
    normalizedArabic: "يا حي يا قيوم برحمتك استغيث",
    isFavorite: false,
  ),
  DhikrDefinition(
    id: "subhanallahi_adada_khalqihi",
    arabic: "سُبْحَانَ ٱللّٰهِ وَبِحَمْدِهِ عَدَدَ خَلْقِهِ وَرِضَا نَفْسِهِ وَزِنَةَ عَرْشِهِ وَمِدَادَ كَلِمَاتِهْ",
    transliteration: "SubhanAllahi wa bihamdihi 'adada khalqihi wa rida nafsihi wa zinata 'arshihi wa midada kalimatih",
    translation: "Glory and praise be to Allah, as much as the number of His creation, according to His pleasure, by the weight of His Throne, and the ink of His words",
    category: "Morning & Evening",
    defaultTarget: 3,
    aliases: ["سبحان الله وبحمده عدد خلقه ورضا نفسه وزنة عرشه ومداد كلماته", "subhanallahi wa bihamdihi adada khalqihi"],
    normalizedArabic: "سبحان الله وبحمده عدد خلقه ورضا نفسه وزنه عرشه ومداد كلماته",
    isFavorite: false,
  ),

  // ── Protection & Trust (حفظ وتوكل) ───────────────────────────────────
  DhikrDefinition(
    id: "bismillahilladhi",
    arabic: "بِسْمِ ٱللّٰهِ ٱلَّذِي لَا يَضُرُّ مَعَ ٱسْمِهِ شَيْءٌ فِي ٱلْأَرْضِ وَلَا فِي ٱلسَّمَاءِ وَهُوَ ٱلسَّمِيعُ ٱلْعَلِيمْ",
    transliteration: "Bismillahi-lladhi la yadurru ma'asmihi shay'un fil-ardi wa la fis-sama'i wa Huwas-Samee'ul-'Aleem",
    translation: "In the Name of Allah with Whose Name nothing in earth or heaven can cause harm, and He is the All-Hearing, All-Knowing",
    category: "Protection & Trust",
    defaultTarget: 3,
    aliases: ["بسم الله الذي لا يضر مع اسمه شيء في الارض ولا في السماء وهو السميع العليم", "bismillahilladhi la yadurru ma asmihi shay"],
    normalizedArabic: "بسم الله الذي لا يضر مع اسمه شيء في الارض ولا في السماء وهو السميع العليم",
    isFavorite: false,
  ),
  DhikrDefinition(
    id: "audhu_bikalimatillah",
    arabic: "أَعُوذُ بِكَلِمَاتِ ٱللّٰهِ ٱلتَّامَّاتِ مِنْ شَرِّ مَا خَلَقْ",
    transliteration: "A'udhu bi-kalimatillahi-ttammati min sharri ma khalaq",
    translation: "I seek refuge in the perfect words of Allah from the evil of what He has created",
    category: "Protection & Trust",
    defaultTarget: 3,
    aliases: ["اعوذ بكلمات الله التامات من شر ما خلق", "audhu bi kalimatillahit tammati min sharri ma khalaq"],
    normalizedArabic: "اعوذ بكلمات الله التامات من شر ما خلق",
    isFavorite: false,
  ),
  DhikrDefinition(
    id: "hasbunallahu_wa_nimal_wakeel",
    arabic: "حَسْبُنَا ٱللّٰهُ وَنِعْمَ ٱلْوَكِيلْ",
    transliteration: "HasbunAllahu wa ni'mal wakeel",
    translation: "Sufficient for us is Allah, and He is the best Disposer of affairs",
    category: "Protection & Trust",
    defaultTarget: 100,
    aliases: ["حسبنا الله ونعم الوكيل", "hasbunallahu wa ni'mal wakeel", "hasbunallah wa nimal wakeel"],
    normalizedArabic: "حسبنا الله ونعم الوكيل",
    isFavorite: false,
  ),
  DhikrDefinition(
    id: "bismillahi_tawakkaltu",
    arabic: "بِسْمِ ٱللّٰهِ تَوَكَّلْتُ عَلَى ٱللّٰهِ لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِٱللّٰهْ",
    transliteration: "Bismillahi tawakkaltu 'alallahi, la hawla wa la quwwata illa billah",
    translation: "In the Name of Allah, I place my trust in Allah, and there is no power nor strength except with Allah",
    category: "Protection & Trust",
    defaultTarget: 3,
    aliases: ["بسم الله توكلت على الله لا حول ولا قوة الا بالله", "bismillahi tawakkaltu alallah"],
    normalizedArabic: "بسم الله توكلت علي الله لا حول ولا قوه الا بالله",
    isFavorite: false,
  ),

  // ── Salawat upon the Prophet (الصلاة على النبي) ────────────────────────
  DhikrDefinition(
    id: "allahumma_salli_ala_muhammad",
    arabic: "ٱللّٰهُمَّ صَلِّ عَلَىٰ مُحَمَّدْ",
    transliteration: "Allahumma salli 'ala Muhammad",
    translation: "O Allah, send blessings upon Muhammad",
    category: "Salawat",
    defaultTarget: 100,
    aliases: ["اللهم صل على محمد", "اللهم صلي على محمد", "allahumma salli ala muhammad"],
    normalizedArabic: "اللهم صل علي محمد",
    isFavorite: false,
  ),
  DhikrDefinition(
    id: "salawat_ibrahimiyyah_short",
    arabic: "ٱللّٰهُمَّ صَلِّ عَلَىٰ مُحَمَّدٍ وَعَلَىٰ آلِ مُحَمَّدْ",
    transliteration: "Allahumma salli 'ala Muhammadin wa 'ala aali Muhammad",
    translation: "O Allah, send peace and blessings upon Muhammad and the family of Muhammad",
    category: "Salawat",
    defaultTarget: 100,
    aliases: ["اللهم صل على محمد وعلى ال محمد", "allahumma salli ala muhammadin wa ala ali muhammad"],
    normalizedArabic: "اللهم صل علي محمد وعلي ال محمد",
    isFavorite: false,
  ),
  DhikrDefinition(
    id: "allahumma_salli_wa_sallim",
    arabic: "ٱللّٰهُمَّ صَلِّ وَسَلِّمْ عَلَىٰ نَبِيِّنَا مُحَمَّدْ",
    transliteration: "Allahumma salli wa sallim 'ala Nabiyyina Muhammad",
    translation: "O Allah, send prayers and peace upon our Prophet Muhammad",
    category: "Salawat",
    defaultTarget: 100,
    aliases: ["اللهم صل وسلم على نبينا محمد", "allahumma salli wa sallim ala nabiyyina muhammad"],
    normalizedArabic: "اللهم صل وسلم علي نبينا محمد",
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
    final sanitizedDhikr = dhikr.copyWith(
      arabic: ArabicNormalizer.enforceSukunCoda(dhikr.arabic),
    );
    _items[sanitizedDhikr.id] = sanitizedDhikr;
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
