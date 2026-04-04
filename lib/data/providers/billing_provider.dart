import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/billing_service.dart';

enum BillingDebugOverride {
  system,
  forceFree,
  forceExpired,
  forceBasic,
  forceBasicCanceling,
  forcePremium,
  forcePremiumCanceling,
  forcePremiumTrial,
}

enum AppPlan { free, basic, premium }

enum BillingLifecycle {
  neverSubscribed,
  trialing,
  active,
  canceling,
  expired,
}

class BillingPlanLimits {
  static const int freeCategoryLimit = 3;
  static const int basicCategoryLimit = 5;
  static const int freePurchaseHistoryRetentionDays = 7;
  static const int basicPurchaseHistoryRetentionDays = 14;
  static const int premiumPurchaseHistoryRetentionDays = 365;
}

class BillingState {
  BillingState({
    required this.systemPlan,
    required this.systemLifecycle,
    required this.systemIsInTrial,
    required this.trialEndsAt,
    required this.accessEndsAt,
    required this.debugOverride,
    required this.isLoading,
    required this.isRevenueCatAvailable,
  });

  BillingState.initial()
    : systemPlan = AppPlan.free,
      systemLifecycle = BillingLifecycle.neverSubscribed,
      systemIsInTrial = false,
      trialEndsAt = null,
      accessEndsAt = null,
      debugOverride = BillingDebugOverride.system,
      isLoading = true,
      isRevenueCatAvailable = BillingService.isSupported;

  final AppPlan systemPlan;
  final BillingLifecycle systemLifecycle;
  final bool systemIsInTrial;
  final DateTime? trialEndsAt;
  final DateTime? accessEndsAt;
  final BillingDebugOverride debugOverride;
  final bool isLoading;
  final bool isRevenueCatAvailable;

  AppPlan get effectivePlan {
    switch (debugOverride) {
      case BillingDebugOverride.forceFree:
      case BillingDebugOverride.forceExpired:
        return AppPlan.free;
      case BillingDebugOverride.forceBasic:
      case BillingDebugOverride.forceBasicCanceling:
        return AppPlan.basic;
      case BillingDebugOverride.forcePremium:
      case BillingDebugOverride.forcePremiumCanceling:
      case BillingDebugOverride.forcePremiumTrial:
        return AppPlan.premium;
      case BillingDebugOverride.system:
        return systemPlan;
    }
  }

  BillingLifecycle get effectiveLifecycle {
    switch (debugOverride) {
      case BillingDebugOverride.forceFree:
        return BillingLifecycle.neverSubscribed;
      case BillingDebugOverride.forceExpired:
        return BillingLifecycle.expired;
      case BillingDebugOverride.forceBasic:
      case BillingDebugOverride.forcePremium:
        return BillingLifecycle.active;
      case BillingDebugOverride.forceBasicCanceling:
      case BillingDebugOverride.forcePremiumCanceling:
        return BillingLifecycle.canceling;
      case BillingDebugOverride.forcePremiumTrial:
        return BillingLifecycle.trialing;
      case BillingDebugOverride.system:
        return systemLifecycle;
    }
  }

  bool get hasBasicOrAbove => effectivePlan != AppPlan.free;
  bool get hasPremium => effectivePlan == AppPlan.premium;
  bool get isInTrial => effectiveLifecycle == BillingLifecycle.trialing;
  bool get isCanceling => effectiveLifecycle == BillingLifecycle.canceling;
  bool get isExpired => effectiveLifecycle == BillingLifecycle.expired;
  bool get isNeverSubscribed =>
      effectiveLifecycle == BillingLifecycle.neverSubscribed;

  DateTime? get effectiveAccessEndsAt {
    switch (debugOverride) {
      case BillingDebugOverride.forceBasicCanceling:
      case BillingDebugOverride.forcePremiumCanceling:
        return DateTime.now().add(const Duration(days: 30));
      case BillingDebugOverride.system:
        return accessEndsAt;
      case BillingDebugOverride.forceFree:
      case BillingDebugOverride.forceExpired:
      case BillingDebugOverride.forceBasic:
      case BillingDebugOverride.forcePremium:
      case BillingDebugOverride.forcePremiumTrial:
        return null;
    }
  }

