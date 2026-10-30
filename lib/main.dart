import 'dart:async';
import 'dart:convert';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'front_page.dart';
import 'payment_return_page.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final configJson = await rootBundle.loadString('env.json');
    final config = jsonDecode(configJson) as Map<String, dynamic>;
    final supabaseUrl = config['SUPABASE_URL'] as String?;
    final supabasePublishableKey =
        config['SUPABASE_PUBLISHABLE_KEY'] as String?;

    if (supabaseUrl == null ||
        supabaseUrl.isEmpty ||
        supabasePublishableKey == null ||
        supabasePublishableKey.isEmpty) {
      throw const FormatException(
        'env.json must contain SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY.',
      );
    }

    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabasePublishableKey,
    );

    final auth = Supabase.instance.client.auth;
    if (auth.currentSession == null) {
      await auth.signInAnonymously();
    }
  } catch (error) {
    runApp(
      StartupErrorApp(
        message: 'Could not initialize Supabase. Check myapp/env.json. $error',
      ),
    );
    return;
  }

  runApp(const MyApp());
}

class StartupErrorApp extends StatelessWidget {
  final String message;

  const StartupErrorApp({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(message, textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _appLinks = AppLinks();
  final Set<String> _handledOrderIds = {};
  late final StreamSubscription<Uri> _linkSubscription;

  @override
  void initState() {
    super.initState();
    _linkSubscription = _appLinks.uriLinkStream.listen(
      _handlePaymentLink,
      onError: (Object error) => debugPrint('App link error: $error'),
    );
    _loadInitialLink();
  }

  Future<void> _loadInitialLink() async {
    try {
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) _handlePaymentLink(initialLink);
    } catch (error) {
      debugPrint('Could not read initial app link: $error');
    }
  }

  void _handlePaymentLink(Uri uri) {
    if (uri.scheme != 'ifinds' ||
        uri.host != 'payment' ||
        !const {'/success', '/failure'}.contains(uri.path)) {
      return;
    }

    final orderId = uri.queryParameters['order_id'];
    if (orderId == null ||
        !RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          caseSensitive: false,
        ).hasMatch(orderId) ||
        !_handledOrderIds.add(orderId)) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = appNavigatorKey.currentState;
      if (navigator == null) {
        _handledOrderIds.remove(orderId);
        return;
      }

      navigator
          .pushAndRemoveUntil(
            MaterialPageRoute<void>(
              builder: (_) => PaymentReturnPage(orderId: orderId),
            ),
            (route) => route.isFirst,
          )
          .whenComplete(() => _handledOrderIds.remove(orderId));
    });
  }

  @override
  void dispose() {
    _linkSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      home: const FrontPage(),
    );
  }
}
