using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using SignalR.Api.Hubs;
using SignalR.Api.Models;

namespace SignalR.Api.Controllers;

[ApiController]
[Route("api/orders")]
public sealed class OrdersController(IHubContext<NotificationHub> hub) : ControllerBase
{
    [HttpPost("{orderId}/status")]
    [ProducesResponseType(StatusCodes.Status202Accepted)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> UpdateStatus(
        string orderId,
        [FromBody] UpdateOrderStatusRequest request)
    {
        if (string.IsNullOrWhiteSpace(orderId))
        {
            return BadRequest(new { message = "Order ID is required." });
        }

        if (string.IsNullOrWhiteSpace(request.Status))
        {
            return BadRequest(new { message = "Status is required." });
        }

        var update = new OrderStatusUpdate(orderId, request.Status.Trim());
        await hub.Clients.All.SendAsync("ReceiveOrderUpdate", update);

        return Accepted(update);
    }
}

public sealed record UpdateOrderStatusRequest(string Status);
