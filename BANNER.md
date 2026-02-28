# Banner & WebView Integration Guide (Flutter)

> **Base URL:** `https://ratemymantri.sallytion.qzz.io`
>
> **Last updated:** 2026-02-28

---

## Table of Contents

1. [Overview](#overview)
2. [Endpoints](#endpoints)
3. [Query Parameters](#query-parameters)
4. [Banner Image](#1-banner-image)
5. [Quiz Game Page](#2-quiz-game-page)
6. [Notice Board Page](#3-notice-board-page)
7. [Dark Mode Integration](#dark-mode-integration)
8. [Language / i18n Integration](#language--i18n-integration)
9. [Flutter WebView Code Examples](#flutter-webview-code-examples)
10. [Caching Behaviour](#caching-behaviour)
11. [Error Handling](#error-handling)
12. [Important Notes](#important-notes)

---

## Overview

The backend serves three banner-related resources that the Flutter app can consume:

| Resource        | Type       | Display Method      | Purpose                                  |
| --------------- | ---------- | ------------------- | ---------------------------------------- |
| Banner Image    | PNG image  | `Image.network()`   | App home screen banner / promotional art |
| Quiz Game       | HTML page  | `WebView`           | Interactive Indian politics quiz game    |
| Notice Board    | HTML page  | `WebView`           | Announcements, updates, notices          |

All HTML pages support **automatic translation** into 10 languages and **dark/light theme** switching via query parameters. No additional client-side logic is needed — the server returns fully rendered, translated HTML.

---

## Endpoints

| Method | Path                          | Response Type | Description             |
| ------ | ----------------------------- | ------------- | ----------------------- |
| GET    | `/api/banner.png`             | `image/png`   | Banner image            |
| GET    | `/api/banner/game.html`       | `text/html`   | Quiz game (full page)   |
| GET    | `/api/banner/noticeboard.html`| `text/html`   | Notice board (full page)|

---

## Query Parameters

Both query params are **optional** for all three endpoints. Defaults: `lang=en`, `theme=light`.

### `theme` — Dark / Light Mode

| Value   | Effect                                                   |
| ------- | -------------------------------------------------------- |
| `light` | Default light theme (white/cream backgrounds)            |
| `dark`  | Dark theme injected server-side (deep navy/charcoal backgrounds, light text) |

**Banner image:** Returns a different PNG file per theme (`banner_light.png` or `banner_dark.png`).
**HTML pages:** The same HTML is served with dark-mode CSS overrides injected before `</head>`.

### `lang` — Language

| Code | Language   |
| ---- | ---------- |
| `en` | English (default — no translation applied) |
| `hi` | Hindi      |
| `ta` | Tamil      |
| `te` | Telugu     |
| `pa` | Punjabi    |
| `mr` | Marathi    |
| `gu` | Gujarati   |
| `bn` | Bengali    |
| `kn` | Kannada    |
| `ml` | Malayalam  |

When a non-English `lang` is provided, **all visible text** is automatically translated server-side, including:

- Page title, headers, subtitles, footer
- Quiz questions, answer options, fact explanations, score messages, button labels
- Notice board titles, bodies, dates, category labels, form labels, placeholders, button text
- HTML `placeholder`, `title`, and `alt` attributes

The `<html lang="...">` attribute is also updated to match the requested language.

> **Note:** The `lang` param has no effect on `/api/banner.png` (it's an image).

---

## 1. Banner Image

### Endpoint

```
GET /api/banner.png?theme=light
GET /api/banner.png?theme=dark
```

### Response

- **Content-Type:** `image/png`
- **Cache-Control:** `public, max-age=3600` (cached for 1 hour)
- Returns a static PNG file

### Flutter Usage

```dart
Image.network(
  '$baseUrl/api/banner.png?theme=${isDark ? "dark" : "light"}',
  fit: BoxFit.cover,
  width: double.infinity,
);
```

Or use `CachedNetworkImage` for better performance:

```dart
CachedNetworkImage(
  imageUrl: '$baseUrl/api/banner.png?theme=${isDark ? "dark" : "light"}',
  fit: BoxFit.cover,
  width: double.infinity,
  placeholder: (_, __) => const SizedBox(height: 200),
  errorWidget: (_, __, ___) => const SizedBox.shrink(),
);
```

---

## 2. Quiz Game Page

### Endpoint

```
GET /api/banner/game.html?lang=hi&theme=dark
```

### Description

A fully self-contained, interactive 10-question quiz about Indian democracy and politics. Features:

- **10 shuffled questions** per game session (randomised order each play)
- **4 options per question** — tap to answer
- **Instant feedback** — correct/wrong indication with a factual explanation
- **Streak counter** — tracks consecutive correct answers
- **Progress bar** — visual progress through the quiz
- **Score screen** — final score with tiered message (Perfect / Excellent / Good / Keep Learning / Try Again)
- **Play Again** button — reshuffles and restarts
- **Fully responsive** — works on all screen sizes
- **No external dependencies** — everything is inline (CSS + JS)

### Response

- **Content-Type:** `text/html; charset=utf-8`
- **Cache-Control:** `no-store` (always fresh — content may change)
- Complete self-contained HTML page

---

## 3. Notice Board Page

### Endpoint

```
GET /api/banner/noticeboard.html?lang=ta&theme=dark
```

### Description

A cork-board style notice board displaying announcements and updates. Features:

- **4 pre-seeded notices** — V2 API launch, ratings system, search improvements, finding representatives
- **Sticky-note visual style** — each notice is a coloured card with a decorative push-pin
- **5 category badges:** Update (orange), Info (blue), Event (green), Alert (red), Tip (purple)
- **Post a Notice form** — users can add their own notices (stored in `localStorage`)
- **Fully responsive** grid layout
- **No external dependencies** — everything is inline

### Response

- **Content-Type:** `text/html; charset=utf-8`
- **Cache-Control:** `no-store`
- Complete self-contained HTML page

### localStorage Behaviour

- Key: `rmm_notices`
- User-posted notices persist in the WebView's localStorage
- If localStorage is empty, the 4 seed notices are shown
- **Note:** If the WebView instance is destroyed and recreated, localStorage may be lost depending on your WebView configuration. Consider enabling persistent storage if notice persistence matters.

---

## Dark Mode Integration

The Flutter app should pass the current theme to all endpoints:

```dart
String buildUrl(String path) {
  final theme = Theme.of(context).brightness == Brightness.dark ? 'dark' : 'light';
  final lang = appLocale.languageCode; // e.g. 'hi', 'ta', 'en'
  return '$baseUrl$path?lang=$lang&theme=$theme';
}

// Usage:
final gameUrl       = buildUrl('/api/banner/game.html');
final boardUrl      = buildUrl('/api/banner/noticeboard.html');
final bannerImgUrl  = '$baseUrl/api/banner.png?theme=${isDark ? "dark" : "light"}';
```

### Dark Mode Colour Palette

For reference, the dark theme uses these colours (in case you want to match surrounding Flutter UI):

| Role              | Hex       |
| ----------------- | --------- |
| Page background   | `#0f1117` |
| Card background   | `#1a1d27` |
| Primary text      | `#e8eaf6` |
| Secondary text    | `#9e9eb8` |
| Border            | `#2e3150` |
| Input background  | `#12141e` |
| Accent (saffron)  | `#ffb74d` |
| Accent (green)    | `#66bb6a` |
| Accent (navy)     | `#7986cb` |

### Light Mode Colour Palette

| Role              | Hex       |
| ----------------- | --------- |
| Page background   | `#fff7ee` → `#eaf4ea` (gradient) |
| Card background   | `#ffffff` |
| Primary text      | `#1a1a2e` |
| Secondary text    | `#555555` |
| Accent (saffron)  | `#FF9933` |
| Accent (green)    | `#138808` |
| Accent (navy)     | `#000080` |

---

## Language / i18n Integration

### How It Works

1. Flutter sends `?lang=hi` (or any supported code) in the URL
2. The server reads the HTML file fresh from disk
3. All visible text nodes and translatable attributes are extracted
4. Text is batch-translated via Google Translate API
5. Translated HTML is returned with `<html lang="hi">`
6. Results are cached in-memory (per content hash + lang + theme) — subsequent requests are instant

### Mapping Flutter Locale to `lang` Param

```dart
/// Map your app's locale to the backend lang code
String getLangCode(Locale locale) {
  const supported = {'en', 'hi', 'ta', 'te', 'pa', 'mr', 'gu', 'bn', 'kn', 'ml'};
  final code = locale.languageCode;
  return supported.contains(code) ? code : 'en';
}
```

### First Request Latency

| Scenario             | Approximate Latency |
| -------------------- | ------------------- |
| English (`lang=en`)  | ~5–15 ms            |
| Non-English (cached) | ~5–15 ms            |
| Non-English (first)  | ~1–4 seconds        |

The **first** request for a new language + content combination involves a Google Translate API call and may take 1–4 seconds. All subsequent requests for the same content + lang + theme are served from in-memory cache instantly.

**Recommendation:** Pre-warm the cache by firing a background request when the app starts:

```dart
// Pre-warm translation cache on app startup (fire and forget)
void prewarmBannerCache(String lang, String theme) {
  if (lang == 'en') return;
  http.get(Uri.parse('$baseUrl/api/banner/game.html?lang=$lang&theme=$theme'));
  http.get(Uri.parse('$baseUrl/api/banner/noticeboard.html?lang=$lang&theme=$theme'));
}
```

---

## Flutter WebView Code Examples

### Dependencies

```yaml
# pubspec.yaml
dependencies:
  webview_flutter: ^4.10.0
  # or
  flutter_inappwebview: ^6.1.5
```

### Basic WebView (webview_flutter)

```dart
import 'package:webview_flutter/webview_flutter.dart';

class GameWebView extends StatefulWidget {
  final String lang;
  final bool isDark;

  const GameWebView({required this.lang, required this.isDark, super.key});

  @override
  State<GameWebView> createState() => _GameWebViewState();
}

class _GameWebViewState extends State<GameWebView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    final theme = widget.isDark ? 'dark' : 'light';
    final url = 'https://ratemymantri.sallytion.qzz.io'
        '/api/banner/game.html?lang=${widget.lang}&theme=$theme';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(
        widget.isDark ? const Color(0xFF0f1117) : const Color(0xFFFFF7EE),
      )
      ..loadRequest(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quiz')),
      body: WebViewWidget(controller: _controller),
    );
  }
}
```

### Notice Board WebView

```dart
class NoticeBoardWebView extends StatefulWidget {
  final String lang;
  final bool isDark;

  const NoticeBoardWebView({required this.lang, required this.isDark, super.key});

  @override
  State<NoticeBoardWebView> createState() => _NoticeBoardWebViewState();
}

class _NoticeBoardWebViewState extends State<NoticeBoardWebView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    final theme = widget.isDark ? 'dark' : 'light';
    final url = 'https://ratemymantri.sallytion.qzz.io'
        '/api/banner/noticeboard.html?lang=${widget.lang}&theme=$theme';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(
        widget.isDark ? const Color(0xFF0f1117) : const Color(0xFFF0EBE1),
      )
      ..loadRequest(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notice Board')),
      body: WebViewWidget(controller: _controller),
    );
  }
}
```

### URL Builder Utility

```dart
class BannerUrls {
  static const _base = 'https://ratemymantri.sallytion.qzz.io';

  static String bannerImage({String theme = 'light'}) =>
      '$_base/api/banner.png?theme=$theme';

  static String game({String lang = 'en', String theme = 'light'}) =>
      '$_base/api/banner/game.html?lang=$lang&theme=$theme';

  static String noticeboard({String lang = 'en', String theme = 'light'}) =>
      '$_base/api/banner/noticeboard.html?lang=$lang&theme=$theme';
}
```

### Reloading on Theme / Language Change

If the user switches theme or language while the WebView is open, reload the page with new params:

```dart
void _reloadWebView(String lang, String theme) {
  final url = BannerUrls.game(lang: lang, theme: theme);
  _controller.loadRequest(Uri.parse(url));
}
```

---

## Caching Behaviour

| Endpoint             | Client Cache Header       | Server-Side Cache                        |
| -------------------- | ------------------------- | ---------------------------------------- |
| `/api/banner.png`    | `public, max-age=3600`    | None (static file)                       |
| `/api/banner/game.html`       | `no-store`      | In-memory (per content hash + lang + theme) |
| `/api/banner/noticeboard.html`| `no-store`      | In-memory (per content hash + lang + theme) |

- HTML pages use `no-store` so the Flutter WebView always fetches fresh content
- Server-side translation cache means repeated requests are fast (~5ms) even though `no-store` is set
- The in-memory cache resets on server restart
- Banner image is cached client-side for 1 hour

---

## Error Handling

| HTTP Status | Meaning                    | Recommended Action              |
| ----------- | -------------------------- | ------------------------------- |
| `200`       | Success                    | Display content                 |
| `404`       | Banner image not found     | Show placeholder / hide widget  |
| `500`       | Server error / file missing| Show error state or retry       |

```dart
_controller = WebViewController()
  ..setNavigationDelegate(
    NavigationDelegate(
      onHttpError: (error) {
        // Handle load failure — show fallback UI
        debugPrint('WebView HTTP error: ${error.response?.statusCode}');
      },
      onWebResourceError: (error) {
        debugPrint('WebView resource error: ${error.description}');
      },
    ),
  )
  ..loadRequest(Uri.parse(url));
```

---

## Important Notes

1. **JavaScript must be enabled** — both HTML pages use inline `<script>` for interactivity. Always set `JavaScriptMode.unrestricted`.

2. **Pages are fully self-contained** — no external CSS/JS/font CDN dependencies. Everything is inline. Pages work offline once loaded.

3. **Content updates require no app release** — the backend reads HTML files fresh on each request. Changing the HTML file on the server instantly updates what all users see.

4. **Unsupported `lang` codes fall back to English** — if an unknown language code is passed, the page is served in English without errors.

5. **Unsupported `theme` values fall back to light** — any value other than `"dark"` results in the light theme.

6. **No authentication required** — all banner endpoints are public. No JWT or API key needed.

7. **CORS** — these endpoints return HTML pages meant for WebView, not JSON APIs. Standard WebView loading works without CORS concerns.

8. **WebView background colour** — set the WebView's background colour to match the theme to avoid a white flash while loading:
   - Light: `#FFF7EE` (game) / `#F0EBE1` (noticeboard)
   - Dark: `#0F1117` (both)

9. **Mobile-responsive** — both pages are fully responsive and work well from 320px to 960px+ width. No horizontal scrolling.

10. **User-posted notices** — notices posted via the noticeboard form are saved to `localStorage`. They persist within the same WebView session. If you need cross-session persistence, configure the WebView to use persistent data storage.
