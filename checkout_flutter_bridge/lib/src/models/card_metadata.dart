/// Card metadata model from from platform channels
class CardMetadata {
  CardMetadata({
    required this.bin,
    required this.scheme,
    required this.type,
    required this.category,
    required this.issuer,
    required this.issuerCountry,
    required this.issuerCountryName,
  });

  final String bin;
  final String scheme;
  final String type;
  final String category;
  final String issuer;
  final String issuerCountry;
  final String issuerCountryName;

  factory CardMetadata.fromMap(Map<String, dynamic> map) {
    return CardMetadata(
      bin: map['bin'] as String? ?? '',
      scheme: map['scheme'] as String? ?? '',
      type: map['type'] as String? ?? '',
      category: map['category'] as String? ?? '',
      issuer: map['issuer'] as String? ?? '',
      issuerCountry: map['issuer_country'] as String? ?? '',
      issuerCountryName: map['issuer_country_name'] as String? ?? '',
    );
  }

  @override
  String toString() {
    return 'CardMetadata(bin: $bin, scheme: $scheme, type: $type, category: $category, issuer: $issuer, issuerCountry: $issuerCountry, issuerCountryName: $issuerCountryName)';
  }
}
