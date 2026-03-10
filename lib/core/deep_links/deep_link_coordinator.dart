import 'dart:async';
import 'dart:developer' as dev;
import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../router/app_router.dart';

class DeepLinkCoordinator {
  final GoRouter _router;
  final AppLinks _appLinks;
  StreamSubscription<Uri>? _subscription;

  DeepLinkCoordinator(this._router, this._appLinks);

  Future<void> start() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleUri(initialUri);
      }
    } catch (e, stack) {
      dev.log(
        'Error reading initial deep link',
        error: e,
        stackTrace: stack,
        name: 'DeepLinkCoordinator',
      );
    }

    _subscription = _appLinks.uriLinkStream.listen(
      _handleUri,
      onError: (error, stackTrace) {
        dev.log(
          'Error in deep link stream',
          error: error,
          stackTrace: stackTrace,
          name: 'DeepLinkCoordinator',
        );
      },
    );
  }

  void _handleUri(Uri uri) {
    final normalizedPath = _normalizePath(uri);
    if (normalizedPath == null) return;

    dev.log('Deep link received: $uri -> $normalizedPath',
        name: 'DeepLinkCoordinator');
    _router.go(normalizedPath);
  }

  String? _normalizePath(Uri uri) {
    if (uri.pathSegments.isNotEmpty) {
      final joined = '/${uri.pathSegments.join('/')}';
      if (joined.startsWith('/ticket/') || joined.startsWith('/event/')) {
        return joined;
      }
    }

    if (uri.host.isNotEmpty) {
      if (uri.host == 'ticket' && uri.pathSegments.isNotEmpty) {
        return '/ticket/${uri.pathSegments.first}';
      }
      if (uri.host == 'event' && uri.pathSegments.isNotEmpty) {
        return '/event/${uri.pathSegments.first}';
      }
    }

    return null;
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}

final deepLinkCoordinatorProvider = Provider<DeepLinkCoordinator>((ref) {
  final coordinator = DeepLinkCoordinator(ref.read(routerProvider), AppLinks());
  unawaited(coordinator.start());
  ref.onDispose(() {
    unawaited(coordinator.dispose());
  });
  return coordinator;
});
