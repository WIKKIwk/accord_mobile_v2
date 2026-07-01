import 'dart:async';

import '../../../app/app_router.dart';
import '../../../core/native_iroh_transport.dart';
import 'package:flutter/material.dart';
import 'widgets/admin_shell.dart';

class AdminIrohTransportTestScreen extends StatefulWidget {
  const AdminIrohTransportTestScreen({super.key});

  @override
  State<AdminIrohTransportTestScreen> createState() =>
      _AdminIrohTransportTestScreenState();
}

class _AdminIrohTransportTestScreenState
    extends State<AdminIrohTransportTestScreen> {
  final _ticketController = TextEditingController(
    text: NativeIrohTransport.endpointTicketFromEnvironment,
  );
  bool _checking = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    if (_ticketController.text.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_runHealthCheck());
        }
      });
    }
  }

  @override
  void dispose() {
    _ticketController.dispose();
    super.dispose();
  }

  Future<void> _runHealthCheck() async {
    if (_checking) {
      return;
    }
    final ticket = _ticketController.text.trim();
    if (ticket.isEmpty) {
      setState(() => _status = 'Ticket kiriting');
      return;
    }
    setState(() {
      _checking = true;
      _status = 'Iroh orqali tekshirilmoqda...';
    });
    try {
      final result = await NativeIrohTransport.healthCheck(
        ticket: ticket,
        runs: 3,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _checking = false;
        _status = 'OK: status ${result.statusCode}, ${result.runs} ta so‘rov, '
            '${result.bytes} byte, ${result.totalMs.toStringAsFixed(1)} ms'
            '${result.pathInfo.isEmpty ? '' : '\n${result.pathInfo}'}';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _checking = false;
        _status = irohTransportErrorText(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AdminShell(
      title: 'Iroh transport test',
      selectedRouteName: AppRoutes.adminIrohTransportTest,
      activeTab: null,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          14,
          16,
          MediaQuery.viewPaddingOf(context).bottom + 128,
        ),
        children: [
          TextField(
            controller: _ticketController,
            minLines: 3,
            maxLines: 7,
            decoration: const InputDecoration(
              labelText: 'IROH_ENDPOINT_TICKET',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _checking ? null : () => unawaited(_runHealthCheck()),
              icon: _checking
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.hub_rounded),
              label: const Text('Health check'),
            ),
          ),
          if (_status.isNotEmpty) ...[
            const SizedBox(height: 14),
            DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_status),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
