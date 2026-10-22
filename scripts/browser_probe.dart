import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Drives the actual deployed Flutter UI through Chrome's local debug protocol.
/// No credentials are put in a build, file, URL, log or command-line argument.
class BrowserProbe {
  final WebSocket socket;
  final pending = <int, Completer<Map<String, dynamic>>>{};
  final messageRequests = <String>[];
  int sequence = 0;
  BrowserProbe(this.socket) {
    socket.listen((event) {
      final value = jsonDecode(event as String) as Map<String, dynamic>;
      final id = value['id'];
      if (id is int) pending.remove(id)?.complete(value);
      if (value['method'] == 'Network.responseReceived') {
        final params = value['params'] as Map;
        final response = params['response'] as Map;
        if (Uri.tryParse(response['url'] as String)?.path ==
            '/rest/v1/messages') {
          messageRequests.add(params['requestId'] as String);
        }
      }
    });
  }
  Future<Map<String, dynamic>> command(
    String method, [
    Map<String, dynamic>? params,
  ]) async {
    final id = ++sequence;
    final reply = Completer<Map<String, dynamic>>();
    pending[id] = reply;
    socket.add(
      jsonEncode({'id': id, 'method': method, 'params': params ?? {}}),
    );
    final value = await reply.future.timeout(const Duration(seconds: 20));
    if (value['error'] != null) {
      throw StateError('Browser command failed: $method');
    }
    return value['result'] as Map<String, dynamic>;
  }

  Future<dynamic> evaluate(String expression) async {
    final result = await command('Runtime.evaluate', {
      'expression': expression,
      'returnByValue': true,
      'awaitPromise': true,
    });
    if (result['exceptionDetails'] != null) {
      throw StateError('Browser expression failed');
    }
    return (result['result'] as Map)['value'];
  }

