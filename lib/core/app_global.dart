import 'package:powersync/powersync.dart';
import './app_config.dart';

class AppGlobals {
  final PowerSyncDatabase db;
  final AppConfig config;

  AppGlobals({required this.db, required this.config});
}