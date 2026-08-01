import 'dart:async';
import 'dart:js_interop';
// setProperty lives here; the Turnstile options object is a plain JS map
// whose keys ('error-callback') aren't valid Dart identifiers, so it can't be
// modelled as an extension type with external fields.
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../../../../core/network/captcha_config.dart';

const bool turnstileSupported = true;

const _scriptId = 'cf-turnstile-script';
const _scriptSrc =
    'https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit';

/// The Turnstile global, present only once the script above has loaded.
@JS('turnstile')
external _TurnstileApi? get _turnstile;

extension type _TurnstileApi(JSObject _) implements JSObject {
  external String render(web.Element container, JSObject options);
  external void reset(String widgetId);
  external void remove(String widgetId);
}

Future<void>? _scriptLoad;

/// Loads the Turnstile script once per page, no matter how many times the
/// widget is mounted.
Future<void> _ensureScriptLoaded() {
  final existing = _scriptLoad;
  if (existing != null) return existing;

  final completer = Completer<void>();
  final existingTag = web.document.getElementById(_scriptId);
  if (existingTag != null) {
    completer.complete();
  } else {
    final script = web.document.createElement('script') as web.HTMLScriptElement
      ..id = _scriptId
      ..src = _scriptSrc
      ..async = true
      ..defer = true;
    script.onload = ((JSAny _) => completer.complete()).toJS;
    script.onerror = ((JSAny _) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('Failed to load Turnstile'));
      }
    }).toJS;
    web.document.head!.appendChild(script);
  }

  return _scriptLoad = completer.future;
}

/// Each instance needs its own platform view type, since a view factory is
/// registered globally and keyed by name.
var _viewCounter = 0;

/// Renders the Turnstile challenge and reports the resulting token.
///
/// [onToken] is called with the token when the challenge is solved, and with
/// null whenever the token stops being valid (expired, errored, or reset), so
/// the caller can disable submission until a fresh one arrives.
class TurnstileWidget extends StatefulWidget {
  final ValueChanged<String?> onToken;

  const TurnstileWidget({super.key, required this.onToken});

  @override
  State<TurnstileWidget> createState() => _TurnstileWidgetState();
}

class _TurnstileWidgetState extends State<TurnstileWidget> {
  late final String _viewType;
  late final web.HTMLDivElement _container;
  String? _widgetId;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _viewType = 'cf-turnstile-${_viewCounter++}';
    _container = web.document.createElement('div') as web.HTMLDivElement;

    ui_web.platformViewRegistry
        .registerViewFactory(_viewType, (int viewId) => _container);

    unawaited(_render());
  }

  Future<void> _render() async {
    try {
      await _ensureScriptLoaded();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
      widget.onToken(null);
      return;
    }
    if (!mounted) return;

    final api = _turnstile;
    if (api == null) {
      setState(() => _failed = true);
      widget.onToken(null);
      return;
    }

    final options = JSObject()
      ..setProperty('sitekey'.toJS, CaptchaConfig.siteKey.toJS)
      ..setProperty('theme'.toJS, 'dark'.toJS)
      ..setProperty(
        'callback'.toJS,
        ((JSString token) => widget.onToken(token.toDart)).toJS,
      )
      ..setProperty(
        'expired-callback'.toJS,
        (() => widget.onToken(null)).toJS,
      )
      ..setProperty(
        'error-callback'.toJS,
        (() {
          widget.onToken(null);
          if (mounted) setState(() => _failed = true);
        }).toJS,
      );

    _widgetId = api.render(_container, options);
  }

  @override
  void dispose() {
    final id = _widgetId;
    if (id != null) _turnstile?.remove(id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Não foi possível carregar a verificação de segurança. '
          'Recarregue a página.',
          style: TextStyle(fontSize: 12),
        ),
      );
    }

    // Turnstile's own widget is a fixed 300x65 iframe.
    return SizedBox(
      height: 70,
      child: HtmlElementView(viewType: _viewType),
    );
  }
}
