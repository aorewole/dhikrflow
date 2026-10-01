/// Canonical representation of a Dhikr item.
class DhikrDefinition {
  final String id;
  final String arabic;
  final String transliteration;
  final String translation;
  final String category;
  final int? defaultTarget;
  final List<String> aliases;
  final String normalizedArabic;
  final bool isFavorite;

  const DhikrDefinition({
    required this.id,
    required this.arabic,
    required this.transliteration,
    required this.translation,
    required this.category,
    this.defaultTarget,
    this.aliases = const [],
    required this.normalizedArabic,
    this.isFavorite = false,
  });

  DhikrDefinition copyWith({
    String? id,
    String? arabic,
    String? transliteration,
    String? translation,
    String? category,
    int? defaultTarget,
    List<String>? aliases,
    String? normalizedArabic,
    bool? isFavorite,
  }) {
    return DhikrDefinition(
      id: id ?? this.id,
      arabic: arabic ?? this.arabic,
      transliteration: transliteration ?? this.transliteration,
      translation: translation ?? this.translation,
      category: category ?? this.category,
      defaultTarget: defaultTarget ?? this.defaultTarget,
      aliases: aliases ?? this.aliases,
      normalizedArabic: normalizedArabic ?? this.normalizedArabic,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DhikrDefinition &&
          runtimeType == other.runtimeType &&
          id == other.id;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'arabic': arabic,
      'transliteration': transliteration,
      'translation': translation,
      'category': category,
      'defaultTarget': defaultTarget,
      'aliases': aliases,
      'normalizedArabic': normalizedArabic,
      'isFavorite': isFavorite,
    };
  }

  factory DhikrDefinition.fromJson(Map<String, dynamic> json) {
    return DhikrDefinition(
      id: json['id'] as String,
      arabic: json['arabic'] as String,
      transliteration: json['transliteration'] as String,
      translation: json['translation'] as String,
      category: json['category'] as String,
      defaultTarget: json['defaultTarget'] as int?,
      aliases: (json['aliases'] as List<dynamic>?)?.cast<String>() ?? const [],
      normalizedArabic: json['normalizedArabic'] as String,
      isFavorite: json['isFavorite'] as bool? ?? false,
    );
  }

  @override
  int get hashCode => id.hashCode;
}
