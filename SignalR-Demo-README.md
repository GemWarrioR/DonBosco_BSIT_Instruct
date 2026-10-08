# Live Order Status: Flutter + ASP.NET Core SignalR

A teaching demo for real-time, server-pushed UI updates. A Flutter button calls a REST endpoint; the ASP.NET Core API broadcasts the changed order status through SignalR; the Flutter screen renders it immediately.

## Prerequisites

- .NET 8 SDK
- Flutter SDK and a supported browser (for example, Chrome)

## Start the API

From the workspace root:

```powershell
dotnet run --project .\SignalR.Api\SignalR.Api.csproj -- --urls http://localhost:5000
```

The API exposes:

- SignalR hub: `http://localhost:5000/hubs/notifications`
- Update endpoint: `POST http://localhost:5000/api/orders/ORD-1042/status`
- Request body: `{"status":"Ready for pickup"}`

The endpoint returns `202 Accepted` after broadcasting. An empty status returns `400 Bad Request` with a message.

## Generate Flutter platform scaffolding

The `flutter_client` directory contains the demo's Dart app and dependency manifest. Generate a standard Flutter project in a separate folder, then copy in the provided app source. This keeps the supplied source files intact:

```powershell
flutter create --project-name signalr_order_demo .\flutter_order_app
Copy-Item .\flutter_client\pubspec.yaml .\flutter_order_app\pubspec.yaml -Force
Copy-Item .\flutter_client\lib\main.dart .\flutter_order_app\lib\main.dart -Force
Set-Location .\flutter_order_app
flutter pub get
flutter run -d chrome
```

To run against a different API address:

```powershell
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:5000
```

For an Android emulator, use `http://10.0.2.2:5000` as `API_BASE_URL`. For a physical device, use the development machine's reachable LAN address and permit the API port through the local firewall. Plain HTTP is for local development only.

Android may block local plain-HTTP traffic by default. For this development demo only, add `android:usesCleartextTraffic="true"` to the `<application>` element in `android\app\src\main\AndroidManifest.xml`. Do not enable cleartext traffic for a production build.

## Demonstrate the event

1. Start the API and Flutter app.
2. Confirm the app shows **Live updates: Connected**.
3. Select **Send next status**. The app calls the REST endpoint and the order status changes as the SignalR event arrives.
4. Open another app instance to show that `Clients.All` broadcasts to all connected clients.
5. Stop the API or submit an empty status with a REST client to discuss connection and request errors.

Sample request:

```powershell
Invoke-RestMethod `
  -Method Post `
  -Uri http://localhost:5000/api/orders/ORD-1042/status `
  -ContentType "application/json" `
  -Body '{"status":"Ready for pickup"}'
```

## Teaching notes

- REST is the command path; SignalR delivers the event to connected clients.
- The sample keeps state in memory and does not persist orders. In a real system, persist the change first and broadcast only after the write succeeds.
- The CORS policy is restricted to loopback hosts for local browser development. Update it to the exact trusted frontend origin when deploying; do not use unrestricted origins with credentials.
- The Flutter UI presents HTTP errors and uses `finally` to clear its loading state. SignalR connection status and API request status are shown separately.
- The sample uses automatic reconnection. For production, also expose reconnecting/reconnected state, handle authentication and authorization, and decide how clients recover events missed while offline.
