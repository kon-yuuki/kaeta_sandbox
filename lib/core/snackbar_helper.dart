import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../data/providers/notifications_provider.dart';
import 'theme/app_colors.dart';
import 'theme/app_typography.dart';
import 'widgets/app_button.dart';

/// 上部から表示される角丸のSnackBarを表示する
/// [action] を指定するとボタン付きになる
/// [saveToHistory] を true にすると通知履歴に保存される
/// [notificationType] で通知タイプを指定（0=通常30日保持, 1=買い物完了7日保持）
/// [familyId] で通知の家族スコープを指定（nullで個人）
void showTopSnackBar(
  BuildContext context,
  String message, {
  String? actionLabel,
  void Function(BuildContext context)? onAction,
  Duration duration = const Duration(seconds: 4),
  bool saveToHistory = false,
  int notificationType = 0,
  String? familyId,
  String? actorUserId,
  bool showCloseButton = false,
}) {
  // 通知履歴に保存
  if (saveToHistory) {
    final container = ProviderScope.containerOf(context, listen: false);
    final notificationsRepo = container.read(notificationsRepositoryProvider);
    notificationsRepo.publishNotification(
      message: message,
      type: notificationType,
      familyId: familyId,
      actorUserId: actorUserId,
    );
  }
  final overlay = Overlay.of(context);
  late OverlayEntry entry;

  entry = OverlayEntry(
    builder: (overlayContext) => _TopSnackBarWidget(
      message: message,
      actionLabel: actionLabel,
      onAction: () {
        entry.remove();
        onAction?.call(overlayContext);
      },
      showCloseButton: showCloseButton,
      onDismissed: () => entry.remove(),
      duration: duration,
    ),
  );

  overlay.insert(entry);
}

class _TopSnackBarWidget extends StatefulWidget {
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool showCloseButton;
  final VoidCallback onDismissed;
  final Duration duration;

  const _TopSnackBarWidget({
    required this.message,
    this.actionLabel,
    this.onAction,
    this.showCloseButton = false,
    required this.onDismissed,
    required this.duration,
  });

  @override
  State<_TopSnackBarWidget> createState() => _TopSnackBarWidgetState();
}

class _TopSnackBarWidgetState extends State<_TopSnackBarWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(_controller);

    _controller.forward();

    Future.delayed(widget.duration, () {
      if (mounted && !_dismissed) {
        _dismiss();
      }
    });
  }

  void _dismiss() {
    if (_dismissed) return;
    _dismissed = true;
    _controller.reverse().then((_) => widget.onDismissed());
  }

  void _handleSwipeDismiss({
    double? primaryVelocity,
    double? velocity,
  }) {
    final v = primaryVelocity ?? velocity ?? 0;
    if (v.abs() > 180) {
      _dismiss();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    final topPadding = MediaQuery.of(context).padding.top;
    return Positioned(
      top: topPadding + 10,
      left: 20,
      right: 20,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onVerticalDragEnd: (details) {
                _handleSwipeDismiss(primaryVelocity: details.primaryVelocity);
              },
              onHorizontalDragEnd: (details) {
                _handleSwipeDismiss(velocity: details.primaryVelocity);
              },
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDFCF9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF2ECCA1), width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        widget.message,
                        style: typography.std14R160.copyWith(
                          color: colors.textHigh,
                        ),
                      ),
                    ),
                    if (widget.actionLabel != null)
                      AppButton(
                        variant: AppButtonVariant.text,
                        onPressed: widget.onAction,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          widget.actionLabel!,
                          style: typography.jaOnl12B100.copyWith(
                            color: colors.textAccentPrimary,
                          ),
                        ),
                      ),
                    if (widget.showCloseButton)
                      InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: _dismiss,
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: Center(
                            child: SvgPicture.asset(
                              'assets/icons/cross.svg',
                              width: 14,
                              height: 14,
                              colorFilter: ColorFilter.mode(
                                colors.surfaceMedium,
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