  int? get categoryLimit {
    switch (effectivePlan) {
      case AppPlan.free:
        return BillingPlanLimits.freeCategoryLimit;
      case AppPlan.basic:
        return BillingPlanLimits.basicCategoryLimit;
      case AppPlan.premium:
        return null;
    }
  }

  int get purchaseHistoryRetentionDays {
    switch (effectivePlan) {
      case AppPlan.free:
        return BillingPlanLimits.freePurchaseHistoryRetentionDays;
      case AppPlan.basic:
        return BillingPlanLimits.basicPurchaseHistoryRetentionDays;
      case AppPlan.premium:
        return BillingPlanLimits.premiumPurchaseHistoryRetentionDays;
    }
  }

  String get purchaseHistoryWindowLabel {
    switch (effectivePlan) {
      case AppPlan.free:
        return '最新1週間';
      case AppPlan.basic:
        return '最新2週間';
      case AppPlan.premium:
        return '最新1年';
    }
  }

  String get planLabel {
    final baseLabel = switch (effectivePlan) {
      AppPlan.free => '無料プラン',
      AppPlan.basic => 'ベーシックプラン',
      AppPlan.premium => 'プレミアムプラン',
    };

    if (isInTrial && effectivePlan == AppPlan.premium) {
      return '$baseLabel 無料体験中';
    }
    if (isCanceling && effectivePlan != AppPlan.free) {
      return '$baseLabel 解約手続き中';
    }
    if (isExpired) {
      return '無料プラン（解約後）';
    }

    return baseLabel;
  }

  String? get lifecycleLabel {
    switch (effectiveLifecycle) {
      case BillingLifecycle.trialing:
        return trialStatusLabel;
      case BillingLifecycle.canceling:
        return cancellationStatusLabel;
      case BillingLifecycle.expired:
        return '解約済みのため無料プランとして利用中です';
      case BillingLifecycle.neverSubscribed:
      case BillingLifecycle.active:
        return null;
    }
  }

  String? get trialStatusLabel {
    if (!isInTrial || trialEndsAt == null) return null;
    final year = trialEndsAt!.year;
    final month = trialEndsAt!.month;
    final day = trialEndsAt!.day;
    return '無料体験は$year/$month/$dayまで';
  }

  String? get cancellationStatusLabel {
    final endsAt = effectiveAccessEndsAt;
    if (!isCanceling || endsAt == null) return '次回更新時に解約されます';
    final year = endsAt.year;
    final month = endsAt.month;
    final day = endsAt.day;
    return 'サブスクリプションは$year/$month/$dayに解約されます';
  }

  BillingState copyWith({
    AppPlan? systemPlan,
    BillingLifecycle? systemLifecycle,
    bool? systemIsInTrial,
    DateTime? trialEndsAt,
    DateTime? accessEndsAt,
    bool clearAccessEndsAt = false,
    bool clearTrialEndsAt = false,
    BillingDebugOverride? debugOverride,
    bool? isLoading,
    bool? isRevenueCatAvailable,
  }) {
    return BillingState(
      systemPlan: systemPlan ?? this.systemPlan,
      systemLifecycle: systemLifecycle ?? this.systemLifecycle,
      systemIsInTrial: systemIsInTrial ?? this.systemIsInTrial,
      trialEndsAt: clearTrialEndsAt ? null : (trialEndsAt ?? this.trialEndsAt),
      accessEndsAt: clearAccessEndsAt ? null : (accessEndsAt ?? this.accessEndsAt),
      debugOverride: debugOverride ?? this.debugOverride,
      isLoading: isLoading ?? this.isLoading,
      isRevenueCatAvailable:
          isRevenueCatAvailable ?? this.isRevenueCatAvailable,
    );
  }
}

class BillingSnapshot {
  const BillingSnapshot({
    required this.plan,
    required this.lifecycle,
    required this.isInTrial,
    required this.trialEndsAt,
    required this.accessEndsAt,
  });

