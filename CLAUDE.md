# LocalEase — Project Brief for Claude Code

LocalEase is a mobile platform (Flutter/Dart, iOS + Android) connecting customers with local
independent service providers — home repair, tutoring, cleaning, beauty, and similar — through
search, booking, reviews, and direct in-app communication. It is a two-sided marketplace MVP
built for a single-semester capstone project by a two-person team.

This file is the build brief distilled from the full 95-page project documentation (SRS, design
diagrams, architecture, test plan). Read it fully before writing code — it defines the data
model, the module boundaries, every functional requirement, and the build order. If anything here
conflicts with a specific instruction given in chat, the chat instruction wins; otherwise, build
to this spec rather than inventing scope.

## Stack (decided — do not change without asking)

- **Client:** Flutter (Dart), single codebase for customer, provider, and admin screens.
- **Backend:** Supabase — managed Postgres database, Supabase Auth, Supabase Storage (listing
  images), Realtime (Postgres change subscriptions for live booking/listing updates).
- **Server-side logic:** Supabase Edge Functions (Deno/TypeScript) for anything that isn't a
  direct query or a Row Level Security policy — booking status transitions, admin actions,
  notification dispatch.
- **Push notifications:** Firebase Cloud Messaging (FCM). This is the one piece Supabase doesn't
  provide natively — everything else (data, auth, storage) is Supabase, only push delivery goes
  through FCM.
- **Tooling:** VS Code, GitHub, Figma (design reference), Android Studio / Xcode (emulators and
  device builds).

## Stakeholders & roles

Three roles, all backed by one `auth.users` row + a `profiles` row distinguishing role:

| Role | Description |
|---|---|
| Customer | Searches, books, reviews, and messages providers. |
| Service Provider | Lists services, manages bookings, replies to reviews and messages. |
| System Administrator | Approves listings/providers, moderates content, resolves reports. |

## Data model

Ten core entities. Field names below are the class-diagram source of truth; treat Postgres
column names as the same in snake_case. `auth.users` (Supabase-managed) holds email + password;
everything else lives in `public` tables.

| Entity | Key fields | Notes |
|---|---|---|
| **profiles** (User/Customer/Provider/Admin) | id (= auth.users.id), name, email, role (`customer`\|`provider`\|`admin`), business_name (providers only), created_at | Customer/Provider/Admin are role variants of one table, not separate tables — matches the class diagram's inheritance. |
| **listings** | id, provider_id → profiles, title, description, category, location, price, status (`pending`\|`approved`\|`rejected`), created_at | |
| **listing_images** | id, listing_id → listings, url | One-to-many; or an array column if you'd rather keep it simple for MVP. |
| **bookings** | id, listing_id → listings, customer_id → profiles, date, time_slot, status (`requested`\|`accepted`\|`rejected`\|`completed`\|`cancelled`), created_at | |
| **reviews** | id, booking_id → bookings (unique), customer_id → profiles, rating, comment, provider_reply (nullable), created_at | One review per booking, only after `completed` (DR-05). |
| **messages** | id, sender_id → profiles, recipient_id → profiles, listing_id or booking_id (scopes the conversation per DR-08), content, is_read, created_at | |
| **notifications** | id, user_id → profiles, type, content, is_read, created_at | Dispatched by Edge Functions on booking-status change and new-message events. |
| **reports** | id, reporter_id → profiles, target_type (`listing`\|`review`), target_id, reason, status (`open`\|`resolved`), resolution, created_at | |

**Relationships (from the class diagram, with multiplicity):** Provider creates 0..* Listings (1
provider). Listing is booked as 0..* Bookings (1 listing). Customer requests 0..* Bookings (1
customer). Booking generates 0..1 Review. User submits 0..* Reports (1 user); Admin reviews 0..*
Reports. Admin moderates 0..* Listings. User receives 0..* Notifications. User sends/receives 0..*
Messages.

**Row Level Security is the primary access-control mechanism** — not app-layer checks. Rough
policy shape: customers/providers can only read/write rows where they're the owner
(`customer_id`/`provider_id`/`sender_id` = `auth.uid()`); admins bypass via a `role = 'admin'`
check; approved listings are publicly readable, pending/rejected are not.

## Architecture — 8 subsystems, 28 components

