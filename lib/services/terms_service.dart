import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/terms_metadata.dart';

class TermsService {
  static const String _metadataPath = 'assets/terms/metadata.json';

  TermsMetadataCollection? _cachedMetadata;

  Future<TermsMetadataCollection> loadMetadata() async {
    if (_cachedMetadata != null) {
      return _cachedMetadata!;
    }

    try {
      final String jsonString = await rootBundle.loadString(_metadataPath);
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      _cachedMetadata = TermsMetadataCollection.fromMap(jsonData);
      return _cachedMetadata!;
    } catch (e) {
      // Fallback to default values if metadata file is not found
      return TermsMetadataCollection(
        serviceTerms: TermsMetadata(
          version: '1.0',
          effectiveDate: '2025-12-18',
          filePath: 'assets/terms/service_terms.md',
        ),
        privacyPolicy: TermsMetadata(
          version: '1.0',
          effectiveDate: '2025-12-18',
          filePath: 'assets/terms/privacy_policy.md',
        ),
      );
    }
  }

  Future<String> loadServiceTerms() async {
    try {
      final metadata = await loadMetadata();
      return await rootBundle.loadString(metadata.serviceTerms.filePath);
    } catch (e) {
      return '약관을 불러올 수 없습니다.';
    }
  }

  Future<String> loadPrivacyPolicy() async {
    try {
      final metadata = await loadMetadata();
      return await rootBundle.loadString(metadata.privacyPolicy.filePath);
    } catch (e) {
      return '개인정보처리방침을 불러올 수 없습니다.';
    }
  }

  String getCurrentServiceTermsVersion() {
    return _cachedMetadata?.serviceTerms.version ?? '1.0';
  }

  String getCurrentPrivacyPolicyVersion() {
    return _cachedMetadata?.privacyPolicy.version ?? '1.0';
  }
}
