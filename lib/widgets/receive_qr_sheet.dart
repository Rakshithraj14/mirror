import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../models/profile.dart';
import '../services/upi.dart';
import '../theme.dart';
import 'category_reason_form.dart';

/// Ask someone to pay you: the amount first, then a QR any UPI app can scan.
///
/// Nothing is recorded here. The money arriving is a real credit, and the SMS
/// or payment-app capture books it the same way as any other.
class ReceiveQrSheet extends StatefulWidget {
  final Profile profile;
  final VoidCallback onCancel;

  const ReceiveQrSheet({
    super.key,
    required this.profile,
    required this.onCancel,
  });

  @override
  State<ReceiveQrSheet> createState() => _ReceiveQrSheetState();
}

class _ReceiveQrSheetState extends State<ReceiveQrSheet> {
  final _amount = TextEditingController();
  final _reason = TextEditingController();
  final _ticketKey = GlobalKey();
  String? _error;

  /// Null while the form is showing; the QR stage once set.
  ({String uri, double amount, String reason})? _request;
  bool _sharing = false;

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  void _generate() {
    final amount = double.tryParse(_amount.text.trim().replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter an amount');
      return;
    }
    FocusScope.of(context).unfocus();
    final reason = _reason.text.trim();
    setState(
      () => _request = (
        uri: upiPayUri(
          upiId: widget.profile.upi!,
          name: widget.profile.display,
          amount: amount,
          note: reason,
        ),
        amount: amount,
        reason: reason,
      ),
    );
  }

  /// Shares the white ticket exactly as drawn, so the payer gets the amount
  /// and name alongside the code rather than a bare square.
  Future<void> _share() async {
    final request = _request;
    if (request == null || _sharing) return;
    setState(() {
      _sharing = true;
      _error = null;
    });
    try {
      final boundary =
          _ticketKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      // Bytes, not a temp file: dart:io does not exist in a browser, and
      // share_plus writes its own temp file on Android. On web it opens the
      // system share sheet, or downloads the PNG where there is none.
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(bytes!.buffer.asUint8List(), mimeType: 'image/png'),
          ],
          fileNameOverrides: const ['yumeko-pay-qr.png'],
          text:
              'Pay ₹${_money(request.amount)} to ${widget.profile.display} '
              '(${widget.profile.upi})',
        ),
      );
    } catch (e) {
      // Shown in the sheet: a snackbar lands on the screen behind it, which
      // is how a failed share used to look like a button that did nothing.
      if (mounted) setState(() => _error = 'Could not share: $e');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final request = _request;

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: p.line),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 28,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    request == null ? 'RECEIVE' : 'SCAN TO PAY',
                    style: uiText(
                      size: 11,
                      spacing: 2.2,
                      weight: FontWeight.w600,
                      color: p.accentInk,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: widget.onCancel,
                    child: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: p.inkFaint,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: request == null ? _form(p) : _qr(p, request),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _form(Palette p) => Column(
    key: const ValueKey('form'),
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text('₹', style: heroAmount(38, color: p.inkFaint)),
          const SizedBox(width: 4),
          Expanded(
            child: TextField(
              controller: _amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: heroAmount(44, color: p.ink),
              cursorColor: p.accentInk,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: heroAmount(44, color: p.inkFaint),
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      Container(
        decoration: BoxDecoration(
          color: p.ground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: p.line),
        ),
        child: Column(
          children: [
            _Field(
              icon: Icons.person_rounded,
              label: 'Name',
              value: widget.profile.display,
            ),
            Divider(height: 1, color: p.line),
            _Field(
              icon: Icons.alternate_email_rounded,
              label: 'UPI ID',
              value: widget.profile.upi!,
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      ReasonField(
        controller: _reason,
        hint: 'Reason (optional)',
        onSubmitted: (_) => _generate(),
      ),
      if (_error != null) ...[
        const SizedBox(height: 8),
        Text(
          _error!,
          style: uiText(size: 12, color: Theme.of(context).colorScheme.error),
        ),
      ],
      const SizedBox(height: 14),
      AccentButton(label: 'Generate QR', onPressed: _generate),
    ],
  );

  Widget _qr(
    Palette p,
    ({String uri, double amount, String reason}) r,
  ) => Column(
    key: const ValueKey('qr'),
    mainAxisSize: MainAxisSize.min,
    children: [
      RepaintBoundary(
        key: _ticketKey,
        child: _Ticket(
          uri: r.uri,
          amount: r.amount,
          reason: r.reason,
          name: widget.profile.display,
          upi: widget.profile.upi!,
          // The palette's deepest ramp step: on-brand, and dark enough on
          // white for every scanner to find the corners.
          eyeColor: p.ramp.last,
        ),
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => setState(() {
                  _request = null;
                  _error = null;
                }),
                icon: Icon(Icons.edit_rounded, size: 16, color: p.inkMuted),
                label: Text('Edit', style: uiText(size: 14, color: p.inkMuted)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: p.line),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AccentButton(
              label: _sharing ? 'Sharing…' : 'Share',
              onPressed: _share,
            ),
          ),
        ],
      ),
      if (_error != null) ...[
        const SizedBox(height: 10),
        Text(
          _error!,
          style: uiText(size: 12, color: Theme.of(context).colorScheme.error),
        ),
      ],
    ],
  );
}

/// White in both themes on purpose: scanners want dark modules on a light
/// ground, and the shared image should look the same whoever opens it.
class _Ticket extends StatelessWidget {
  final String uri;
  final double amount;
  final String reason;
  final String name;
  final String upi;
  final Color eyeColor;

  const _Ticket({
    required this.uri,
    required this.amount,
    required this.reason,
    required this.name,
    required this.upi,
    required this.eyeColor,
  });

  static const _ink = Color(0xFF101110);
  static const _muted = Color(0xFF63665E);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        // Invisible on the dark sheet; on the white light-theme sheet it is
        // the only thing marking where the ticket ends.
        border: Border.all(color: const Color(0xFFE6E8E0)),
      ),
      child: Column(
        children: [
          Text('₹${_money(amount)}', style: heroAmount(34, color: _ink)),
          const SizedBox(height: 6),
          Text(
            'to $name',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: uiText(size: 14, weight: FontWeight.w600, color: _ink),
          ),
          Text(
            upi,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: uiText(size: 12.5, color: _muted),
          ),
          const SizedBox(height: 14),
          QrImageView(
            data: uri,
            size: 220,
            padding: EdgeInsets.zero,
            backgroundColor: Colors.white,
            errorCorrectionLevel: QrErrorCorrectLevel.M,
            eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: eyeColor),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: _ink,
            ),
            semanticsLabel: 'UPI QR code for ₹${_money(amount)} to $upi',
          ),
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F2EE),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                reason,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: uiText(size: 12.5, color: _ink),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _Field({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: p.inkFaint),
          const SizedBox(width: 10),
          Text(label, style: uiText(size: 13, color: p.inkMuted)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: uiText(size: 14, weight: FontWeight.w500, color: p.ink),
            ),
          ),
        ],
      ),
    );
  }
}

/// Whole rupees without the ".00"; paise only when there are some.
String _money(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
