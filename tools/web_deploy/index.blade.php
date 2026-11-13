<!DOCTYPE html>
{{-- Deploy to Web's boot page for the new admin app (docs/web-deploy.md).
     Source of truth: tools/web_deploy/index.blade.php in invoiceninja/flutter;
     staged into resources/views/flutter/index.blade.php and rendered by
     tools/web_deploy/render_boot_page.py. Every variable is optional (`??`), so
     a controller that passes fewer of them can never 500 the page. The glue
     blocks match web/index.html (test/lint/web_boot_page_glue_test.dart). --}}
<html data-served="1" data-hosted="{{ ($is_hosted ?? false) ? '1' : '0' }}" data-signup="{{ $signup ?? '' }}" data-rc="{{ $rc ?? '' }}" data-white-label="{{ $white_label ?? '' }}" data-api-url="{{ $api_url ?? '' }}" data-google-client-id="{{ $google_client_id ?? '' }}" data-microsoft-client-id="{{ $microsoft_client_id ?? '' }}" data-apple-client-id="{{ $apple_client_id ?? '' }}">
<head>
  <base href="{{ $base_href ?? '/flutter/' }}">
  <meta charset="UTF-8">
  <meta content="IE=Edge" http-equiv="X-UA-Compatible">
  <meta name="mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="black">
  <link rel="apple-touch-icon" href="icons/Icon-192.png">
  <link rel="icon" type="image/x-icon" href="favicon.ico"/>
  <link rel="icon" type="image/png" href="favicon.png"/>
  <meta name="theme-color" content="#F6F4EF" media="(prefers-color-scheme: light)">
  <meta name="theme-color" content="#15140F" media="(prefers-color-scheme: dark)">
  <title>{{ ($white_label ?? false) ? '' : 'Invoice Ninja' }}</title>
  <link rel="manifest" href="manifest.json">
  <script>
    (function () {
      // The static hosted page (Cloudflare Pages, docs/web-deploy.md § Going
      // live) can't template ?signup=true and ?rc=, so they are copied from
      // the URL here, before the app reads them. A page the server rendered
      // has filled them already, and that value wins.
      var root = document.documentElement;
      // Only the static page names its API; a server-rendered page decides
      // these itself (it may drop a referral code on purpose).
      if (!root.getAttribute('data-api-url')) return;
      var query = new URLSearchParams(location.search);
      if (!root.getAttribute('data-signup') && query.get('signup') === 'true') {
        root.setAttribute('data-signup', 'true');
      }
      if (!root.getAttribute('data-rc') && query.get('rc')) {
        root.setAttribute('data-rc', query.get('rc'));
      }
    })();
  </script>

  <script>
    (function () {
      // The sign-in SDKs, each only when the page names a client ID for it
      // (docs/web-deploy.md § Web sign-in). Loaded with the page, never on a
      // tap: a sign-in window opened after the app awaited a download is
      // blocked as a pop-up. MSAL is vendored next to the build, like pdf.js.
      var root = document.documentElement;
      function load(attribute, src) {
        if (!root.getAttribute(attribute)) return;
        var s = document.createElement('script');
        s.src = src;
        s.async = true;
        document.head.appendChild(s);
      }
      load('data-google-client-id', 'https://accounts.google.com/gsi/client');
      load('data-microsoft-client-id', 'msal/msal-browser.min.js?v=4.30.0');
      load('data-apple-client-id', 'https://appleid.cdn-apple.com/appleauth/static/jsapi/appleid/1/en_US/appleid.auth.js');
    })();
  </script>

  <!-- glue:start loader-style -->
  <style>
    /* Boot loader shown until Flutter paints its first frame. Ported from
       admin-portal/web/index.html — three-dot spinner from
       https://projects.lukehaas.me/css-loaders/ */
    body { margin: 0; background-color: #888888; }
    #loader {
      position: absolute;
      inset: 0;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .loader,
    .loader:before,
    .loader:after {
      border-radius: 50%;
      width: 2.5em;
      height: 2.5em;
      -webkit-animation-fill-mode: both;
      animation-fill-mode: both;
      -webkit-animation: load7 1.8s infinite ease-in-out;
      animation: load7 1.8s infinite ease-in-out;
    }
    .loader {
      color: #ffffff;
      font-size: 10px;
      position: relative;
      text-indent: -9999em;
      -webkit-transform: translateZ(0);
      -ms-transform: translateZ(0);
      transform: translateZ(0);
      -webkit-animation-delay: -0.40s;
      animation-delay: -0.40s;
    }
    .loader:before,
    .loader:after {
      content: '';
      position: absolute;
      top: 0;
    }
    .loader:before {
      left: -3.5em;
      -webkit-animation-delay: -0.80s;
      animation-delay: -0.80s;
    }
    .loader:after {
      left: 3.5em;
    }
    @-webkit-keyframes load7 {
      0%, 80%, 100% { box-shadow: 0 2.5em 0 -1.3em; }
      40% { box-shadow: 0 2.5em 0 0; }
    }
    @keyframes load7 {
      0%, 80%, 100% { box-shadow: 0 2.5em 0 -1.3em; }
      40% { box-shadow: 0 2.5em 0 0; }
    }
  </style>
  <!-- glue:end -->

  <!-- glue:start pdfjs -->
  <script>
    window.dartPdfJsBaseUrl = new URL('pdfjs/', document.baseURI).href;
  </script>
  <!-- glue:end -->

  @if ($is_hosted ?? false)
  <!-- G Tag Manager -->
  <script>(function(w,d,s,l,i){w[l]=w[l]||[];w[l].push({'gtm.start':
  new Date().getTime(),event:'gtm.js'});var f=d.getElementsByTagName(s)[0],
  j=d.createElement(s),dl=l!='dataLayer'?'&l='+l:'';j.async=true;j.src=
  'https://www.googletagmanager.com/gtm.js?id='+i+dl;f.parentNode.insertBefore(j,f);
  })(window,document,'script','dataLayer','GTM-WMJ5W23');</script>
  <!-- End G Tag Manager -->
  @endif
</head>
<body>
  @if ($is_hosted ?? false)
  <noscript><iframe src="https://www.googletagmanager.com/ns.html?id=GTM-WMJ5W23"
  height="0" width="0" style="display:none;visibility:hidden"></iframe></noscript>
  @endif

  <!-- glue:start loader -->
  <div id="loader"><div class="loader"></div></div>
  <!-- glue:end -->

  <script>
    (function () {
      // The old app's page registered flutter_service_worker.js?v=<version> at
      // the site root. Today's copy is a self-unregistering stub, but it reloads
      // the page when it activates, and a reload mid-boot can wedge the web
      // database. So when that worker still controls this page, drop it and
      // reload once BEFORE the app starts; otherwise boot straight away.
      var BOOTSTRAP = 'flutter_bootstrap.js?v=__BOOTSTRAP_VERSION__';
      var OLD = '/flutter_service_worker.js';
      var KEY = 'invoiceninja.v2.sw-cleanup';
      function isOld(scriptURL) {
        try {
          var path = new URL(scriptURL).pathname;
          return path.slice(-OLD.length) === OLD;
        } catch (e) {
          return false;
        }
      }
      function boot() {
        var s = document.createElement('script');
        s.src = BOOTSTRAP;
        s.async = true;
        document.body.appendChild(s);
      }
      var sw = navigator.serviceWorker;
      var controller = sw && sw.controller;
      if (!controller || !isOld(controller.scriptURL)) {
        try { sessionStorage.removeItem(KEY); } catch (e) {}
        boot();
        return;
      }
      var already = true;
      try {
        already = sessionStorage.getItem(KEY) === '1';
        sessionStorage.setItem(KEY, '1');
      } catch (e) {}
      if (already) {
        // Unregistering didn't take (or storage is off): boot anyway rather
        // than loop.
        boot();
        return;
      }
      var scope = new URL('../', document.baseURI).href;
      sw.getRegistrations().then(function (regs) {
        return Promise.all(regs.filter(function (r) {
          var w = r.active || r.waiting || r.installing;
          return r.scope === scope && w && isOld(w.scriptURL);
        }).map(function (r) { return r.unregister(); }));
      }).then(function () { window.location.reload(); },
              function () { window.location.reload(); });
    })();
  </script>
  <!-- glue:start first-frame -->
  <script>
    (function () {
      // Drop the boot loader once Flutter paints its first frame. The loader
      // carries no z-index, so Flutter's view already covers it before this
      // fires — this just cleans the node out of the DOM.
      var painted = false;
      window.addEventListener('flutter-first-frame', function () {
        painted = true;
        // Read by Deploy to Web's boot smoke (docs/web-deploy.md).
        window.__flutterFirstFrame = true;
        var el = document.getElementById('loader');
        if (el && el.parentNode) el.parentNode.removeChild(el);
      });
      // Safety-net: boot must never leave the user on an endless spinner. If
      // the first frame hasn't painted after 30s the boot is wedged — most
      // likely a transient web-database lock left by a service-worker reload
      // after a redeploy (see lib/data/db/database_opener_web.dart, which now
      // time-bounds WasmDatabase.open). Swap the spinner for a one-tap reload,
      // which clears the stale lock.
      window.setTimeout(function () {
        if (painted) return;
        var el = document.getElementById('loader');
        if (!el) return;
        el.innerHTML =
          '<div style="font-family:system-ui,-apple-system,sans-serif;color:#fff;' +
          'text-align:center;max-width:320px;padding:24px;line-height:1.5">' +
          '<div style="margin-bottom:16px">This is taking longer than expected.</div>' +
          '<button onclick="window.location.reload()" ' +
          'style="font:inherit;color:#1f2937;background:#fff;border:0;' +
          'border-radius:6px;padding:8px 22px;cursor:pointer">Reload</button>' +
          '</div>';
      }, 30000);
    })();
  </script>
  <!-- glue:end -->
</body>
</html>
