import "@supabase/functions-js/edge-runtime.d.ts";
import { adminClient, getAuthedUser, jsonResponse } from "../_shared/supabase.ts";

// FR-25/26: Accept/Reject Booking Request. Provider-only, only from 'requested'.
// TODO(G7): dispatch a notification to the customer on accept/reject.
Deno.serve(async (req) => {
  const user = await getAuthedUser(req);
  if (!user) return jsonResponse({ error: "Not authenticated" }, 401);

  const { booking_id, action, reason } = await req.json();
  if (!booking_id || !["accept", "reject"].includes(action)) {
    return jsonResponse({ error: "booking_id and action ('accept' | 'reject') are required" }, 400);
  }

  const db = adminClient();

  const { data: booking } = await db.from("bookings").select("id, provider_id, status").eq("id", booking_id).single();
  if (!booking) return jsonResponse({ error: "Booking not found" }, 404);
  if (booking.provider_id !== user.id) return jsonResponse({ error: "Only the listing's provider can respond to this booking" }, 403);
  if (booking.status !== "requested") return jsonResponse({ error: `Cannot respond to a booking in status '${booking.status}'` }, 409);

  const updates = action === "accept" ? { status: "accepted" } : { status: "rejected", reject_reason: reason ?? null };

  const { data: updated, error } = await db.from("bookings").update(updates).eq("id", booking_id).select().single();
  if (error) return jsonResponse({ error: error.message }, 500);

  return jsonResponse({ booking: updated });
});
