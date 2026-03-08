import 'dart:developer' as dev;
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppProviderObserver extends ProviderObserver {
  @override
  void didUpdateProvider(
    ProviderBase<Object?> provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    dev.log(
      'Provider updated: ${provider.name ?? provider.runtimeType}',
      name: 'ProviderObserver',
    );
  }

  @override
  void providerDidFail(
    ProviderBase<Object?> provider,
    Object error,
    StackTrace stackTrace,
    ProviderContainer container,
  ) {
    dev.log(
      'Provider failed: ${provider.name ?? provider.runtimeType}',
      error: error,
      stackTrace: stackTrace,
      name: 'ProviderObserver',
    );
  }
}
