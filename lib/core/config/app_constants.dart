class AppConstants {
  static const String chatMessagesTable = 'chat_messages';
  static const String chatSessionsTable = 'chat_sessions';
  static const String generationRequestsTable = 'generation_requests';
  static const String subscriptionsTable = 'subscriptions';
  static const String profilesTable = 'profiles';

  static const String sourcePhotosBucket = 'source-photos';

  static const String generateHairstyleFunction = 'generate-hairstyle';

  /// Free-tier request limit per billing period, mirrored in the DB
  /// (`subscriptions.tier` = 'free') and enforced server-side in the
  /// `generate-hairstyle` Edge Function. Keep this in sync manually.
  static const Map<String, int> tierRequestLimits = {
    'free': 3,
    'pro': 100,
    'max': 1000,
  };

  static const String photoConsentPrefsKey = 'photo_consent_accepted_v1';

  static const String themeModePrefsKey = 'theme_mode_v1';
}
