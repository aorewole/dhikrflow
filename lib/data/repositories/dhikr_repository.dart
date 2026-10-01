import '../../domain/models/dhikr_definition.dart';

/// Repository interface for Dhikr definitions.
abstract interface class DhikrRepository {
  List<DhikrDefinition> getAll();
  DhikrDefinition? getById(String id);
  List<DhikrDefinition> getByCategory(String category);
  List<DhikrDefinition> getFavorites();
  List<String> getCategories();
  void toggleFavorite(String id);
}

/// In-memory repository seeded with validated canonical short adhkar.
class InMemoryDhikrRepository implements DhikrRepository {
  final Map<String, DhikrDefinition> _items = {};

  InMemoryDhikrRepository() {
    _seedDefaultItems();
  }

  void _seedDefaultItems() {
    final list = [
      const DhikrDefinition(
        id: 'astaghfirullah',
        arabic: 'أَسْتَغْفِرُ ٱللَّٰهَ',
        transliteration: 'Astaghfirullah',
        translation: 'I seek forgiveness from Allah',
        category: 'Forgiveness',
        defaultTarget: 100,
        aliases: ['Astaghfirullahal Azeem'],
        normalizedArabic: 'استغفر الله',
        isFavorite: true,
      ),
      const DhikrDefinition(
        id: 'subhanallah',
        arabic: 'سُبْحَانَ ٱللَّٰهِ',
        transliteration: 'SubhanAllah',
        translation: 'Glory be to Allah',
        category: 'Tasbih',
        defaultTarget: 33,
        aliases: [],
        normalizedArabic: 'سبحان الله',
        isFavorite: true,
      ),
      const DhikrDefinition(
        id: 'alhamdulillah',
        arabic: 'ٱلْحَمْدُ لِلَّٰهِ',
        transliteration: 'Alhamdulillah',
        translation: 'All praise is due to Allah',
        category: 'Tahmid',
        defaultTarget: 33,
        aliases: [],
        normalizedArabic: 'الحمد لله',
        isFavorite: true,
      ),
      const DhikrDefinition(
        id: 'allahu_akbar',
        arabic: 'ٱللَّٰهُ أَكْبَرُ',
        transliteration: 'Allahu Akbar',
        translation: 'Allah is the Greatest',
        category: 'Takbir',
        defaultTarget: 33,
        aliases: [],
        normalizedArabic: 'الله اكبر',
        isFavorite: true,
      ),
      const DhikrDefinition(
        id: 'la_ilaha_illallah',
        arabic: 'لَا إِلَٰهَ إِلَّا ٱللَّٰهُ',
        transliteration: 'La ilaha illallah',
        translation: 'There is no god but Allah',
        category: 'Tahlil',
        defaultTarget: 100,
        aliases: [],
        normalizedArabic: 'لا اله الا الله',
      ),
      const DhikrDefinition(
        id: 'subhanallahi_wa_bihamdihi',
        arabic: 'سُبْحَانَ ٱللَّٰهِ وَبِحَمْدِهِ',
        transliteration: 'SubhanAllahi wa bihamdihi',
        translation: 'Glory be to Allah and His is the praise',
        category: 'Tasbih',
        defaultTarget: 100,
        aliases: [],
        normalizedArabic: 'سبحان الله وبحمده',
      ),
      const DhikrDefinition(
        id: 'la_hawla',
        arabic: 'لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِٱللَّٰهِ',
        transliteration: 'La hawla wa la quwwata illa billah',
        translation: 'There is no power nor strength except with Allah',
        category: 'Hawqalah',
        defaultTarget: 100,
        aliases: [],
        normalizedArabic: 'لا حول ولا قوة الا بالله',
      ),
    ];

    for (final item in list) {
      _items[item.id] = item;
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
    return _items.values.where((d) => d.isFavorite).toList();
  }

  @override
  List<String> getCategories() {
    return _items.values.map((d) => d.category).toSet().toList();
  }

  @override
  void toggleFavorite(String id) {
    final item = _items[id];
    if (item != null) {
      _items[id] = item.copyWith(isFavorite: !item.isFavorite);
    }
  }
}
