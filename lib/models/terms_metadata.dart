class TermsMetadata {
  final String version;
  final String effectiveDate;
  final String filePath;

  TermsMetadata({
    required this.version,
    required this.effectiveDate,
    required this.filePath,
  });

  factory TermsMetadata.fromMap(Map<String, dynamic> map) {
    return TermsMetadata(
      version: map['version'] ?? '1.0',
      effectiveDate: map['effectiveDate'] ?? '',
      filePath: map['filePath'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'version': version,
      'effectiveDate': effectiveDate,
      'filePath': filePath,
    };
  }
}

class TermsMetadataCollection {
  final TermsMetadata serviceTerms;
  final TermsMetadata privacyPolicy;

  TermsMetadataCollection({
    required this.serviceTerms,
    required this.privacyPolicy,
  });

  factory TermsMetadataCollection.fromMap(Map<String, dynamic> map) {
    return TermsMetadataCollection(
      serviceTerms: TermsMetadata.fromMap(
        map['serviceTerms'] ?? {},
      ),
      privacyPolicy: TermsMetadata.fromMap(
        map['privacyPolicy'] ?? {},
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'serviceTerms': serviceTerms.toMap(),
      'privacyPolicy': privacyPolicy.toMap(),
    };
  }
}
