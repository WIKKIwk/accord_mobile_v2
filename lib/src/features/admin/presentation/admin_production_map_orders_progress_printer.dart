part of 'admin_production_map_orders_screen.dart';

class _ProgressPrinterOption {
  const _ProgressPrinterOption({
    required this.server,
    required this.driverUrl,
    required this.printerLabel,
  });

  final DiscoveredServer server;
  final String driverUrl;
  final String printerLabel;
}

Future<_ProgressPrinterOption?> _showProgressPrinterPicker(
  BuildContext context,
) {
  return showModalBottomSheet<_ProgressPrinterOption>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => const _ProgressPrinterPickerSheet(),
  );
}

Future<String?> _pickProgressDriverUrl(
  BuildContext context,
  Future<String?> Function(BuildContext context)? progressDriverUrlPicker,
) async {
  if (progressDriverUrlPicker != null) {
    return progressDriverUrlPicker(context);
  }
  return (await _showProgressPrinterPicker(context))?.driverUrl;
}

class _ProgressPrinterPickerSheet extends StatefulWidget {
  const _ProgressPrinterPickerSheet();

  @override
  State<_ProgressPrinterPickerSheet> createState() =>
      _ProgressPrinterPickerSheetState();
}

class _ProgressPrinterPickerSheetState
    extends State<_ProgressPrinterPickerSheet> {
  final http.Client _client = http.Client();
  List<_ProgressPrinterOption> _options = const [];
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    unawaited(_loadPrinters());
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  Future<void> _loadPrinters() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final preferredEndpoint = await loadLastUsedServer();
      final fast = await discoverServersFast(
        _client,
        preferredEndpoint: preferredEndpoint,
      );
      var options = await _connectedProgressPrinters(_client, fast.servers);
      if (options.isEmpty) {
        final full = await discoverServers(
          _client,
          preferredEndpoint: preferredEndpoint,
        );
        options = await _connectedProgressPrinters(_client, [
          ...fast.servers,
          ...full.servers,
        ]);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _options = options;
        _loading = false;
        _error = options.isEmpty ? 'Printer ulangan RPS topilmadi' : '';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _options = const [];
        _loading = false;
        _error = 'Printer ulangan RPS topilmadi';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return FractionallySizedBox(
      heightFactor: 0.62,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Printerni tanlang',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed:
                        _loading ? null : () => unawaited(_loadPrinters()),
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: 'Yangilash',
                  ),
                ],
              ),
              if (_loading) ...[
                const SizedBox(height: 8),
                const LinearProgressIndicator(),
              ],
              if (!_loading && _error.isNotEmpty) ...[
                const SizedBox(height: 12),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      _error,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onErrorContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: _options.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final option = _options[index];
                    return ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      tileColor: scheme.surfaceContainerHighest,
                      leading: const Icon(Icons.print_rounded),
                      title: Text(
                        printTargetLabel(option.server),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${option.printerLabel} • ${option.driverUrl}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).pop(option),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<List<_ProgressPrinterOption>> _connectedProgressPrinters(
  http.Client client,
  List<DiscoveredServer> servers,
) async {
  final seen = <String>{};
  final uniqueServers = <DiscoveredServer>[];
  for (final server in servers) {
    if (seen.add(server.endpoint.baseUrl)) {
      uniqueServers.add(server);
    }
  }
  final options = await Future.wait(
    uniqueServers.map((server) => _connectedProgressPrinter(client, server)),
  );
  return [
    for (final option in options)
      if (option != null) option,
  ];
}

Future<_ProgressPrinterOption?> _connectedProgressPrinter(
  http.Client client,
  DiscoveredServer server,
) async {
  try {
    final response = await client
        .get(Uri.parse('${server.endpoint.baseUrl}/v1/mobile/monitor/state'))
        .timeout(const Duration(seconds: 2));
    if (response.statusCode < 200 || response.statusCode > 299) {
      return null;
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final printerRaw = (payload['printer'] as Map?)?.cast<String, dynamic>() ??
        ((payload['state'] as Map?)?['printer'] as Map?)
            ?.cast<String, dynamic>();
    if (printerRaw == null) {
      return null;
    }
    final connected =
        _jsonBool(printerRaw['connected']) || _jsonBool(printerRaw['ok']);
    if (!connected) {
      return null;
    }
    final kind = _jsonText(printerRaw['kind'], fallback: 'printer');
    return _ProgressPrinterOption(
      server: server,
      driverUrl: driverUrlForRs(server).replaceFirst(RegExp(r'/+$'), ''),
      printerLabel: _jsonText(printerRaw['label'], fallback: kind),
    );
  } catch (_) {
    return null;
  }
}

bool _jsonBool(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }
  return false;
}

String _jsonText(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}
