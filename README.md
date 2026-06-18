# Invoice Ninja (Beta)

v2 client application for [Invoice Ninja](https://github.com/invoiceninja/invoiceninja).

#### Desktop Apps
- [Windows](https://apps.microsoft.com/detail/restricted/9NN6PVZSXWWB)
- [macOS](https://testflight.apple.com/join/YY1BZ7uR)
- [Linux] `sudo snap install invoiceninja --edge`

#### Mobile Apps
- [iOS](https://testflight.apple.com/join/YY1BZ7uR)
- [Android](https://play.google.com/apps/testing/com.invoiceninja.admin)

# Table of Contents

- [Setting up the app](#setting-up-the-app)
- [Application architecture](#application-architecture)
    - [Project structure](#project-structure)
    - [Documentation](#documentation)
- [Code generation](#code-generation)
- [Tests](#tests)
- [Screenshots](#screenshots)
- [Platforms](#platforms)
- [Feature parity](#feature-parity)
- [Credits](#credits)
- [Contributions](#contributions)
- [License](#license)

---

## Setting up the app

```sh
# 1. Enable the repo's pre-commit hook (formats staged Dart, mirrors CI)
git config core.hooksPath .githooks

# 2. Install dependencies
flutter pub get

# 3. Generate freezed / json_serializable / drift code
dart run build_runner build --delete-conflicting-outputs

# 4. Run (pick a device)
flutter run -d macos      # or -d chrome, or an iOS simulator
```

Don't have an Invoice Ninja backend? Test against the demo server:

- **URL:** `demo.invoiceninja.com`
- **Email:** `demo@invoiceninja.com`
- **Password:** `Password0`

To avoid retyping credentials, copy `dev.json.example` → `dev.json` and run with
`--dart-define-from-file=dev.json` (debug/profile only; release builds tree-shake it).
macOS entitlements, platform targets, and the web/WASM assets are documented in
[`docs/setup.md`](docs/setup.md).

## Application architecture

Layered MVVM: `ChangeNotifier` + `ListenableBuilder` only.

```
View (StatelessWidget)
  └─ ViewModel (ChangeNotifier)
       └─ Repository (single source of truth per entity)
            ├─ Drift database (local state, watched by streams)
            ├─ Outbox (offline mutation queue)
            └─ Service (HTTP client → /api/v1/...)
```

Drift is the only thing the UI reads from: the network writes *into* Drift, the UI
watches Drift. Every write goes through the outbox, so the app keeps working offline;
mutations reconcile with the server later via a strictly-ordered, idempotent drain
loop. Every list is scoped by `company_id` (multi-company), and on native platforms
Drift sits on SQLCipher (encrypted at rest).

### Project structure

```
lib/
├── main.dart         boot sequence (DI, restore, runApp)
├── app/              DI bag, router, theme, design tokens, env
├── data/
│   ├── models/       freezed domain models + API DTOs
│   ├── services/     HTTP clients (one per entity + shared ApiClient)
│   ├── repositories/ single source of truth per entity
│   └── db/           Drift database, DAOs, tables
├── domain/           entity types, registry, sync dispatchers
├── ui/
│   ├── core/         generic list/detail/edit scaffolds + shared widgets
│   └── features/     feature folders (auth, clients, products, …)
├── l10n/             localization delegate + supported locales
└── utils/            Formatter, parsing helpers, etc.
```

Every entity follows the same shape under `data/` and `ui/features/`. When in doubt,
mirror `Client`.

### Documentation

- [`ARCHITECTURE.md`](ARCHITECTURE.md), start here: the five layers, the login and
  create-product code flows, and cross-cutting concerns.
- [`CLAUDE.md`](CLAUDE.md): strict rules and invariants.
- [`FEATURES.md`](FEATURES.md): live parity tracker (React vs Flutter v1 vs this rebuild).
- [`BACKEND.md`](BACKEND.md): upstream API gaps this client depends on.
- [`docs/`](docs/), deep dives: [adding an entity](docs/adding-an-entity.md),
  [settings screens](docs/settings-screens.md),
  [the offline write pipeline](docs/architecture.md),
  [probing the demo API](docs/probing-the-demo-api.md),
  [integration tests](docs/integration-tests.md), [diagnostics](docs/diagnostics.md),
  and [setup](docs/setup.md).

## Code generation

Regenerate freezed models, JSON serializers, and Drift code after editing any
annotated source:

```sh
dart run build_runner build --delete-conflicting-outputs
```

## Tests

```sh
flutter analyze              # static analysis
flutter test                # unit + widget + repository-contract suite
flutter build web --wasm    # the authoritative web compile gate
```

Integration tests (`integration_test/`) boot the real app and **take over the
foreground**. Let CI run them; don't run them during a focused session. The
on-request procedure is in [`docs/integration-tests.md`](docs/integration-tests.md).

## Screenshots

The images at the top are generated, not hand-captured, produced by
`integration_test/screenshots_test.dart`, which boots the real app (web) against the
demo server and captures each marketing screen. This is a **local, on-demand** task
(needs `chromedriver`):

```sh
bash tools/capture_screenshots.sh   # writes PNGs into samples/screenshots/
```

## Platforms

- **Now:** iOS, macOS, web.
- **Later:** Android, Windows, Linux.

Web runs on drift WASM over IndexedDB (unencrypted: the browser origin sandbox is the
trust boundary); native iOS/macOS behavior is byte-identical. See
[`CLAUDE.md` § Web](CLAUDE.md#web) and [`docs/setup.md`](docs/setup.md).

## Feature parity

See [**FEATURES.md**](FEATURES.md) for the live tracker comparing every user-facing
feature across the React web client, Flutter v1 (`admin-portal`), and this rebuild.

## Credits

<https://github.com/invoiceninja/invoiceninja/tree/v5-develop#credits>

## Contributions

We gladly accept contributions! To get involved, join our
[Slack group](http://slack.invoiceninja.com/) or
[Discord server](https://discord.gg/ZwEdtfCwXA).

## License

See [`LICENSE.txt`](LICENSE.txt).
