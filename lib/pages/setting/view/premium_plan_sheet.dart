import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/snackbar_helper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_selection.dart';
import '../../../data/providers/billing_provider.dart';

Future<void> openPremiumPlanPage(
  BuildContext context, {
  bool scrollToCoinSection = false,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) =>
          PremiumPlanPage(scrollToCoinSectionOnOpen: scrollToCoinSection),
    ),
  );
}

class PremiumPlanPage extends ConsumerStatefulWidget {
  const PremiumPlanPage({super.key, this.scrollToCoinSectionOnOpen = false});

  final bool scrollToCoinSectionOnOpen;

  @override
  ConsumerState<PremiumPlanPage> createState() => _PremiumPlanPageState();
}

class _PremiumPlanPageState extends ConsumerState<PremiumPlanPage> {
  static final Uri _manageSubscriptionsUri = Uri.parse(
    'https://apps.apple.com/account/subscriptions',
  );
  static final Uri _faqMoreUri = Uri.parse(
    'https://invented-bamboo-37c.notion.site/34526c0ce325805ca765fcbfc0d8a752?source=copy_link',
  );
  static final Uri _privacyPolicyUri = Uri.parse(
    'https://invented-bamboo-37c.notion.site/34426c0ce3258076b8b8f715ab2ae0a0?source=copy_link',
  );
  static final Uri _termsOfServiceUri = Uri.parse(
    'https://invented-bamboo-37c.notion.site/34426c0ce32580709576c7c1b654a3e9?source=copy_link',
  );
  late final PageController _sharedController;
  late final PageController _exclusiveController;
  late final ScrollController _scrollController;
  final GlobalKey _coinSectionKey = GlobalKey();
  AppPlan _showcasePlan = AppPlan.premium;
  AppPlan _selectedPlan = AppPlan.premium;
  final Set<int> _expandedFaqIndexes = <int>{};
  bool _isPurchasing = false;

