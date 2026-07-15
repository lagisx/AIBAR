import '../../core/config/app_constants.dart';
import '../models/subscription.dart';
import '../services/supabase_service.dart';

class SubscriptionRepository {
  String get _userId {
    final id = SupabaseService.currentUser?.id;
    if (id == null) throw Exception('Пользователь не авторизован');
    return id;
  }

  Future<Subscription> fetchCurrent() async {
    final row = await SupabaseService.client
        .from(AppConstants.subscriptionsTable)
        .select()
        .eq('user_id', _userId)
        .maybeSingle();

    if (row == null) {
      return Subscription(
        userId: _userId,
        tier: SubscriptionTier.free,
        requestsUsedThisPeriod: 0,
        periodResetAt: DateTime.now().add(const Duration(days: 30)),
        status: 'active',
      );
    }
    return Subscription.fromMap(row);
  }

  /// Mock "checkout": just flips the tier in the DB, no real payment.
  Future<void> mockUpgrade(SubscriptionTier tier) async {
    await SupabaseService.client.from(AppConstants.subscriptionsTable).upsert({
      'user_id': _userId,
      'tier': tier.name,
    });
  }

  bool hasReachedLimit(Subscription subscription) {
    final limit = AppConstants.tierRequestLimits[subscription.tier.name] ?? 0;
    return subscription.requestsUsedThisPeriod >= limit;
  }
}
