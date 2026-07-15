import 'package:flutter/material.dart';

import '../core/app_assets.dart';
import '../core/app_theme.dart';
import '../keys/peg_config.dart';
import '../relay/insight.dart';
import '../relay/notify_pipe.dart';
import '../relay/peg_vault.dart';
import '../relay/signal_gauge.dart';
import 'bounce_button.dart';
import 'hosted_view.dart';

/// Push opt-in promo shown once before the hosted WebView.
///
/// The background artwork is orientation-aware; Accept and Skip are
/// laid out as two symmetric buttons — horizontally centred without
/// a [SafeArea], per the current TZ (safe-area padding on a
/// side-notched landscape device would push both buttons off-centre).
class NotifyPromptView extends StatefulWidget {
  const NotifyPromptView({
    super.key,
    required this.vault,
    required this.pipe,
    required this.gauge,
    required this.contentUrl,
  });

  final PegVault vault;
  final NotifyPipe pipe;
  final SignalGauge gauge;
  final String contentUrl;

  @override
  State<NotifyPromptView> createState() => _NotifyPromptViewState();
}

class _NotifyPromptViewState extends State<NotifyPromptView> {
  @override
  void initState() {
    super.initState();
    Insight.screen('push_invite');
  }

  int _cooldownAt() =>
      DateTime.now().millisecondsSinceEpoch ~/ 1000 +
      PegConfig.notifyPromptCooldown;

  Future<void> _accept(BuildContext context) async {
    Insight.event('push_invite_accept');
    final bool granted = await widget.pipe.requestPermission();
    Insight.tag('notif_permission', granted ? 'granted' : 'denied');
    Insight.event(granted ? 'push_granted' : 'push_denied');
    if (!granted) {
      await widget.vault.gateNotifyPrompt(_cooldownAt());
    }
    if (context.mounted) _forward(context);
  }

  Future<void> _skip(BuildContext context) async {
    Insight.event('push_invite_skip');
    Insight.tag('notif_permission', 'skipped');
    await widget.vault.gateNotifyPrompt(_cooldownAt());
    if (context.mounted) _forward(context);
  }

  void _forward(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => HostedView(
          initialUrl: widget.contentUrl,
          vault: widget.vault,
          pipe: widget.pipe,
          gauge: widget.gauge,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final bool landscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final String bg = landscape
        ? AppAssets.horizontalNotifications
        : AppAssets.verticalNotifications;

    final double acceptWidth = landscape
        ? size.width * 0.28
        : (size.width * 0.60).clamp(220.0, 360.0);
    final double skipWidth = landscape
        ? size.width * 0.24
        : (size.width * 0.52).clamp(200.0, 320.0);
    final double bottomInset =
        landscape ? size.height * 0.07 : size.height * 0.08;

    return Scaffold(
      backgroundColor: AppColors.deepPurple,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(bg,
              fit: BoxFit.cover, width: size.width, height: size.height),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: <Color>[Colors.transparent, Color(0x8F0D0521)],
              ),
            ),
          ),
          // No SafeArea here — buttons remain horizontally centred on
          // side-notched landscape devices.
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomInset,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  BounceButton(
                    label: 'Accept',
                    width: acceptWidth,
                    compact: landscape,
                    variant: BounceVariant.primary,
                    onTap: () => _accept(context),
                  ),
                  SizedBox(height: landscape ? 10 : 14),
                  BounceButton(
                    label: 'Skip',
                    width: skipWidth,
                    compact: landscape,
                    variant: BounceVariant.ghost,
                    onTap: () => _skip(context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

