import 'package:clarity_flutter/clarity_flutter.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/app_theme.dart';
import 'relay/gate_caller.dart';
import 'relay/insight.dart';
import 'relay/masked_client.dart';
import 'relay/notify_pipe.dart';
import 'relay/peg_vault.dart';
import 'relay/signal_gauge.dart';
import 'relay/source_tracker.dart';
import 'shell/boot_pilot.dart';

// -----------------------------------------------------------------
// Bootstrap wiring order (do not shuffle):
//   1. Bindings — required before any plugin call.
//   2. Firebase + AppCheck — wrapped in try/catch so the app still
//      builds while google-services.json is not yet present.
//   3. Orientation whitelist + status bar tint.
//   4. MaskedClient.reassemble() — the WebView will read its UA.
//   5. PegVault.hydrate() — makes the first BootPilot frame able to
//      decide the route synchronously (no blank splash).
//   6. Relays are constructed but not "armed" here; NotifyPipe and
//      SourceTracker start inside BootPilot after UI is up.
// -----------------------------------------------------------------

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
    );
  } catch (_) {
    // Continue without Firebase — the shell degrades to the game path.
  }

  await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  await maskedWire.reassemble();

  final PegVault vault = PegVault();
  await vault.hydrate();

  final SignalGauge gauge = SignalGauge();
  final SourceTracker tracker = SourceTracker();
  final GateCaller gate = GateCaller(vault);
  final NotifyPipe pipe = NotifyPipe(vault);

  runApp(ClarityWidget(
    clarityConfig: Insight.config,
    app: PegboardBounceApp(
      vault: vault,
      gauge: gauge,
      tracker: tracker,
      gate: gate,
      pipe: pipe,
    ),
  ));
}

class PegboardBounceApp extends StatelessWidget {
  const PegboardBounceApp({
    super.key,
    required this.vault,
    required this.gauge,
    required this.tracker,
    required this.gate,
    required this.pipe,
  });

  final PegVault vault;
  final SignalGauge gauge;
  final SourceTracker tracker;
  final GateCaller gate;
  final NotifyPipe pipe;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pegboard Bounce',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.deepPurple,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.panelPurple,
          brightness: Brightness.dark,
        ),
        fontFamily: 'sans-serif',
      ),
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(highContrast: false),
          child: child!,
        );
      },
      home: BootPilot(
        vault: vault,
        gauge: gauge,
        tracker: tracker,
        gate: gate,
        pipe: pipe,
      ),
    );
  }
}
