import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class DonationWebViewScreen extends StatefulWidget {
  final String paymentUrl;

  const DonationWebViewScreen({
    super.key,
    required this.paymentUrl,
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