Components are cohesive modules, not one-per-requirement — several closely related requirements
share a component when they'd realistically be one handler (e.g. accept/reject booking is one
Booking Response Handler). Build subsystems roughly in this order; within G2/G3/G4 the components
are listed in their real dependency order (each depends on the one before it existing).

**G1 — User Management** (`C1`→`C2`→`C3`, `C2`→`C4`)
- C1 Registration Handler — FR-01, FR-02 (customer + provider sign-up)
- C2 Authentication Manager — FR-03, FR-04 (login, logout)
- C3 Password Reset Handler — FR-05
- C4 Profile Manager — FR-06

**G2 — Business Listing Management** (`C5`→`C6`→`C7`→`C8`→`C9`)
- C5 Listing Creator — FR-07
- C6 Listing Media & Category Handler — FR-08, FR-09
- C7 Listing Location & Pricing Handler — FR-10, FR-11
- C8 Listing Editor — FR-12
- C9 Listing Deletion Handler — FR-13

**G3 — Search, Browse & Discovery** (`C10`→`C11`→`C12`→`C13`→`C14`)
- C10 Listings Browser & Search Engine — FR-14, FR-15
- C11 Listing Filter Engine — FR-16, FR-17, FR-18
- C12 Sort Manager — FR-19
- C13 Listing Detail Viewer — FR-20
- C14 Provider Profile Viewer — FR-21

**G4 — Booking Management** (`C15`→`C16`→`C17`→`C18`)
- C15 Booking Request Handler — FR-22
- C16 Bookings Viewer — FR-23, FR-24 (customer + provider views)
- C17 Booking Response Handler — FR-25, FR-26 (accept/reject)
- C18 Booking Lifecycle Manager — FR-27, FR-28 (cancel/complete)

**G5 — Reviews & Ratings** (`C19`→`C20`, `C19`→`C21`)
- C19 Review Submission Handler — FR-29
- C20 Review Editor — FR-30, FR-31 (edit/delete)
- C21 Review Reply Handler — FR-32

**G6 — Messaging** (`C22`→`C23`)
- C22 Message Composer — FR-33, FR-35 (send new + reply)
- C23 Inbox Viewer — FR-34

**G7 — Notifications & Alerts** (single component, no internal dependency)
- C24 Notification Dispatcher — FR-36, FR-37

**G8 — Admin & Moderation** (`C25`→`C26`, `C25`→`C27`, `C25`→`C28`)
- C25 Admin Authentication Handler — FR-38
- C26 Listing Moderation Handler — FR-39, FR-40, FR-41
- C27 User Moderation Handler — FR-42, FR-43
- C28 Report Handler — FR-44, FR-45

**Subsystem-level flow:** G1 → G2 → G3 → G4 → {G5, G6, G7}; G8 → G2 (moderates listings) and
G8 → G5 (moderation touches reviews too, via reports).

## Functional requirements (all 45 — build every one, skip none)

Grouped by subsystem; each row is `FR-ID: description — key data/notes`.

**Account (G1)**
- FR-01 Customer Registration — name, email, password
- FR-02 Provider Registration — business name, email, password → account starts `pending` admin approval
- FR-03 User Login — email + password
- FR-04 User Logout
- FR-05 Password Reset — via email link
- FR-06 View & Edit Profile

**Listings (G2)**
- FR-07 Create Service Listing — title, description, category → starts `pending`
- FR-08 Upload Listing Images
- FR-09 Set Listing Category — from a predefined list
- FR-10 Set Listing Location & Service Area
- FR-11 Set Pricing & Availability — price + time slots
- FR-12 Edit Listing — owner only (DR-04)
- FR-13 Delete/Deactivate Listing — blocked while active bookings exist

**Discovery (G3)**
- FR-14 Browse All Listings — approved/active only
- FR-15 Search Listings by Keyword — matches title/description/category
- FR-16 Filter by Category
- FR-17 Filter by Location/distance
- FR-18 Filter by Rating
- FR-19 Sort Listings — rating/price/newest, default newest
- FR-20 View Listing Details Page
- FR-21 View Provider Profile — includes avg rating + active listings

