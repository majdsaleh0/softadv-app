import "@supabase/functions-js/edge-runtime.d.ts";
import { adminClient, getAuthedUser, jsonResponse } from "../_shared/supabase.ts";

// FR-27: Cancel Booking (either party, from 'requested' or 'accepted').
// FR-28: Mark Booking as Completed (provider only, only from 'accepted'; unlocks review in G5).
Deno.serve(async (req) => {
  const user = await getAuthedUser(req);
  if (!user) return jsonResponse({ error: "Not authenticated" }, 401);

  const { booking_id, action } = await req.json();
  if (!booking_id || !["cancel", "complete"].includes(action)) {
    return jsonResponse({ error: "booking_id and action ('cancel' | 'complete') are required" }, 400);
  }

  const db = adminClient();

  const { data: booking } = await db.from("bookings").select("id, customer_id, provider_id, status").eq("id", booking_id).single();
  if (!booking) return jsonResponse({ error: "Booking not found" }, 404);

  if (action === "cancel") {
    if (booking.customer_id !== user.id && booking.provider_id !== user.id) {
      return jsonResponse({ error: "Only the customer or provider on this booking can cancel it" }, 403);
    }
    if (!["requested", "accepted"].includes(booking.status)) {
      return jsonResponse({ error: `Cannot cancel a booking in status '${booking.status}'` }, 409);
    }
  } else {
    if (booking.provider_id !== user.id) {
      return jsonResponse({ error: "Only the listing's provider can mark a booking completed" }, 403);
    }
    if (booking.status !== "accepted") {
      return jsonResponse({ error: "Only an accepted booking can be marked completed" }, 409);
    }
  }

  const { data: updated, error } = await db
    .from("bookings")
    .update({ status: action === "cancel" ? "cancelled" : "completed" })
    .eq("id", booking_id)
    .select()
    .single();
  if (error) return jsonResponse({ error: error.message }, 500);

  return jsonResponse({ booking: updated });
});
