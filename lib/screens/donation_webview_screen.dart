import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class DonationWebViewScreen extends StatefulWidget {
  final String paymentUrl;
  final int? donationId;

  const DonationWebViewScreen({
    super.key,
    required this.paymentUrl,
    this.donationId,
  });

  @override
  State<DonationWebViewScreen> createState() =>
      _DonationWebViewScreenState();
}

class _DonationWebViewScreenState extends State<DonationWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (_) {
            setState(() {
              _isLoading = false;
            });
          },
          onNavigationRequest: (NavigationRequest request) {
            final Uri? uri = Uri.tryParse(request.url);
            if (uri == null) return NavigationDecision.navigate;

            final bool isSuccess = uri.path.contains('/donation/success');
            final bool isCancel = uri.path.contains('/donation/cancel');
            if (isSuccess || isCancel) {
              final int? donationIdFromUrl =
                  int.tryParse(uri.queryParameters['donationId'] ?? '');
              Navigator.of(context).pop(<String, dynamic>{
                'success': isSuccess,
                'donationId': donationIdFromUrl ?? widget.donationId,
              });
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thanh toán quyên góp'),
      ),
      body: Stack(
        children: <Widget>[
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}

