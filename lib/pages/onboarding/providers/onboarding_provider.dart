import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'onboarding_provider.g.dart';

// オンボーディングの現在のステップ
@Riverpod(keepAlive: true)
class OnboardingStep extends _$OnboardingStep {
  @override
  int build() => 0;

  void next() {
    if (state < 4) state++;
  }

  void previous() {
    if (state > 0) state--;
  }

  void goTo(int step) {
    if (step >= 0 && step <= 4) state = step;
  }
}

// オンボーディング中の一時データ
@Riverpod(keepAlive: true)
class OnboardingData extends _$OnboardingData {
  @override
  OnboardingFormData build() => const OnboardingFormData();

  void setDisplayName(String name) {
    state = state.copyWith(displayName: name);
  }

  void setTeamName(String name) {
    state = state.copyWith(teamName: name);
  }

  void setAvatarPreset(String? preset) {
    state = state.copyWith(avatarPreset: preset, avatarUrl: null);
  }

  void setAvatarUrl(String? url) {
    state = state.copyWith(avatarUrl: url, avatarPreset: null);
  }

  void setNotificationEnabled(bool enabled) {
    state = state.copyWith(notificationEnabled: enabled);
  }
}

class OnboardingFormData {
  static const Object _noChange = Object();

  final String displayName;
  final String teamName;
  final String? avatarPreset;
  final String? avatarUrl;
  final bool notificationEnabled;

  const OnboardingFormData({
    this.displayName = '',
    this.teamName = '',
    this.avatarPreset,
    this.avatarUrl,
    this.notificationEnabled = false,
  });

  OnboardingFormData copyWith({
    String? displayName,
    String? teamName,
    Object? avatarPreset = _noChange,
    Object? avatarUrl = _noChange,
    bool? notificationEnabled,
  }) {
    return OnboardingFormData(
      displayName: displayName ?? this.displayName,
      teamName: teamName ?? this.teamName,
      avatarPreset: identical(avatarPreset, _noChange)
          ? this.avatarPreset
          : avatarPreset as String?,
      avatarUrl: identical(avatarUrl, _noChange)
          ? this.avatarUrl
          : avatarUrl as String?,
      notificationEnabled: notificationEnabled ?? this.notificationEnabled,
    );
  }
}
