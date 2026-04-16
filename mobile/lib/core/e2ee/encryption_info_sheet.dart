import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'crypto_service.dart';
import '../../l10n/app_localizations.dart';

/// Bottom sheet showing E2EE encryption status and safety number for verification.
class EncryptionInfoSheet extends StatefulWidget {
  final String localUserId;
  final String remoteUserId;
  final String remoteName;

  const EncryptionInfoSheet({
    super.key,
    required this.localUserId,
    required this.remoteUserId,
    required this.remoteName,
  });

  @override
  State<EncryptionInfoSheet> createState() => _EncryptionInfoSheetState();
}

class _EncryptionInfoSheetState extends State<EncryptionInfoSheet> {
  String? _safetyNumber;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSafetyNumber();
  }

  Future<void> _loadSafetyNumber() async {
    final sn = await E2eeCryptoService().getSafetyNumber(
      widget.localUserId,
      widget.remoteUserId,
    );
    if (mounted) {
      setState(() {
        _safetyNumber = sn;
        _loading = false;
      });
    }
  }

  String _formatSafetyNumber(String sn) {
    final buffer = StringBuffer();
    for (int i = 0; i < sn.length; i++) {
      buffer.write(sn[i]);
      if ((i + 1) % 5 == 0 && i + 1 < sn.length) buffer.write(' ');
      if ((i + 1) % 20 == 0 && i + 1 < sn.length) buffer.write('\n');
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock, size: 48, color: Colors.greenAccent.shade400),
            const SizedBox(height: 16),
            Text(
              l.e2eeTitle,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              l.e2eeDescription(widget.remoteName),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 24),
            if (_loading)
              const CircularProgressIndicator()
            else if (_safetyNumber != null) ...[
              Text(
                l.securityCode,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _formatSafetyNumber(_safetyNumber!),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 16,
                    letterSpacing: 2,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l.securityCodeHint(widget.remoteName),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _safetyNumber!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l.codeCopied), duration: const Duration(seconds: 1)),
                  );
                },
                icon: const Icon(Icons.copy, size: 18),
                label: Text(l.copyCode),
              ),
            ] else
              Text(
                l.securityCodeUnavailable,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
