import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:imagine_access/l10n/app_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/config/env.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/i18n/locale_provider.dart';
import 'core/ui/loading_overlay.dart';
import 'core/ui/offline_sync_banner.dart';
import 'core/utils/error_handler.dart';
import 'core/observability/app_provider_observer.dart';
import 'core/deep_links/deep_link_coordinator.dart';

Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (FlutterErrorDetails details) {
      ErrorHandler.logError(
        'Flutter framework error',
        details.exception,
        stackTrace: details.stack,
        source: 'FlutterError',
      );
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      ErrorHandler.logError(
        'Uncaught platform error',
        error,
        stackTrace: stack,
        source: 'PlatformDispatcher',
      );
      return true;
    };

    await dotenv.load(fileName: ".env");

    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    );

    runApp(
      ProviderScope(
        observers: [AppProviderObserver()],
        child: const ImagineAccessApp(),
      ),
    );
  }, (error, stack) {
    ErrorHandler.logError(
      'Uncaught zone error',
      error,
      stackTrace: stack,
      source: 'runZonedGuarded',
    );
  });
}

class ImagineAccessApp extends ConsumerWidget {
  const ImagineAccessApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(deepLinkCoordinatorProvider);
    final themeMode = ref.watch(themeNotifierProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'Imagine Access',
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: themeMode,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'), // English
        Locale('es'), // Spanish
        Locale('pt'), // Portuguese
      ],
      routerConfig: ref.watch(routerProvider),
      debugShowCheckedModeBanner: false,
      builder: (context, child) => LoadingOverlay(
        child: Stack(
          children: [
            child!,
            const Align(
              alignment: Alignment.topCenter,
              child: OfflineSyncBanner(),
            ),
          ],
        ),
      ),
    );
  }
}