  @override
  void initState() {
    super.initState();
    _sharedController = PageController();
    _exclusiveController = PageController();
    _scrollController = ScrollController();
    final billingState = ref.read(billingControllerProvider);
    if (billingState.effectivePlan == AppPlan.basic) {
      _showcasePlan = AppPlan.basic;
      _selectedPlan = AppPlan.basic;
    } else if (billingState.effectivePlan == AppPlan.premium ||
        billingState.isInTrial) {
      _showcasePlan = AppPlan.premium;
      _selectedPlan = AppPlan.premium;
    }
    if (widget.scrollToCoinSectionOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await Future<void>.delayed(const Duration(milliseconds: 120));
        if (!mounted) return;
        await _scrollToCoinSection();
      });
    }
  }

  @override
  void dispose() {
    _sharedController.dispose();
    _exclusiveController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _scrollToCoinSection() async {
    final targetContext = _coinSectionKey.currentContext;
    if (targetContext == null) return;
    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
  }

  void _selectPlan(AppPlan plan) {
    if (_selectedPlan == plan) return;
    setState(() => _selectedPlan = plan);
  }

  void _selectShowcasePlan(AppPlan plan) {
    if (_showcasePlan == plan && _selectedPlan == plan) return;
    setState(() {
      _showcasePlan = plan;
      _selectedPlan = plan;
    });
  }

  String get _selectedPackageIdentifier {
    switch (_selectedPlan) {
      case AppPlan.basic:
        return 'basic';
      case AppPlan.premium:
        return 'premium';
      case AppPlan.free:
        return 'basic';
    }
  }

  String get _selectedPlanLabel {
    switch (_selectedPlan) {
      case AppPlan.basic:
        return 'ベーシックプラン';
      case AppPlan.premium:
        return 'プレミアムプラン';
      case AppPlan.free:
        return 'ベーシックプラン';
    }
  }

  String get _selectedCtaLabel {
    final billingState = ref.read(billingControllerProvider);
    if (billingState.isExpired) {
      return 'プランをはじめる';
    }
    if (billingState.isInTrial ||
        ((billingState.effectivePlan == AppPlan.premium ||
                billingState.effectivePlan == AppPlan.basic) &&
            !billingState.isInTrial)) {
      return 'プランを変更する';
    }
    switch (_selectedPlan) {
      case AppPlan.premium:
        return '2週間無料体験をはじめる';
      case AppPlan.basic:
        return 'ベーシックプランをはじめる';
      case AppPlan.free:
        return 'ベーシックプランをはじめる';
    }
  }

  String get _selectedCtaNote {
    final billingState = ref.read(billingControllerProvider);
    if (billingState.isExpired) {
      return '';
    }
    if (billingState.isInTrial && _selectedPlan == AppPlan.basic) {
      return '体験終了まではプレミアム機能をご利用できます\n終了後に¥400/月で課金開始';
    }
    if (billingState.isInTrial) {
      return '';
    }
    if (billingState.effectivePlan == AppPlan.premium &&
        _selectedPlan == AppPlan.basic) {
      return '次の更新日から新プランが適用されます';
    }
    if (billingState.effectivePlan == AppPlan.premium) {
      return '';
    }
    if (billingState.effectivePlan == AppPlan.basic &&
        _selectedPlan == AppPlan.premium) {
      return '次の更新日から新プランが適用されます';
    }
    if (billingState.effectivePlan == AppPlan.basic) {
      return '';
    }
    switch (_selectedPlan) {
      case AppPlan.premium:
        return '体験終了後は¥500/月で自動課金されます';
      case AppPlan.basic:
        return '¥400/月が即日課金されます\n無料体験はプレミアムプランのみとなります';
      case AppPlan.free:
        return '¥400/月が即日課金されます\n無料体験はプレミアムプランのみとなります';
    }
  }

  Future<void> _purchaseSelectedPlan() async {
    if (_isPurchasing) return;
    setState(() => _isPurchasing = true);
    final success = await ref
        .read(billingControllerProvider.notifier)
        .purchasePackageByIdentifier(_selectedPackageIdentifier);
    if (!mounted) return;
    setState(() => _isPurchasing = false);
    showTopSnackBar(
      context,
      success ? '$_selectedPlanLabelの購入情報を反映しました' : '購入処理を完了できませんでした',
      saveToHistory: false,
    );
  }

  Future<void> _openManageSubscriptions() async {
    final opened = await launchUrl(
      _manageSubscriptionsUri,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      showTopSnackBar(context, 'サブスクリプション管理ページを開けませんでした');
    }
  }

  Future<void> _openFaqMore() async {
    final opened = await launchUrl(
      _faqMoreUri,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      showTopSnackBar(context, 'FAQページを開けませんでした');
    }
  }

  Future<void> _openExternalLink(Uri uri, String errorMessage) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      showTopSnackBar(context, errorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.of(context).backgroundGray,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/start/bg_auth.png',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.chevron_left),
                        color: const Color(0xFF5A6E89),
                        splashRadius: 20,
                      ),
                      const Expanded(
                        child: Text(
                          '有料プラン詳細',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2D3B4A),
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _heroCard(),
                        const SizedBox(height: 18),
                        _worriesSection(),
                        const SizedBox(height: 28),
                        _sharedSection(),
                        const SizedBox(height: 28),
                        _exclusiveSection(),
                        const SizedBox(height: 28),
                        _planSelectorSection(),
                        const SizedBox(height: 28),
                        _comparisonTableSection(),
                        const SizedBox(height: 28),
                        _coinPlanSection(),
                        const SizedBox(height: 28),
                        _faqSection(),
                        const SizedBox(height: 28),
                        _notesSection(),
                        const SizedBox(height: 28),
                        _footerLinks(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroCard() {
    return GestureDetector(
      onTap: _scrollToCoinSection,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Image.asset(
          'assets/images/premium/premium_top.png',
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _worriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'こんなお悩みがある方へ',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2D3B4A),
            height: 1.6,
          ),
        ),
        const SizedBox(height: 18),
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Image.asset(
            'assets/images/premium/premiere_though.png',
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
      ],
    );
  }

  Widget _sharedSection() {
    return _carouselSection(
      topLabel: 'ベーシック&プレミアム',
      title: 'プランを上げてより快適に',
      label: '全プラン共通',
      pageController: _sharedController,
      imagePaths: const [
        'assets/images/premium/Card_Kyotsu_01.png',
        'assets/images/premium/Card_Kyotsu_02.png',
      ],
    );
  }

  Widget _exclusiveSection() {
    return _carouselSection(
      topLabel: null,
      title: null,
      label: 'プレミアムプラン限定',
      pageController: _exclusiveController,
      imagePaths: const [
        'assets/images/premium/Card_Premium_01.png',
        'assets/images/premium/Card_Premium_02.png',
        'assets/images/premium/Card_Premium_03.png',
        'assets/images/premium/Card_Premium_04.png',
      ],
    );
  }

  Widget _carouselSection({
    required String? topLabel,
    required String? title,
    required String label,
    required PageController pageController,
    required List<String> imagePaths,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (topLabel != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/common/crown.png',
                width: 18,
                height: 18,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 6),
              Text(
                topLabel,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF50637A),
                  height: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        if (title != null) ...[
          const Text(
            'プランを上げてより快適に',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF2D3B4A),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
        ],
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.of(context).borderLow,
              width: 2,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: label == '全プラン共通'
                        ? const Color(0xFFE7FBF5)
                        : AppColors.of(context).accentPrimary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: label == '全プラン共通'
                          ? const Color(0xFF18B889)
                          : Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 440,
                child: PageView.builder(
                  controller: pageController,
                  itemCount: imagePaths.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Image.asset(
                        imagePaths[index],
                        fit: BoxFit.contain,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: SmoothPageIndicator(
                  controller: pageController,
                  count: imagePaths.length,
                  effect: const ExpandingDotsEffect(
                    dotHeight: 8,
                    dotWidth: 8,
                    expansionFactor: 2.6,
                    spacing: 8,
                    radius: 999,
                    dotColor: Color(0xFFD5DDEA),
                    activeDotColor: Color(0xFF5A6E89),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _planSelectorSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '選べる2つのプラン',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF2D3B4A),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              _planToggle(),
              const SizedBox(height: 22),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _showcasePlan == AppPlan.premium
                    ? _PlanSelectorPanel(
                        key: const ValueKey('premium-plan-panel'),
                        title: 'プレミアムプラン',
                        price: '¥500',
                        description:
                            '家族5人以内で利用可能に。\nメッセージアプリなしで\n気軽にやりとりしたい方にもおすすめ',
                        benefits: const [
                          (
                            'assets/icons/history_green.png',
                            '7日間の履歴保存 -> 1年に延長',
                          ),
                          ('assets/icons/folder_green.png', 'カテゴリ数の制限なし'),
                          ('assets/icons/trending-up_green.png', 'よく買うアイテムを表示'),
                          ('assets/icons/smile-plus_green.png', 'スタンプが送り合える'),
                          (
                            'assets/icons/message-square-share_green.png',
                            'ひとこと掲示板でコメントを共有',
                          ),
                          (
                            'assets/icons/user-round-plus_green.png',
                            '1人をチームに招待 -> 4人にアップ',
                          ),
                        ],
                        onProceed: _scrollToCoinSection,
                      )
                    : _PlanSelectorPanel(
                        key: const ValueKey('basic-plan-panel'),
                        title: 'ベーシックプラン',
                        price: '¥400',
                        description: '家族2人でカテゴリや履歴を\nもっと活用したい方におすすめ',
                        benefits: const [
                          ('assets/icons/history.png', '7日間の履歴保存 -> 2週間に延長'),
                          ('assets/icons/folder.png', 'カテゴリ上限数3個 -> 5個にアップ'),
                        ],
                        onProceed: _scrollToCoinSection,
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _planToggle() {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _planToggleChip(
              label: 'ベーシック',
              selected: _showcasePlan == AppPlan.basic,
              onTap: () => _selectShowcasePlan(AppPlan.basic),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _planToggleChip(
              label: 'プレミアム',
              selected: _showcasePlan == AppPlan.premium,
              onTap: () => _selectShowcasePlan(AppPlan.premium),
            ),
          ),
        ],
      ),
    );
  }

  Widget _planToggleChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2ECCA1) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : const Color(0xFF425269),
          ),
        ),
      ),
    );
  }

  Widget _comparisonTableSection() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Image.asset(
        'assets/images/premium/Table.png',
        width: double.infinity,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _coinPlanSection() {
    final billingState = ref.watch(billingControllerProvider);
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    final isBasic = _selectedPlan == AppPlan.basic;
    final isTrial = billingState.isInTrial;
    final isCanceling = billingState.isCanceling;
    final isCurrentPremium = billingState.effectivePlan == AppPlan.premium;
    final isCurrentBasic = billingState.effectivePlan == AppPlan.basic;
    final canShowTrialBadge =
        billingState.effectivePlan == AppPlan.free &&
        billingState.isNeverSubscribed;
    final isExpired = billingState.isExpired;
    final trialEndsAt = billingState.trialEndsAt;
    final trialInfo = trialEndsAt == null
        ? '無料体験は2週間で終了します。途中で解約をしない場合、体験終了後に課金が開始されます。'
        : '無料体験は${trialEndsAt.year}年${trialEndsAt.month}月${trialEndsAt.day}日に終了します。途中で解約をしない場合、体験終了後に課金が開始されます。';
    final cancellationInfo =
        billingState.cancellationStatusLabel ?? 'サブスクリプションは次回更新時に解約されます';
    final shouldDisablePrimaryCta =
        (isCurrentPremium && _selectedPlan == AppPlan.premium) ||
        (isCurrentBasic && _selectedPlan == AppPlan.basic);
    return KeyedSubtree(
      key: _coinSectionKey,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Image.asset(
              'assets/images/premium/img_500coin.png',
              width: 96,
              height: 96,
            ),
            const SizedBox(height: 20),
            const Text(
              'ワンコインでプランを上げる',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF2D3B4A),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'いつでもキャンセル可／オーナー1人の登録でOK',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF7B8AA1),
                height: 1.5,
              ),
            ),
            if (isTrial || isCanceling) ...[
              const SizedBox(height: 18),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.info_outline,
                        size: 18,
                        color: Color(0xFF687A95),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isTrial ? 'プレミアムプランを無料体験中' : '解約手続き中',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2D3B4A),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isTrial ? trialInfo : cancellationInfo,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF5F728A),
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 22),
            _coinPlanOptionCard(
              title: 'ベーシック',
              subtitle: '履歴保存・カテゴリ数アップ',
              priceLabel: '¥400',
              selected: isBasic,
              recommended: false,
              isCurrentPlan: isCurrentBasic,
              onTap: () => _selectPlan(AppPlan.basic),
            ),
            const SizedBox(height: 16),
            _coinPlanOptionCard(
              title: 'プレミアム',
              subtitle: '5人利用・スタンプ・掲示板も',
              priceLabel: '¥500',
              selected: !isBasic,
              recommended: canShowTrialBadge,
              isCurrentPlan: isCurrentPremium,
              onTap: () => _selectPlan(AppPlan.premium),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 54,
              child: FilledButton(
                onPressed: (_isPurchasing || shouldDisablePrimaryCta)
                    ? null
                    : _purchaseSelectedPlan,
                style: FilledButton.styleFrom(
                  backgroundColor: shouldDisablePrimaryCta
                      ? colors.surfaceDisabled
                      : ((isTrial || isCurrentPremium || isCurrentBasic)
                            ? const Color(0xFF2E3A48)
                            : const Color(0xFF2ECCA1)),
                  disabledBackgroundColor: colors.surfaceDisabled,
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: _isPurchasing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _selectedCtaLabel,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: Text(
                _selectedCtaNote,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF667B95),
                  height: 1.5,
                ),
              ),
            ),
            if ((isTrial || isCurrentPremium || isCurrentBasic) &&
                !isExpired) ...[
              const SizedBox(height: 14),
              TextButton(
                onPressed: _openManageSubscriptions,
                child: Text(
                  'サブスクリプションを管理する',
                  style: typography.std14B160.copyWith(
                    color: colors.textMedium,
                    decoration: TextDecoration.underline,
                    decorationColor: colors.textMedium,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _coinPlanOptionCard({
    required String title,
    required String subtitle,
    required String priceLabel,
    required bool selected,
    required bool recommended,
    required bool isCurrentPlan,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFE9FBF6) : Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: selected ? const Color(0xFF2ECCA1) : Colors.transparent,
                width: 2,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
            child: Row(
              children: [
                AppRadioCircle(selected: selected),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2D3B4A),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF6A7D95),
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                RichText(
                  text: TextSpan(
                    text: priceLabel,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2D3B4A),
                      height: 1.6,
                    ),
                    children: const [
                      TextSpan(
                        text: '/月',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF5D718A),
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isCurrentPlan)
            Positioned(
              top: -12,
              left: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF2ECCA1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  '利用中',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          else if (recommended)
            Positioned(
              top: -12,
              left: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF2ECCA1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  '無料体験あり',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _faqSection() {
    const items = [
      (
        '解約はいつでもできますか？',
        'はい、Appleの設定からすぐにご解約可能です。ご契約後は、このページ内の「プランを変更する」ボタンの下にある「サブスクリプションを管理する」よりお手続きいただけます。更新日を過ぎた後、自動的に無料プランに切り替わります。',
      ),
      ('家族も課金が必要ですか？', '必要ありません。オーナー1名の課金でチーム全員が利用できます。'),
      ('機種変更したらどうなる？', 'アカウント連携をしていれば、同じアカウントでログインするとデータが引き継がれます。'),
    ];
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'よくある質問',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF2D3B4A),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),
        for (var i = 0; i < items.length; i++) ...[
          _faqItem(
            question: items[i].$1,
            answer: items[i].$2,
            expanded: _expandedFaqIndexes.contains(i),
            onTap: () {
              setState(() {
                if (_expandedFaqIndexes.contains(i)) {
                  _expandedFaqIndexes.remove(i);
                } else {
                  _expandedFaqIndexes.add(i);
                }
              });
            },
          ),
          if (i != items.length - 1) const SizedBox(height: 16),
        ],
        const SizedBox(height: 28),
        OutlinedButton(
          onPressed: _openFaqMore,
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: colors.textHigh,
            minimumSize: const Size.fromHeight(60),
            side: BorderSide(color: colors.borderMedium),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            elevation: 0,
            shadowColor: Colors.transparent,
          ),
          child: Text(
            'FAQをもっと見る',
            style: typography.std14B160.copyWith(color: colors.textHigh),
          ),
        ),
      ],
    );
  }

  Widget _faqItem({
    required String question,
    required String answer,
    required bool expanded,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        question,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2D3B4A),
                          height: 1.6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: Image.asset(
                        'assets/icons/chevron-down.png',
                        width: 20,
                        height: 20,
                        color: const Color(0xFF5C708A),
                      ),
                    ),
                  ],
                ),
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(height: 1, color: const Color(0xFFE4EBF3)),
                        const SizedBox(height: 18),
                        Text(
                          answer,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF16AA80),
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  crossFadeState: expanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 180),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _notesSection() {
    const notes = [
      'オーナー1名の課金で、チーム内の全メンバーがご利用いただけます。',
      '2週間無料体験はおひとり様1回限りとなります。',
      '2週間無料体験期間終了の24時間前までに解約されない場合、自動的に有料プランへ移行し料金が発生します。',
      'ご利用中のプランは、購読期間終了の24時間前までであれば解約(自動継続購入の停止)が可能です。',
      '定期購入のお支払いは AppleID に請求されます。',
      'アプリを削除しただけでは解約されません。解約は App Store の設定から行ってください。',
      '異なるアカウントでの重複課金に対する返金はいたしかねますのでご了承ください。',
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.of(context).surfaceSecondary,
        borderRadius: BorderRadius.circular(36),
      ),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '注意事項',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2D3B4A),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 22),
          for (var i = 0; i < notes.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Text(
                    '•',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF587091),
                      height: 1.6,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    notes[i],
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF587091),
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
            if (i != notes.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _footerLinks() {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _footerLinkButton(label: 'プライバシーポリシー'),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              '|',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w300,
                color: Color(0xFFC8D2DF),
                height: 1,
              ),
            ),
          ),
          _footerLinkButton(label: '利用規約'),
        ],
      ),
    );
  }

  Widget _footerLinkButton({required String label}) {
    return TextButton(
      onPressed: () {
        if (label == 'プライバシーポリシー') {
          _openExternalLink(_privacyPolicyUri, 'プライバシーポリシーを開けませんでした');
          return;
        }
        _openExternalLink(_termsOfServiceUri, '利用規約を開けませんでした');
      },
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF6E86A4),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Color(0xFF6E86A4),
          height: 1.6,
        ),
      ),
    );
  }
}

class _PlanSelectorPanel extends StatelessWidget {
  const _PlanSelectorPanel({
    super.key,
    required this.title,
    required this.price,
    required this.description,
    required this.benefits,
    required this.onProceed,
  });

  final String title;
  final String price;
  final String description;
  final List<(String, String)> benefits;
  final VoidCallback onProceed;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2D3B4A),
            height: 1.6,
          ),
        ),
        Text(
          price,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 44,
            fontWeight: FontWeight.w800,
            color: Color(0xFF2D3B4A),
            height: 1.15,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          description,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF5F7287),
            height: 1.6,
          ),
        ),
        const SizedBox(height: 18),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              for (final benefit in benefits)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Image.asset(benefit.$1, width: 18, height: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          benefit.$2,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF587091),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 54,
          child: FilledButton(
            onPressed: onProceed,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2ECCA1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'プラン選択へ進む',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}
