class AppConstants {
  static const String chatMessagesTable = 'chat_messages';
  static const String chatSessionsTable = 'chat_sessions';
  static const String generationRequestsTable = 'generation_requests';
  static const String generationSettingsTable = 'generation_settings';
  static const String subscriptionsTable = 'subscriptions';
  static const String profilesTable = 'profiles';
  static const String favoritePhotosTable = 'favorite_photos';
  static const String bugReportsTable = 'bug_reports';

  static const String sourcePhotosBucket = 'source-photos';

  static const String generateHairstyleFunction = 'generate-hairstyle';
  static const String cancelGenerationFunction = 'cancel-generation';
  static const String deleteAccountFunction = 'delete-account';

  static const Map<String, int> tierRequestLimits = {
    'free': 3,
    'pro': 3,
    'max': 1000,
  };

  static const String variantCountPrefsKey = 'variant_count_v1';

  static const String themeModePrefsKey = 'theme_mode_v1';

  static const String photoConsentPrefsKey = 'photo_consent_v1';
}