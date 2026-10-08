# Detailed Lesson Plan

## Real-Time Mobile Communication: Flutter UI Updates with ASP.NET Core SignalR

| Lesson information | Details |
|---|---|
| Subject area | Mobile Application Development / Web API Integration |
| Topic | Real-time communication using ASP.NET Core SignalR and Flutter |
| Duration | 45 minutes |
| Lesson format | Instructor demonstration, guided code walkthrough, and formative assessment |
| Demo scenario | Live order status update |
| Target learners | Students with introductory experience in C#, REST APIs, and Flutter/Dart |

## I. Learning objectives

By the end of class, students should be able to:

1. **Describe** the difference between polling and server-pushed real-time updates.
2. **Identify** the role of the SignalR hub, REST endpoint, event name, and Flutter client in the demo architecture.
3. **Trace** an order-status event from an HTTP request through `IHubContext` to a Flutter event handler.
4. **Demonstrate** how a Flutter widget displays an incoming SignalR update.
5. **Propose** an appropriate UI response to a `400 Bad Request` or a lost SignalR connection.

### What I’ll look for

Students are on track if they can:

- Explain that the API request triggers the update and SignalR sends it to connected clients.
- Point out the hub route (`/hubs/notifications`) and event name (`ReceiveOrderUpdate`).
- Explain why the app should stop showing a loading indicator whether the request succeeds or fails.

## II. Subject matter

**Main idea:** Use SignalR to send updates between an ASP.NET Core server and connected Flutter clients. SignalR can use WebSockets when the connection supports them.

**Key terms**

- **Hub:** SignalR endpoint that manages client connections and messaging.
- **Client:** A connected application that can receive hub messages and invoke hub methods.
- **Broadcast:** Sending an event to a set of connected clients, such as `Clients.All`.
- **Event name:** The method name used by the server and client to identify a message, here `ReceiveOrderUpdate`.
- **Reactive UI:** A user interface that rebuilds in response to new application data.

**Architecture**

```text
Flutter button
    │ HTTP POST /api/orders/{orderId}/status
    ▼
ASP.NET Core OrdersController
    │ IHubContext<NotificationHub>.Clients.All.SendAsync(...)
    ▼
SignalR NotificationHub ── ReceiveOrderUpdate ──> Flutter event handler
                                                    │
                                                    ▼
                                              Updated UI state
```

**Event payload**

```json
{
  "orderId": "ORD-1042",
  "status": "Ready for pickup"
}
```

## III. Materials and preparation

### Materials

- Computer with Visual Studio or VS Code.
- ASP.NET Core API project and Flutter client prepared before class.
- .NET 8 SDK and Flutter SDK installed on the instructor's demo machine.
- Browser, Android emulator, or iOS simulator.
- Terminal or REST client for sending a sample HTTP request.
- Projector or display configured to show source code and the running client side by side.

### Before class

1. Start the API at `http://localhost:5000` and check that it responds.
2. Make sure the hub is available at `/hubs/notifications`.
3. Run the Flutter app with the right `API_BASE_URL` for the browser or emulator.
4. Check that the screen says **Live updates: Connected**.
5. Keep a sample `POST` request handy in case the app's button doesn't work.
6. If time allows, open a second client to show both screens receiving the update.

### Important setup note

For Flutter Web, the API must allow requests from the web app's development origin. An Android emulator usually reaches the host computer at `10.0.2.2`; a phone needs the computer's reachable LAN address. For anything beyond a local classroom demo, use HTTPS and restrict allowed origins.

## IV. Teaching and learning procedure

| Time | What we'll do | Instructor | Students | Check for understanding |
|---|---|---|---|---|
| 0–4 min | A customer is waiting for an order | Show the order screen and ask, “The order is ready now. How does the customer find out without refreshing?” | Share ideas: refresh, keep checking, or get an automatic update. | Note what students already know about polling and live updates. |
| 4–8 min | Why use a live connection? | Compare repeated polling with a message pushed by the server. Mention that SignalR uses WebSockets when available and can fall back to other transports. | Discuss which approach feels better for an order-status screen and why. | Ask for one downside of checking the server repeatedly. |
| 8–12 min | Follow one update | Walk through the diagram: the app sends a request, the API handles it, SignalR broadcasts the result, and the screen changes. Point out that `Clients.All` is used to keep this demo simple. | Follow along and identify who sends and who receives the update. | Ask, “What changes the order, and what tells the screens about it?” |
| 12–19 min | Look at the backend | Show `AddSignalR`, the hub route, and `NotificationHub`. Then follow the controller to `IHubContext` and `SendAsync("ReceiveOrderUpdate", update)`. | Predict what will happen when the endpoint is called. | Students should be able to find the route and event name. |
| 19–23 min | Trigger an update | Send a valid `POST` request and point out the response. If there's time, send a blank status and look at the validation error. | Watch the result and explain why the invalid request shouldn't be broadcast. | Check that students can tell a rejected request from an accepted update. |
| 23–31 min | Follow the message in Flutter | Show the hub URL, the event handler, payload checks, and the state update. Explain that `StreamBuilder` redraws when a new value arrives. | Trace the message from the handler to the status on screen. | Ask, “What needs to match in the C# and Dart code?” |
| 31–37 min | See it work | Put the code beside the running app. Press the update button or send a request from the terminal. If ready, show a second client receiving the same event. | Watch the screen update without a refresh and describe what happened. | Invite a student to narrate the request-and-event sequence. |
| 37–41 min | What if something goes wrong? | Ask the focus question below. Show the error message and loading indicator behavior; distinguish an HTTP error from a lost SignalR connection. | Suggest what the app should show and how the user could recover. | Listen for a clear error, stopped spinner, and a sensible retry or recovery. |
| 41–45 min | Wrap up | Ask the exit questions, review the answers, and return to the main idea. | Answer the questions aloud or on a short exit slip. | Use the answers to see what needs revisiting next class. |