**Booking (G4)**
- FR-22 Create Booking Request — checks slot availability, status starts `requested`
- FR-23 View My Bookings (Customer) — grouped by status
- FR-24 View Incoming Bookings (Provider)
- FR-25 Accept Booking Request → triggers notification
- FR-26 Reject Booking Request — optional reason
- FR-27 Cancel Booking — either party
- FR-28 Mark Booking as Completed — only from `accepted`; unlocks review

**Reviews (G5)**
- FR-29 Submit Review & Rating — only if booking `completed` (DR-05)
- FR-30 Edit Own Review
- FR-31 Delete Own Review
- FR-32 Reply to Review — listing owner only

**Messaging (G6)**
- FR-33 Send In-App Message — scoped to shared booking/inquiry (DR-08)
- FR-34 View Message Inbox — sorted by recent activity
- FR-35 Reply to Messages

**Notifications (G7)**
- FR-36 Receive Booking Notification — on any status change
- FR-37 Receive Message Notification — on new message

**Admin (G8)**
- FR-38 Admin Login
- FR-39 Approve/Reject New Listing
- FR-40 View All Listings (Admin) — any status
- FR-41 Remove Listing (Admin) — moderation, distinct from provider's own delete
- FR-42 View All Users (Admin)
- FR-43 Ban/Suspend User (Admin) — also hides their listings
- FR-44 Report a Listing or Review — any user
- FR-45 Resolve Reports (Admin) — remove content / ban user / dismiss

## Non-functional requirements

| ID | Category | Requirement |
|---|---|---|
| NFR1 | Performance | Listing/search screens load within 3s under normal load. |
| NFR2 | Security | Role-based access control (customer/provider/admin), enforced via Supabase RLS. |
| NFR3 | Scalability | No significant degradation as listings/bookings/users grow. |
| NFR4 | Maintainability | Easy to fix bugs and ship changes — keep the module boundaries above intact. |
| NFR5 | Usability | Simple, intuitive on both Android and iOS, no training needed. |
| NFR6 | Reliability | Booking data must not be lost; system stays available during peak hours. |

## Domain rules (business logic that must be enforced, not just implemented)

- **DR-01** Dual roles: customer vs. provider accounts have different capabilities.
- **DR-02** Every listing has a predefined category.
- **DR-03** Booking status lifecycle: `requested → accepted/rejected → completed/cancelled`.
- **DR-04** Only the owning provider can edit/deactivate/delete their listing.
- **DR-05** A customer can only review a booking after it's `completed`.
- **DR-06** Listings store a location/area for location-based search.
- **DR-07** New provider accounts and new listings require admin approval before appearing publicly.
- **DR-08** In-app messaging is limited to users who share an active/past booking or a listing inquiry.
- **DR-09** Admin can remove listings/reviews and suspend accounts that violate terms.

## Suggested build order

This mirrors both the architecture's dependency chains and the schedule in the source doc
("account management and listing creation first, then search/discovery, booking, reviews and
messaging in later sprints"):

1. **Auth & accounts** (G1) — Supabase Auth wiring, `profiles` table + RLS, registration/login/
   logout/reset/profile screens.
2. **Listings** (G2) — CRUD, image upload to Supabase Storage, category/location/pricing, admin
   approval gate (DR-07).
3. **Discovery** (G3) — browse/search/filter/sort/detail/provider-profile screens, all read-only
   against `listings`.
4. **Booking** (G4) — request → accept/reject → cancel/complete, with the status-transition rules
   in an Edge Function so they can't be bypassed from the client.
5. **Reviews, Messaging, Notifications** (G5/G6/G7) — can be built in parallel, all depend only on
   G4 (a completed booking) or G1 (an authenticated user), not on each other.
6. **Admin & Moderation** (G8) — approval queue, user management, reports; depends on G2 and G5
   already existing.
7. **Testing pass** — see Chapter 6 of the doc for the full test matrix: one test case per FR (45)
   and two per NFR (12), plus black-box/white-box/unit/integration/system/regression/UAT coverage.

## What this brief intentionally leaves open

Screen-by-screen UI layout (Figma is the source of truth, not this file), exact Postgres column
types/indexes, and Edge Function file/folder structure are all implementation decisions — make
them as you build, they don't need to be re-litigated against the doc. The scope above (45 FRs,
9 domain rules, 8 subsystems) is what should not silently shrink.
