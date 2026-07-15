import 'supabase_service.dart';
import '../../core/config/app_constants.dart';

class GenerationLimitExceededException implements Exception {
  final String message;
  GenerationLimitExceededException(this.message);

  @override
  String toString() => message;
}

/// Calls the `generate-hairstyle` Supabase Edge Function.
///
/// All AI provider calls (Replicate / Fal.ai) happen server-side inside the
/// Edge Function - the client never sees the provider API key.
class AiGenerationService {
  Future<void> requestGeneration({
    required String sourcePhotoUrl,
    required String promptText,
    required String messageId,
    required String sessionId,
  }) async {
    try {
      final response = await SupabaseService.client.functions.invoke(
        AppConstants.generateHairstyleFunction,
        body: {
          'source_photo_url': sourcePhotoUrl,
          'prompt_text': promptText,
          'message_id': messageId,
          'session_id': sessionId,
        },
      );

      if (response.status == 429) {
        throw GenerationLimitExceededException(
          (response.data is Map && response.data['error'] != null)
              ? response.data['error'] as String
              : 'Лимит запросов исчерпан. Оформите подписку.',
        );
      }

      if (response.status != 200) {
        throw Exception(
          'Edge Function error (${response.status}): ${response.data}',
        );
      }
    } on GenerationLimitExceededException {
      rethrow;
    } catch (e) {
      throw Exception('Не удалось запустить генерацию: $e');
    }
  }
}