## V. Instructor demonstration code

### ASP.NET Core registration and hub mapping

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

### API endpoint broadcast

The demo endpoint accepts `{"status":"Ready for pickup"}` and broadcasts the order ID and new status:

```csharp
[HttpPost("{orderId}/status")]
public async Task<IActionResult> UpdateStatus(
    string orderId,
    [FromBody] UpdateOrderStatusRequest request)
{
    if (string.IsNullOrWhiteSpace(request.Status))
    {
        return BadRequest(new { message = "Status is required." });
    }

    var update = new OrderStatusUpdate(orderId, request.Status.Trim());
    await hub.Clients.All.SendAsync("ReceiveOrderUpdate", update);

    return Accepted(update);
}
```

### Flutter subscription concept

```dart
_connection.on('ReceiveOrderUpdate', (arguments) {
  // Validate the event payload, then update application state.
});
```

The actual demo app validates the received payload and updates the displayed order status. The server event name and the Flutter subscription name must match.

## VI. Class discussion: handling a failed request

Ask the class: **“If this endpoint returns a 400 Bad Request, what should the Flutter screen do so the user isn't left staring at a loading spinner?”**

Look for answers along these lines:

- Inspect the non-success HTTP status and display a useful validation message.
- Clear the loading indicator after both success and failure, such as in a `finally` block.
- Do not show the rejected status as if it were saved; preserve the previous status or allow a retry.
- Keep API request progress separate from SignalR connection state.

Then ask: **“What if the API request succeeds, but the SignalR connection drops?”**

Students might suggest showing a reconnecting message, trying the connection again, or fetching the latest status after reconnecting in case an event was missed.

## VII. Formative assessment

### Quick exit check

Before leaving, ask students to answer:

1. What is the purpose of `NotificationHub`?
2. Which two names must match for the Flutter event handler to receive the server message?
3. Name one action the UI should take when the status endpoint returns `400 Bad Request`.

### Answers to listen for

| Question | A good answer includes |
|---|---|
| 1 | The hub is where SignalR-connected clients and the server exchange messages. |
| 2 | The event name passed to `SendAsync` must match the Flutter handler name: `ReceiveOrderUpdate`. |
| 3 | Show an error, stop loading, keep the last valid status, or let the user retry. |

If students can answer at least two questions—and understand that a failed request must clear the loading state—they've got the main points.

## VIII. If students need support—or are ready for more

### A little extra support

- Keep the architecture diagram and sample payload visible during the walkthrough.
- Trace the message one step at a time and point out the event name in both codebases.
- For students new to streams, describe a stream as a sequence of values arriving over time; `StreamBuilder` responds when one arrives.

### For students who finish early

- Ask how to send an update only to people watching a particular order, rather than using `Clients.All`.
- Ask what the app should do if it reconnects after missing an event.
- Discuss why a real system should save the order change before broadcasting it.

### Things worth clearing up

- **“SignalR replaces the REST API.”** In this demo, REST triggers the operation; SignalR broadcasts the resulting update.
- **“WebSockets will work everywhere.”** SignalR can use another transport when needed, but the network and server still need to be configured correctly.
- **“The order is saved because the message was sent.”** This demo doesn't save anything. A real app should save the change first, then notify clients.
- **“Every client should see every order.”** `Clients.All` keeps the lesson simple. Real apps should limit updates to the right users and orders.

## IX. Assignment / follow-up activity

Modify the demo so that:

1. The client can select an order status from a dropdown instead of cycling through fixed values.
2. Invalid or blank status input is shown clearly without changing the displayed order.
3. The client displays **Reconnecting** when the SignalR connection is interrupted.
4. After reconnecting, the client requests the latest order status from an API endpoint.

Turn in the updated source with a short explanation of how the REST request and SignalR event work together.

## X. Reflection

After class, jot down a few notes:

- Could students explain polling versus a server-pushed update?
- Could they follow `ReceiveOrderUpdate` from the C# code into Flutter?
- Did the demo work reliably on the chosen browser or emulator?
- What needs another look next time: async UI state, CORS, reconnecting, authentication, or saving data?
- Should I adjust the timing or prepare anything differently for the next class?

## Key takeaway

The API handles the request; SignalR lets connected screens know what happened. In Flutter, update the screen when an event arrives, but make sure errors and dropped connections are visible to the user too.
