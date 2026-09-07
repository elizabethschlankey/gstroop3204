# PayHubble

A simple way for a troop to share its payment options.

## Netlify deployment

This is a static site. Netlify can publish the repository with no build command and no publish directory; `index.html` forwards the root URL to `payhub.html` while preserving shared profile data in the URL hash.

## Accounts (Supabase)

PayHubble uses [Supabase](https://supabase.com) for real username + password sign-in, so a saved wallet follows you to any device. One-time setup for whoever owns this deployment:

1. Create a free project at [supabase.com](https://supabase.com).
2. In **Authentication → Providers → Email**, turn **off** "Confirm email" (PayHubble signs people in immediately after they create an account; password-reset emails still work fine with this off).
3. Open the **SQL Editor**, paste in [`supabase-schema.sql`](supabase-schema.sql), and run it. This creates the `profiles` and `hubs` tables and locks them down with Row Level Security so each account can only ever see its own data.
4. Under **Project Settings → API**, copy the **Project URL** and the **anon public** key.
5. Paste those two values into `payhub.html`, near the top of the second `<script>` block:
   ```js
   var SUPABASE_URL = 'https://YOUR-PROJECT.supabase.co';
   var SUPABASE_ANON_KEY = 'YOUR-ANON-PUBLIC-KEY';
   ```
   The anon key is meant to be public in client-side code like this — it can't do anything the Row Level Security policies in `supabase-schema.sql` don't allow.
6. Deploy. Anyone can now create their own account and their wallet, buyer page and settings sync to whatever device they sign in on.

People sign in with a username (not their email); the email they give at sign-up is only used for password recovery.

A buyer who opens a shared payment link never needs an account — that page still works entirely offline, decoded straight from the link.
