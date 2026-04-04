import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../core/app_config.dart';

class BillingService {
  static bool _configured = false;
  static bool _pluginAvailable = true;

  static bool get isSupported => Platform.isIOS;
  static bool get isAvailable => isSupported && _pluginAvailable;

  static Future<void> configure({String? appUserId}) async {
    if (!isSupported || !_pluginAvailable || _configured) return;

    try {
      final apiKey = AppConfig.revenueCatApplePublicSdkKey;
      if (apiKey.isEmpty) {
        debugPrint(
          'RevenueCat configure skipped: production SDK key is missing for this build.',
        );
        return;
      }

      await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.info);

      final configuration = PurchasesConfiguration(apiKey);
      if (appUserId != null && appUserId.isNotEmpty) {
        configuration.appUserID = appUserId;
      }

      await Purchases.configure(configuration);
      _configured = true;
    } on MissingPluginException catch (e, st) {
      _pluginAvailable = false;
      debugPrint('RevenueCat plugin unavailable. Full rebuild required: $e');
      debugPrint('$st');
    }
  }

  static Future<void> logIn(String userId) async {
    if (!isAvailable || userId.isEmpty) return;
    await configure();
    if (!_configured) return;
    await Purchases.logIn(userId);
  }

  static Future<void> logOut() async {
    if (!isAvailable || !_configured) return;
    await Purchases.logOut();
  }

  static Future<CustomerInfo?> getCustomerInfo() async {
    if (!isAvailable) return null;
    await configure();
    if (!_configured) return null;
    return Purchases.getCustomerInfo();
  }

  static Future<Offerings?> getOfferings() async {
    if (!isAvailable) return null;
    await configure();
    if (!_configured) return null;
    return Purchases.getOfferings();
  }

  static Future<CustomerInfo?> purchasePackage(Package package) async {
    if (!isAvailable) return null;
    await configure();
    if (!_configured) return null;
    final result = await Purchases.purchase(PurchaseParams.package(package));
    return result.customerInfo;
  }

  static Future<CustomerInfo?> restorePurchases() async {
    if (!isAvailable) return null;
    await configure();
    if (!_configured) return null;
    return Purchases.restorePurchases();
  }
}