  static const dom = '''
    function all(selector, root=document) {
      let found=Array.from(root.querySelectorAll(selector));
      for(const element of root.querySelectorAll('*')) {
        if(element.shadowRoot) found.push(...all(selector,element.shadowRoot));
      }
      return found;
    }
    function label(element) { return (element.getAttribute('aria-label') || element.innerText || element.textContent || '').trim(); }
  ''';
  Future<void> until(Future<bool> Function() check, String stage) async {
    final deadline = DateTime.now().add(const Duration(seconds: 40));
    while (DateTime.now().isBefore(deadline)) {
      if (await check()) return;
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    throw StateError('Browser timeout: $stage');
  }

  Future<void> enableSemantics() async {
    await until(
      () async =>
          await evaluate(
            "(()=>{$dom const e=all('flt-semantics-placeholder')[0]; if(e) e.click(); return all('[role=button]').length>0;})()",
          ) ==
          true,
      'Flutter accessibility tree',
    );
  }

  Future<void> click(String selector, String text) async {
    final clicked = await evaluate('''(()=>{$dom
      const e=all(${jsonEncode(selector)}).find(e=>label(e)===${jsonEncode(text)}) || all(${jsonEncode(selector)}).find(e=>label(e).includes(${jsonEncode(text)}));
      if(!e) return false; e.click(); return true;
    })()''');
    if (clicked != true) {
      throw StateError('Browser control unavailable: $text');
    }
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }

  Future<void> fill(String name, String value) async {
    final found = await evaluate('''(()=>{$dom
      const e=all('input, textarea, [role=textbox]').find(e=>label(e)===${jsonEncode(name)});
      if(!e) return false; e.focus(); e.click(); return true;
    })()''');
    if (found != true) throw StateError('Browser input unavailable: $name');
    await Future<void>.delayed(const Duration(milliseconds: 150));
    await command('Input.insertText', {'text': value});
    final accepted = await evaluate(
      '''(()=>{$dom return all('input, textarea').some(e=>e.value===${jsonEncode(value)});})()''',
    );
    if (accepted != true) {
      throw StateError('Browser input did not accept text: $name');
    }
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }

  Future<void> waitText(String text) => until(
    () async =>
        await evaluate(
          '''(()=>{$dom return all('flt-semantics, [aria-label], textarea, input').some(e=>label(e).includes(${jsonEncode(text)}) || (typeof e.value==='string' && e.value.includes(${jsonEncode(text)})));})()''',
        ) ==
        true,
    'expected application content',
  );

  Future<void> selectLanguage({required bool english}) async {
    await click(
      '[role=button]',
      english ? 'اللغة: العربية' : 'Language: English',
    );
    await waitText(english ? 'English' : 'العربية');
    File('.local/language-menu-dom.json').writeAsStringSync(
      jsonEncode(
        await evaluate(
          "(()=>{$dom return all('[role=menuitemcheckbox]').map(e=>e.outerHTML);})()",
        ),
      ),
    );
    final focused = await evaluate(
      '''(()=>{$dom const e=all('[role=menuitemcheckbox]').find(e=>label(e)===${jsonEncode(english ? 'English' : 'العربية')});if(!e)return false;e.focus();return document.activeElement===e;})()''',
    );
    if (focused != true) throw StateError('Language option unavailable');
    // Focus and activate exactly once; semantics bounds can extend outside
    // Chrome's viewport even when the visual Flutter menu is correctly placed.
    for (final type in ['keyDown', 'keyUp']) {
      await command('Input.dispatchKeyEvent', {
        'type': type,
        'key': 'Enter',
        'code': 'Enter',
        'windowsVirtualKeyCode': 13,
      });
    }
    await waitText(english ? 'Language: English' : 'اللغة: العربية');
  }

  Future<void> waitPersistentMessage(String expected) => until(() async {
    var received = false;
    for (final id in messageRequests.toList()) {
      try {
        final body = await command('Network.getResponseBody', {
          'requestId': id,
        });
        final text = body['base64Encoded'] == true
            ? utf8.decode(base64Decode(body['body'] as String))
            : body['body'] as String;
        final rows = jsonDecode(text);
        if (rows is List &&
            rows.any((r) => r is Map && r['body'] == expected)) {
          received = true;
        }
      } catch (_) {
        /* Response may still be loading. No response bodies are logged. */
      }
    }
    // Flutter exposes SelectableText as native read-only textareas without its
    // text in the semantics label. Verify the real authorized network response
    // AND the three rendered message controls plus composer, then retain shots
    // for visual review; never infer persistence from a screen title alone.
    final rendered = await evaluate(
      "(()=>{$dom return all('textarea').length>=4;})()",
    );
    return received && rendered == true;
  }, 'authorized persistent messages and rendered conversation rows');

  Future<void> screenshot(String path) async {
    final shot = await command('Page.captureScreenshot');
    File(path).writeAsBytesSync(base64Decode(shot['data'] as String));
  }

  static Future<void> verify({
    required String url,
    required String email,
    required String password,
    required String conversationId,
    required String expectedMessage,
    bool readinessOnly = false,
    bool adminOnly = false,
    bool expanded = false,
  }) async {
    final uri = Uri.parse(url);
    if (uri.scheme != 'https' ||
        uri.host != 'mohamedmohsenarabtec-bot.github.io') {
      throw StateError('Unexpected preview origin');
    }
    final executable = Platform.isWindows
        ? r'C:\Program Files\Google\Chrome\Application\chrome.exe'
        : 'google-chrome';
    final profile = Directory(
      '.local/browser-${DateTime.now().microsecondsSinceEpoch}',
    ).absolute;
    profile.createSync(recursive: true);
    final reservation = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    final port = reservation.port;
    await reservation.close();
    final chrome = await Process.start(executable, [
      '--headless',
      '--disable-gpu',
      '--remote-debugging-port=$port',
      '--user-data-dir=${profile.path}',
      '--window-size=1440,1100',
      url,
    ]);
    unawaited(chrome.stdout.drain<void>());
    unawaited(chrome.stderr.drain<void>());
    final http = HttpClient();
    http.connectionTimeout = const Duration(seconds: 2);
    BrowserProbe? browser;
    var stage = 'connect to headless Chrome';
    try {
      final deadline = DateTime.now().add(const Duration(seconds: 30));
      List<dynamic> pages = [];
      while (pages.isEmpty && DateTime.now().isBefore(deadline)) {
        try {
          final response = await (await http.getUrl(
            Uri.parse('http://127.0.0.1:$port/json/list'),
          )).close();
          pages = jsonDecode(await utf8.decoder.bind(response).join()) as List;
        } catch (_) {
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
      }
      if (pages.isEmpty) {
        throw StateError('Headless Chrome did not start');
      }
      final page = pages.firstWhere((p) => p['type'] == 'page') as Map;
      browser = BrowserProbe(
        await WebSocket.connect(page['webSocketDebuggerUrl'] as String),
      );
      await browser.command('Network.enable');
      stage = 'activate Flutter accessibility';
      await browser.enableSemantics();
      stage = 'select English';
      await browser.selectLanguage(english: true);
      stage = 'English sign-in UI';
      await browser.waitText('Sign in');
      stage = 'persist dark appearance and English locale';
      await browser.click('[role=button]', 'Switch to dark theme');
      await browser.waitText('Switch to light theme');
      await browser.command('Page.reload', {'ignoreCache': true});
      await Future<void>.delayed(const Duration(seconds: 2));
      await browser.enableSemantics();
      await browser.waitText('Language: English');
      await browser.waitText('Switch to light theme');
      await browser.waitText('Sign in');
      if (readinessOnly) {
        await browser.fill('Email', 'local-ui-probe');
        await browser.fill('Password', 'local-ui-probe');
        await browser.click('[role=button]', 'Sign in');
        await browser.waitText('Enter a valid email');
        return;
      }
      stage = 'sign in through deployed UI';
      await browser.fill('Email', email);
      await browser.fill('Password', password);
      await browser.click('[role=button]', 'Sign in');
      if (adminOnly) {
        stage = 'open authorized owner administration';
        await browser.command('Page.navigate', {
          'url': uri.replace(fragment: '/admin').toString(),
        });
        await browser.enableSemantics();
        await browser.waitText('NOVA • Moderation');
        await browser.waitText('safety');
        await browser.screenshot('.local/owner-admin.png');
        await browser.click('[role=button]', 'Change password');
        await browser.waitText('Current password');
        await browser.waitText('Confirm new password');
        await browser.screenshot('.local/owner-password.png');
        return;
      }
      await browser.waitText('People, with intention');
      if (expanded) {
        for (final page in {
          '/account': 'Edit my profile and photos',
          '/profile/edit': 'Display name',
          '/filters': 'Apply',
          '/favorites': 'favorites',
          '/liked': 'Liked',
          '/notifications': 'Your notifications',
          '/referrals': 'invitation',
          '/plans': 'illustrative and unapproved',
        }.entries) {
          stage = 'real authenticated screen ${page.key}';
          await browser.command('Page.navigate', {
            'url': uri.replace(fragment: page.key).toString(),
          });
          await browser.enableSemantics();
          await browser.waitText(page.value);
          if (page.key == '/account') {
            final staffVisible = await browser.evaluate(
              "(()=>{$dom return all('[role=button]').some(e=>label(e).includes('Staff portal'));})()",
            );
            if (staffVisible == true) {
              throw StateError('Ordinary user sees staff portal');
            }
          }
        }
        await browser.command('Emulation.setDeviceMetricsOverride', {
          'width': 390,
          'height': 844,
          'deviceScaleFactor': 1,
          'mobile': true,
        });
        await browser.waitText('illustrative and unapproved');
        await Future<void>.delayed(const Duration(milliseconds: 500));
        await browser.screenshot('.local/browser-mobile-plans.png');
        await browser.command('Emulation.clearDeviceMetricsOverride');
      }
      stage = 'open real persistent conversation';
      final chatUrl = uri.replace(fragment: '/chat/$conversationId').toString();
      await browser.command('Page.navigate', {'url': chatUrl});
      await browser.enableSemantics();
      await browser.waitPersistentMessage(expectedMessage);
      await browser.waitText('Language: English');
      await browser.waitText('Switch to light theme');
      await browser.screenshot('.local/browser-before-reload.png');
      stage = 'switch live chat to Arabic';
      await browser.selectLanguage(english: false);
      await browser.waitText('رسالتك');
      await browser.waitText('اللغة: العربية');
      stage = 'reload browser and restore session';
      browser.messageRequests.clear();
      await browser.command('Page.reload', {'ignoreCache': true});
      await Future<void>.delayed(const Duration(seconds: 2));
      await browser.enableSemantics();
      await browser.waitPersistentMessage(expectedMessage);
      await browser.waitText('اللغة: العربية');
      await browser.waitText('تفعيل المظهر الفاتح');
      await browser.screenshot('.local/browser-after-reload.png');
    } catch (error) {
      if (browser != null) {
        try {
          final shot = await browser.command('Page.captureScreenshot');
          File('.local/browser-diagnostic.png')
              .writeAsBytesSync(base64Decode(shot['data'] as String));
          final labels = await browser.evaluate(
            "(()=>{$dom return all('[role], [aria-label], input, textarea').map(e=>{const r=e.getBoundingClientRect();return {role:e.getAttribute('role'),label:label(e),tag:e.tagName,x:r.x,y:r.y,width:r.width,height:r.height};});})()",
          );
          File('.local/browser-controls.json')
              .writeAsStringSync(jsonEncode(labels));
        } catch (_) {}
      }
      final detail = error is StateError
          ? error.message
          : error is FileSystemException
          ? '${error.runtimeType}, OS ${error.osError?.errorCode}'
          : error.runtimeType.toString();
      throw StateError('$stage: $detail');
    } finally {
      if (browser != null) {
        try {
          await browser.command('Storage.clearDataForOrigin', {
            'origin': uri.origin,
            'storageTypes': 'all',
          });
        } catch (_) {}
        try {
          await browser.command('Browser.close');
        } catch (_) {}
        await browser.socket.close();
      }
      chrome.kill();
      http.close(force: true);
      // Clear the isolated test browser's storage, including session tokens.
    }
  }
}
