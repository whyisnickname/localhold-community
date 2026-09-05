// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:localhold_app_foundation/localhold_app_foundation.dart';
import 'package:localhold_vault_core/localhold_vault_core.dart';

typedef TotpQrReader = Future<String?> Function();

final class TotpIntakeDialog extends StatefulWidget {
  const TotpIntakeDialog({
    required this.onAdd,
    this.readCameraQr,
    this.readImageQr,
    this.parser = const TotpIntakeParser(),
    super.key,
  });

  final ValueChanged<Map<String, Object?>> onAdd;
  final TotpQrReader? readCameraQr;
  final TotpQrReader? readImageQr;
  final TotpIntakeParser parser;

  @override
  State<TotpIntakeDialog> createState() => _TotpIntakeDialogState();
}

final class _TotpIntakeDialogState extends State<TotpIntakeDialog> {
  final _value = TextEditingController();
  final _issuer = TextEditingController();
  final _account = TextEditingController();
  TotpImportPreview? _preview;
  bool _invalid = false;
  bool _revealed = false;

  @override
  void dispose() {
    _preview?.dispose();
    _value.clear();
    _issuer.clear();
    _account.clear();
    _value.dispose();
    _issuer.dispose();
    _account.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = LocalholdLocalizations.of(context);
    return AlertDialog(
      title: Text(strings.totpImportTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('totp_value'),
              controller: _value,
              autocorrect: false,
              enableSuggestions: false,
              obscureText: !_revealed,
              decoration: InputDecoration(
                labelText: strings.totpUriOrSecret,
                errorText: _invalid ? strings.totpInvalid : null,
                suffixIcon: IconButton(
                  tooltip: _revealed
                      ? strings.recordViewHide
                      : strings.recordViewReveal,
                  onPressed: () => setState(() => _revealed = !_revealed),
                  icon: Icon(
                    _revealed
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ),
            ),
            TextField(
              controller: _issuer,
              decoration: InputDecoration(labelText: strings.totpIssuer),
            ),
            TextField(
              controller: _account,
              decoration: InputDecoration(labelText: strings.totpAccount),
            ),
            if (widget.readCameraQr != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.qr_code_scanner),
                title: Text(strings.totpScanQr),
                onTap: () => _readQr(widget.readCameraQr!),
              ),
            if (widget.readImageQr != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.image_search_outlined),
                title: Text(strings.totpImportQrImage),
                onTap: () => _readQr(widget.readImageQr!),
              ),
            if (_preview case final preview?) ...[
              const SizedBox(height: LocalholdSpacing.md),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  strings.totpReview,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              _PreviewRow(strings.totpIssuer, preview.issuer),
              _PreviewRow(strings.totpAccount, preview.account),
              _PreviewRow(
                strings.totpAlgorithm,
                preview.algorithm.name.toUpperCase(),
              ),
              _PreviewRow(strings.totpDigits, '${preview.digits}'),
              _PreviewRow(strings.totpPeriod, '${preview.periodSeconds} s'),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(strings.commonCancel),
        ),
        if (_preview == null)
          FilledButton(onPressed: _review, child: Text(strings.actionReview))
        else
          FilledButton(
            onPressed: () {
              final value = _preview!.toVaultValue();
              widget.onAdd(value);
              Navigator.pop(context);
            },
            child: Text(strings.totpAdd),
          ),
      ],
    );
  }

  Future<void> _readQr(TotpQrReader reader) async {
    final value = await reader();
    if (!mounted || value == null) return;
    _value.text = value;
    _review(forceUri: true);
  }

  void _review({bool forceUri = false}) {
    _preview?.dispose();
    _preview = null;
    try {
      final raw = _value.text.trim();
      final parsed = forceUri || raw.toLowerCase().startsWith('otpauth:')
          ? widget.parser.parseUri(raw)
          : widget.parser.parseManual(
              secret: raw,
              issuer: _issuer.text,
              account: _account.text,
            );
      _issuer.text = parsed.issuer;
      _account.text = parsed.account;
      _value.clear();
      setState(() {
        _preview = parsed;
        _invalid = false;
      });
    } on VaultFailure {
      setState(() => _invalid = true);
    }
  }
}

final class _PreviewRow extends StatelessWidget {
  const _PreviewRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: LocalholdSpacing.xs),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label)),
        Expanded(child: Text(value, textAlign: TextAlign.end)),
      ],
    ),
  );
}
