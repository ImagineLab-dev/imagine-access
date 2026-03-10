import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:imagine_access/l10n/app_localizations.dart';

class TicketDeepLinkScreen extends ConsumerStatefulWidget {
  final String ticketId;
  const TicketDeepLinkScreen({super.key, required this.ticketId});

  @override
  ConsumerState<TicketDeepLinkScreen> createState() =>
      _TicketDeepLinkScreenState();
}

class _TicketDeepLinkScreenState extends ConsumerState<TicketDeepLinkScreen> {
  @override
  void initState() {
    super.initState();
    _resolveTicket();
  }

  Future<void> _resolveTicket() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final client = Supabase.instance.client;
      await client
          .from('tickets')
          .select('id')
          .eq('id', widget.ticketId)
          .maybeSingle();

      if (!mounted) return;
      context.go('/tickets');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.ticketLoadedFromDeepLink)),
      );
    } catch (_) {
      if (!mounted) return;
      context.go('/tickets');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.couldNotOpenSharedTicket)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
