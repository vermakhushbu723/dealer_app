# ICECLUB Dealer App

Flutter app for ICECLUB dealers: register, order ice, track deliveries, manage credit and raise complaints.
It builds for Android, iOS and the web (`dealer.iceclub.online`).
The Admin Panel and Driver App are planned as separate projects next to this folder.

## Run

```
flutter pub get
flutter run
```

Demo account: mobile `9876543210`, OTP `123456`, password `Demo@1234`. It has sample orders, a credit balance and
complaints. Any other number with the same OTP starts a new registration.

## Folder structure

```
lib/
  main.dart               entry point
  app/                    app widget, routes, router, bottom navigation
  core/                   shared by all features
    constants/            contact details and business settings
    error/                errors that are safe to show to dealers
    location/             GPS
    storage/              on-device JSON store
    theme/                colours, text sizes, ThemeData
    utils/                formatters, validators, phone and WhatsApp links
    widgets/              shared UI
  features/<feature>/
    domain/               entities and repository interfaces, no Flutter UI
    data/                 repository implementations
    presentation/         providers and screens
```

## Menu to feature map

| Menu item | Feature folder |
| --- | --- |
| Dashboard | `home` |
| Place new order, repeat previous order | `catalog`, `cart`, `orders` |
| My orders | `orders` |
| Track my delivery | `tracking` |
| Products and price list | `catalog` |
| Payments, my account / ledger, invoices and GST bills | `payments` |
| Quality and damage complaints | `complaints` |
| Delivery schedule | `delivery_schedule`, `standing_orders` |
| Offers and schemes | `offers` |
| My business profile | `profile`, `addresses` |
| Notifications | `notifications` |
| Customer support | `support` |
| Settings | `settings` |

Extras: `ice_boxes`, `calculator`, `reports`.

## Connecting a real backend

There is no server yet. Every `data/fake_*_repository.dart` keeps its data on the device, so the app runs without a
backend, but nothing is shared between devices or with the company. To go live, write an API version of each
repository and swap it in the feature's provider. Screens only depend on the interfaces in `domain/`.

The server must enforce these rules. The app alone can't guarantee them:

| Requirement | Today, in the app | Needed in production |
| --- | --- | --- |
| Dealers see only their own data | Data is kept apart per dealer on the device | Server checks on every request |
| Admin controls dealer pricing | Rate fixed per tier in `fake_catalog_repository.dart` | Admin Panel and price API |
| Unique order ID | Built from date, dealer number and time | Server assigns it |
| Admin approves or rejects complaints | New complaints stay under review; the demo account has decided samples | Admin Panel |
| Photo server timestamp | Set from the phone's clock | Server sets it on upload |
| Automatic notifications | In-app only | Firebase Cloud Messaging |
| Credit and balance update automatically | Worked out on the device | Server ledger |
| Live rider location | Simulated rider and fixed map points | Driver App, saved address coordinates |
| OTP and password login | OTP is always `123456`; password hash is on the device | SMS provider and server login |
| KYC approval | Approved when the dealer checks status | Admin Panel |
| Pay online | Marked paid straight away | Payment gateway such as Razorpay |
| Order progress | Moves forward on a timer | Admin Panel and Driver App |
| Standing orders | Placed when the app opens | Scheduled job on the server |

Maps use public OpenStreetMap tiles, which are fine for development. Production needs a paid tile provider or
Google Maps, under their usage policies.

## Before going live

These values are placeholders because the company hasn't supplied them:

- Company GSTIN, FSSAI number and UPI ID: `core/constants/app_constants.dart`. Invoices print "TAX INVOICE" and the
  UPI button works only once these are filled in.
- Pack sizes, prices, slabs, HSN codes, tax rates and stock: `features/catalog/data/fake_catalog_repository.dart`
- Slab ice description and usage warning: same file. The website doesn't mention slab ice.
- Minimum order, delivery fee, free delivery amount, ice box deposit, delivery slots: `core/constants/app_constants.dart`
- Offers and schemes: `features/offers/data/fake_offer_repository.dart`
- Ice calculator figures: `features/calculator/presentation/calculator_screen.dart`

Have an accountant check the invoice format before using it for GST filing. Application ID
`in.iceclubstore.dealer_app` also needs confirming before release.

## Theme

- Colours: premium blue and white, based on iceclubstore.in.
- Fonts and text sizes: achivora.com at phone width, with Sora for headings and Manrope for text. The fonts are bundled
  in `assets/fonts`, under the SIL Open Font License.
- Cards, fields, buttons, bottom bar and spacing: the `growork-user-app` design.

## Tests

```
flutter test
```

`test/screens_smoke_test.dart` opens every screen on a small phone and fails on crashes or layout overflows.
