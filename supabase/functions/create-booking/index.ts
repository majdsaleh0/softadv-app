import "@supabase/functions-js/edge-runtime.d.ts";
import { adminClient, getAuthedUser, jsonResponse } from "../_shared/supabase.ts";

// FR-22: Create Booking Request. Checks slot availability, status starts 'requested'.
Deno.serve(async (req) => {
  const user = await getAuthedUser(req);
  if (!user) return jsonResponse({ error: "Not authenticated" }, 401);

  const { listing_id, date, time_slot_id } = await req.json();
  if (!listing_id || !date || !time_slot_id) {
    return jsonResponse({ error: "listing_id, date, and time_slot_id are required" }, 400);
  }

  const db = adminClient();

  const { data: profile } = await db.from("profiles").select("role").eq("id", user.id).single();
  if (profile?.role !== "customer") {
    return jsonResponse({ error: "Only customer accounts can request bookings" }, 403);
  }

  const { data: listing } = await db.from("listings").select("id, provider_id, status, is_active").eq("id", listing_id).single();
  if (!listing || listing.status !== "approved" || !listing.is_active) {
    return jsonResponse({ error: "Listing is not available for booking" }, 404);
  }

  const { data: slot } = await db.from("listing_time_slots").select("id, day_of_week").eq("id", time_slot_id).eq("listing_id", listing_id).single();
  if (!slot) {
    return jsonResponse({ error: "Time slot does not belong to this listing" }, 400);
  }

  const requestedDate = new Date(`${date}T00:00:00Z`);
  if (Number.isNaN(requestedDate.getTime()) || requestedDate.getUTCDay() !== slot.day_of_week) {
    return jsonResponse({ error: "date does not fall on the time slot's day of week" }, 400);
  }

  const { data: conflicts } = await db
    .from("bookings")
    .select("id")
    .eq("listing_id", listing_id)
    .eq("time_slot_id", time_slot_id)
    .eq("date", date)
    .in("status", ["requested", "accepted"]);
  if (conflicts && conflicts.length > 0) {
    return jsonResponse({ error: "This time slot is already booked for that date" }, 409);
  }

  const { data: booking, error } = await db
    .from("bookings")
    .insert({ listing_id, customer_id: user.id, provider_id: listing.provider_id, time_slot_id, date, status: "requested" })
    .select()
    .single();
  if (error) return jsonResponse({ error: error.message }, 500);

  return jsonResponse({ booking });
});
