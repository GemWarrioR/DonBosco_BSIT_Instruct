# 45-Minute Lesson: Real-Time Flutter Updates with ASP.NET Core SignalR

**Demo scenario:** An order's status changes on the backend and the Flutter screen updates live, without polling or refreshing.

## Learning outcomes

By the end of the lesson, students should be able to:

- Explain how SignalR supports server-to-client and client-to-server communication.
- Send an event from an ASP.NET Core API endpoint through a SignalR hub.
- Subscribe to that event in Flutter and render updates reactively.
- Describe how the UI should handle a failed API request or disconnected connection.

## Lesson flow

| Time | Activity |
|---|---|
| 0–5 min | Introduce the scenario: “How does the customer see an order update without refreshing?” Contrast polling with server-pushed events. |
| 5–12 min | Show the architecture and event contract. Identify the REST API as the trigger and SignalR as the notification channel. |
| 12–22 min | Walk through the backend hub, registration, and API endpoint. Trigger a sample status update. |
| 22–34 min | Connect Flutter, subscribe to the event, and display the latest order status with a `StreamBuilder`. |
| 34–40 min | Run the split-screen demo: call the API and observe the Flutter UI update. Briefly demonstrate disconnect and error handling. |
| 40–45 min | Discuss the 400 Bad Request question, recap, and check understanding. |

## Architecture and event contract

```text
API request ──> OrdersController ──> SignalR hub ──> Flutter clients
                                         │
                                         └─ ReceiveOrderUpdate
```

Example event payload:

```json
{
  "orderId": "ORD-1042",
  "status": "Ready for pickup"
}
```

Emphasize that the REST endpoint performs the action; SignalR notifies connected clients about the resulting change.

## Backend: ASP.NET Core

Register SignalR and map the hub:

```csharp
builder.Services.AddSignalR();

var app = builder.Build();

app.MapControllers();
app.MapHub<NotificationHub>("/hubs/notifications");

app.Run();

public sealed class NotificationHub : Hub
{
}
```

Send an update from an API endpoint:

```csharp
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;

public sealed record OrderStatusUpdate(string OrderId, string Status);
public sealed record UpdateOrderStatusRequest(string Status);

[ApiController]
[Route("api/orders")]
public sealed class OrdersController(IHubContext<NotificationHub> hub) : ControllerBase
{
    [HttpPost("{orderId}/status")]
    public async Task<IActionResult> UpdateStatus(
        string orderId,
        [FromBody] UpdateOrderStatusRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Status))
            return BadRequest("Status is required.");

        var update = new OrderStatusUpdate(orderId, request.Status.Trim());
        await hub.Clients.All.SendAsync(
            "ReceiveOrderUpdate",
            update);

        return Accepted();
    }
}
```

**Teaching note:** In a real app, send the notification after the status change has been successfully saved. For a focused demo, the endpoint can validate and broadcast directly.

If Flutter runs on another origin, configure CORS with that specific origin and credentials, and apply the CORS policy. Avoid combining `AllowAnyOrigin()` with credentials.

## Flutter: subscribe and render updates

Install the `signalr_netcore` package and create a connection to the mapped hub URL. The host depends on where the app runs: an Android emulator commonly reaches the development machine via `10.0.2.2`, while a physical device needs a reachable LAN address.

A simple service can expose incoming events as a stream:

```dart
import 'dart:async';
import 'package:signalr_netcore/signalr_client.dart';

class OrderUpdates {
  final _updates = StreamController<Map<String, dynamic>>.broadcast();
  late final HubConnection _connection;

  Stream<Map<String, dynamic>> get stream => _updates.stream;

  Future<void> connect(String hubUrl) async {
    _connection = HubConnectionBuilder().withUrl(hubUrl).build();

    _connection.on('ReceiveOrderUpdate', (arguments) {
      if (arguments == null || arguments.isEmpty) return;

      final payload = Map<String, dynamic>.from(
        arguments.first as Map,
      );
      _updates.add(payload);
    });

    await _connection.start();
  }

  Future<void> dispose() async {
    await _connection.stop();
    await _updates.close();
  }
}
```

Render the latest event with a `StreamBuilder`:

```dart
StreamBuilder<Map<String, dynamic>>(
  stream: orderUpdates.stream,
  builder: (context, snapshot) {
    if (snapshot.hasError) {
      return const Text('Live updates are unavailable.');
    }

    if (!snapshot.hasData) {
      return const Text('Waiting for order updates…');
    }

    final update = snapshot.data!;
    return Text('Order ${update['orderId']}: ${update['status']}');
  },
)
```

**For review:** This is a teaching sketch, not production-ready code. Production code should handle connection startup failures, reconnection, stream disposal, payload validation, and the package's concrete callback types without unchecked casts.

## Demo sequence

1. Start the ASP.NET Core API and Flutter app.
2. Show the Flutter screen waiting for an update.
3. Send a `POST` request to `/api/orders/ORD-1042/status` with `{"orderId":"ORD-1042","status":"Ready for pickup"}`.
4. Point out the new status appearing in Flutter without a refresh.

## Engagement question: handling a 400 response

Ask: **“If this endpoint returns a 400 Bad Request, how should our Flutter UI react so the user isn’t stuck on an infinite loading spinner?”**

Expected points:

- Check the HTTP response and show a useful validation or error message.
- Clear the loading state on both success and failure, for example with `try/catch/finally`.
- Don’t treat an API failure as a successful status update; keep the prior state or allow retry.
- Keep the API request state separate from the live connection state.

## Pedagogical takeaway

SignalR is useful when updates should reach connected clients promptly. REST can remain the command interface, while SignalR delivers resulting events. This separation makes the demonstration dynamic while introducing a common real-time system design pattern.