  final AppPlan plan;
  final BillingLifecycle lifecycle;
  final bool isInTrial;
  final DateTime? trialEndsAt;
  final DateTime? accessEndsAt;
}

class BillingController extends StateNotifier<BillingState> {
  BillingController() : super(BillingState.initial()) {
    _initialize();
  }

  static const String _overridePrefsKey = 'billing_debug_override';

  Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final rawValue = prefs.getString(_overridePrefsKey);
    final debugOverride = BillingDebugOverride.values.firstWhere(
      (value) => value.name == rawValue,
      orElse: () => BillingDebugOverride.system,
    );

    state = state.copyWith(
      debugOverride: debugOverride,
      isLoading: false,
      isRevenueCatAvailable: BillingService.isSupported,
    );

    await refresh();
  }

  Future<void> refresh() async {
    if (!BillingService.isSupported) {
      state = state.copyWith(
        systemPlan: AppPlan.free,
        systemLifecycle: BillingLifecycle.neverSubscribed,
        systemIsInTrial: false,
        clearTrialEndsAt: true,
        clearAccessEndsAt: true,
        isLoading: false,
        isRevenueCatAvailable: false,
      );
      return;
    }

    try {
      final customerInfo = await BillingService.getCustomerInfo();
      final snapshot = _snapshotFromCustomerInfo(customerInfo);
      state = state.copyWith(
        systemPlan: snapshot.plan,
        systemLifecycle: snapshot.lifecycle,
        systemIsInTrial: snapshot.isInTrial,
        trialEndsAt: snapshot.trialEndsAt,
        accessEndsAt: snapshot.accessEndsAt,
        clearTrialEndsAt: snapshot.trialEndsAt == null,
        clearAccessEndsAt: snapshot.accessEndsAt == null,
        isLoading: false,
        isRevenueCatAvailable: true,
      );
    } catch (e, st) {
      debugPrint('RevenueCat refresh failed: $e');
      debugPrint('$st');
      state = state.copyWith(isLoading: false, isRevenueCatAvailable: true);
    }
  }

  Future<void> handleSignedIn(String userId) async {
    if (!BillingService.isSupported || userId.isEmpty) return;
    try {
      await BillingService.logIn(userId);
    } catch (e, st) {
      debugPrint('RevenueCat logIn failed: $e');
      debugPrint('$st');
    }
    await refresh();
  }

  Future<void> handleSignedOut() async {
    if (BillingService.isSupported) {
      try {
        await BillingService.logOut();
      } catch (e, st) {
        debugPrint('RevenueCat logOut failed: $e');
        debugPrint('$st');
      }
    }

    state = state.copyWith(
      systemPlan: AppPlan.free,
      systemLifecycle: BillingLifecycle.neverSubscribed,
      systemIsInTrial: false,
      clearTrialEndsAt: true,
      clearAccessEndsAt: true,
    );
  }

  Future<void> setDebugOverride(BillingDebugOverride value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_overridePrefsKey, value.name);
    state = state.copyWith(debugOverride: value);
  }

  Future<bool> purchasePackageByIdentifier(String packageIdentifier) async {
    if (!BillingService.isSupported) return false;

    try {
      final offerings = await BillingService.getOfferings();
      final currentOffering = offerings?.current;
      if (currentOffering == null) {
        debugPrint('RevenueCat current offering not found.');
        return false;
      }

      final package = currentOffering.availablePackages
          .where((candidate) => candidate.identifier == packageIdentifier)
          .firstOrNull;
      if (package == null) {
        debugPrint('RevenueCat package not found: $packageIdentifier');
        return false;
      }

      final customerInfo = await BillingService.purchasePackage(package);
      final snapshot = _snapshotFromCustomerInfo(customerInfo);
      state = state.copyWith(
        systemPlan: snapshot.plan,
        systemLifecycle: snapshot.lifecycle,
        systemIsInTrial: snapshot.isInTrial,
        trialEndsAt: snapshot.trialEndsAt,
        accessEndsAt: snapshot.accessEndsAt,
        clearTrialEndsAt: snapshot.trialEndsAt == null,
        clearAccessEndsAt: snapshot.accessEndsAt == null,
      );
      return true;
    } on PlatformException catch (e, st) {
      final wasCancelled =
          e.code == '1' ||
          e.code == 'purchaseCancelledError' ||
          e.code == 'PURCHASE_CANCELLED';
      if (wasCancelled) {
        debugPrint('RevenueCat purchase cancelled: ${e.message}');
        return false;
      }
      debugPrint('RevenueCat purchase failed: $e');
      debugPrint('$st');
      return false;
    } catch (e, st) {
      debugPrint('RevenueCat purchase failed: $e');
      debugPrint('$st');
      return false;
    }
  }

  Future<bool> restore() async {
    if (!BillingService.isSupported) return false;

    try {
      final customerInfo = await BillingService.restorePurchases();
      final snapshot = _snapshotFromCustomerInfo(customerInfo);
      state = state.copyWith(
        systemPlan: snapshot.plan,
        systemLifecycle: snapshot.lifecycle,
        systemIsInTrial: snapshot.isInTrial,
        trialEndsAt: snapshot.trialEndsAt,
        accessEndsAt: snapshot.accessEndsAt,
        clearTrialEndsAt: snapshot.trialEndsAt == null,
        clearAccessEndsAt: snapshot.accessEndsAt == null,
      );
      return true;
    } catch (e, st) {
      debugPrint('RevenueCat restore failed: $e');
      debugPrint('$st');
      return false;
    }
  }

  BillingSnapshot _snapshotFromCustomerInfo(CustomerInfo? customerInfo) {
    if (customerInfo == null) {
      return const BillingSnapshot(
        plan: AppPlan.free,
        lifecycle: BillingLifecycle.neverSubscribed,
        isInTrial: false,
        trialEndsAt: null,
        accessEndsAt: null,
      );
    }

    final entitlements = customerInfo.entitlements.active;
    final premiumEntitlement = entitlements['premium'];
    if (premiumEntitlement != null) {
      final isInTrial = premiumEntitlement.periodType == PeriodType.trial;
      final trialEndsAt = isInTrial
          ? DateTime.tryParse(premiumEntitlement.expirationDate ?? '')
          : null;
      final accessEndsAt = DateTime.tryParse(
        premiumEntitlement.expirationDate ?? '',
      );
      return BillingSnapshot(
        plan: AppPlan.premium,
        lifecycle: isInTrial
            ? BillingLifecycle.trialing
            : (premiumEntitlement.willRenew
                  ? BillingLifecycle.active
                  : BillingLifecycle.canceling),
        isInTrial: isInTrial,
        trialEndsAt: trialEndsAt,
        accessEndsAt: accessEndsAt,
      );
    }

    final basicEntitlement = entitlements['basic'];
    if (basicEntitlement != null) {
      return BillingSnapshot(
        plan: AppPlan.basic,
        lifecycle: basicEntitlement.willRenew
            ? BillingLifecycle.active
            : BillingLifecycle.canceling,
        isInTrial: false,
        trialEndsAt: null,
        accessEndsAt: DateTime.tryParse(basicEntitlement.expirationDate ?? ''),
      );
    }

    final allEntitlements = customerInfo.entitlements.all;
    final hasBillingHistory =
        allEntitlements.containsKey('premium') ||
        allEntitlements.containsKey('basic') ||
        customerInfo.allPurchasedProductIdentifiers.contains('premium') ||
        customerInfo.allPurchasedProductIdentifiers.contains('basic');

    if (hasBillingHistory) {
      return const BillingSnapshot(
        plan: AppPlan.free,
        lifecycle: BillingLifecycle.expired,
        isInTrial: false,
        trialEndsAt: null,
        accessEndsAt: null,
      );
    }

    return const BillingSnapshot(
      plan: AppPlan.free,
      lifecycle: BillingLifecycle.neverSubscribed,
      isInTrial: false,
      trialEndsAt: null,
      accessEndsAt: null,
    );
  }
}

final billingControllerProvider =
    StateNotifierProvider<BillingController, BillingState>(
      (ref) => BillingController(),
    );

final categoryLimitProvider = Provider<int?>((ref) {
  return ref.watch(billingControllerProvider).categoryLimit;
});
