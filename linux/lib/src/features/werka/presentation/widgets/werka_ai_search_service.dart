import '../../../../core/api/mobile_api.dart';
import '../../../../core/localization/app_localizations.dart';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class WerkaAiSearchException implements Exception {
  const WerkaAiSearchException(this.message);

  final String message;

  @override
  String toString() => message;
}

class WerkaAiSearchSuggestion {
  const WerkaAiSearchSuggestion({
    required this.displayQuery,
    required this.backgroundQueries,
    required this.visibleText,
  });

  final String displayQuery;
  final List<String> backgroundQueries;
  final String visibleText;
}

class WerkaAiSearchService {
  WerkaAiSearchService._();

  static final WerkaAiSearchService instance = WerkaAiSearchService._();

  final ImagePicker _picker = ImagePicker();

  Future<WerkaAiSearchSuggestion?> pickAndInferSuggestion(
    BuildContext context,
  ) async {
    final l10n = AppLocalizations.of(context);
    final source = await _pickSource(context);
    if (source == null) {
      return null;
    }

    XFile? image;
    try {
      image = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
    } catch (_) {
      throw WerkaAiSearchException(l10n.imagePickFailed);
    }
    if (image == null) {
      return null;
    }

    try {
      final payload = await MobileApi.instance.werkaAiSearchSuggestion(
        bytes: await image.readAsBytes(),
        filename: _normalizedFileName(image.name),
      );
      final backgroundQueries = _readBackgroundQueries(
        payload['background_queries'],
      );
      final displayQuery = _sanitizeText(payload['display_query']);
      final suggestion = WerkaAiSearchSuggestion(
        displayQuery: displayQuery.isNotEmpty
            ? displayQuery
            : (backgroundQueries.isNotEmpty ? backgroundQueries.first : ''),
        backgroundQueries: backgroundQueries,
        visibleText: _sanitizeText(payload['visible_text']),
      );
      if (suggestion.displayQuery.isEmpty &&
          suggestion.backgroundQueries.isEmpty) {
        throw WerkaAiSearchException(l10n.aiSearchNoResult);
      }
      return suggestion;
    } on MobileApiException catch (error) {
      switch (error.code) {
        case 'not_configured':
          throw WerkaAiSearchException(l10n.aiSearchNotConfigured);
        case 'no_result':
          throw WerkaAiSearchException(l10n.aiSearchNoResult);
        case 'invalid_image':
          throw WerkaAiSearchException(l10n.imagePickFailed);
        default:
          throw WerkaAiSearchException(
            l10n.aiSearchFailed(error.message),
          );
      }
    }
  }

  Future<ImageSource?> _pickSource(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return showModalBottomSheet<ImageSource>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded),
                title: Text(l10n.aiSearchTakePhoto),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: Text(l10n.aiSearchChoosePhoto),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );
  }

  List<String> _readBackgroundQueries(Object? raw) {
    if (raw is! List) {
      return const <String>[];
    }
    final values = <String>[];
    final seen = <String>{};
    for (final entry in raw) {
      final value = _sanitizeText(entry);
      if (value.isEmpty) {
        continue;
      }
      final key = value.toLowerCase();
      if (!seen.add(key)) {
        continue;
      }
      values.add(value);
    }
    return values;
  }

  String _sanitizeText(Object? raw) {
    if (raw is! String) {
      return '';
    }
    return raw.trim();
  }

  String _normalizedFileName(String raw) {
    final value = raw.trim();
    return value.isEmpty ? 'werka-ai-search.jpg' : value;
  }
}
