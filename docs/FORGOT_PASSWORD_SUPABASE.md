# Forgot Password – What to Do in Supabase

This app implements forgot-password using Supabase Auth. Configure the following in the **Supabase Dashboard** so the flow works end-to-end.

---

## 1. Redirect URLs (required)

The reset email contains a link. Supabase will only redirect to URLs that are on the allow list.

1. Open **[Authentication → URL Configuration](https://supabase.com/dashboard/project/_/auth/url-configuration)** (or **Project Settings → Auth → URL Configuration**).
2. Under **Redirect URLs**, add your app’s deep link so the reset link can open the app:
   - Add: `sporttrackerfantasy://reset-password`
   - Or, if you use a different URL scheme in Xcode, add that exact URL (e.g. `yourapp://reset-password`).
3. **Site URL** can stay as-is for web; for a mobile-only app you can set it to the same scheme, e.g. `sporttrackerfantasy://`.

Without this, Supabase will reject the `redirectTo` used when requesting the reset and the link in the email may not open your app.

---

## 2. Email template (optional)

1. Go to **Authentication → Email Templates**.
2. Open the **Reset Password** (or **Magic Link** / **Recovery**) template.
3. Ensure the link in the email uses the redirect URL. If you use a custom `redirectTo`, the template should use `{{ .RedirectTo }}` where the confirmation link is (see [Email templates](https://supabase.com/docs/guides/auth/auth-email-templates)).
4. Customize subject/body if you want.

Default template usually works once **Redirect URLs** are set.

---

## 3. SMTP / email sending (production)

- **Default**: Supabase sends auth emails (e.g. reset password) with a built-in sender. It’s rate-limited (e.g. a few emails per hour) and not for production.
- **Production**: Configure your own SMTP in **Project Settings → Auth → SMTP** so password-reset (and other) emails are reliable and not rate-limited.

---

## 4. Summary checklist

| Step | Where | Action |
|------|--------|--------|
| Redirect URL | Auth → URL Configuration | Add `sporttrackerfantasy://reset-password` (or your app’s scheme) |
| Email template | Auth → Email Templates | Optional: use `{{ .RedirectTo }}` if using custom redirect |
| SMTP | Project Settings → Auth | For production: set custom SMTP |

No database migrations or RLS changes are required for forgot-password; it uses Supabase Auth only.

---

## 5. App URL scheme (Xcode)

For the reset link in the email to open your app, the app must declare a URL scheme:

1. In Xcode, select the **Sport_Tracker-Fantasy** target.
2. Open the **Info** tab (or **Signing & Capabilities** then **Info**).
3. Under **URL Types**, click **+** and add:
   - **Identifier**: e.g. `com.Manas.Sport-Tracker-Fantasy`
   - **URL Schemes**: `sporttrackerfantasy` (no `://`; must match the redirect URL scheme)
   - **Role**: Editor (or leave default)

The redirect URL we use in the app is `sporttrackerfantasy://reset-password`. The scheme (`sporttrackerfantasy`) must match the URL scheme you set here.

---

## Not receiving the email?

Work through these in order:

1. **Check the app for an error**  
   After tapping “Send reset link”, if the API call failed you’ll see a red error message. If you see “Check your email” with no error, Supabase accepted the request.

2. **Confirm Redirect URL in Supabase**  
   If `sporttrackerfantasy://reset-password` (or your custom redirect) is **not** in **Authentication → URL Configuration → Redirect URLs**, Supabase may not send the email or may reject the request. Add it and try again.

3. **Check Supabase Auth logs**  
   In the dashboard go to **Authentication → Logs**. Trigger “Forgot password” again and look for a “Recovery requested” or similar log and any error. That shows whether the request reached Supabase and if sending failed.

4. **Check spam / junk**  
   Look in Spam/Junk and “Promotions” (Gmail). Search for “Supabase” or “reset password”.

5. **Default email rate limit**  
   Supabase’s built-in sender is heavily rate-limited (often only a few emails per hour per project). If you’ve already sent signup/reset emails recently, the next one may be delayed or dropped. Wait an hour and try again, or configure **Project Settings → Auth → SMTP** with your own SMTP for reliable delivery.

6. **Use the correct email**  
   Request the reset for the **exact** email the account was created with (same spelling and domain).

7. **Custom SMTP (recommended for real use)**  
   For consistent delivery, set **Project Settings → Auth → SMTP** with your own provider (e.g. Resend, SendGrid, Mailgun, or your domain’s SMTP). The default sender is not intended for production.

---

## Flow recap

1. User taps “Forgot password?” and enters email.
2. App calls `auth.resetPasswordForEmail(email, redirectTo: your-app-url)`.
3. Supabase sends an email with a link to that `redirectTo` URL.
4. User taps the link → OS opens your app via the URL scheme → app receives the URL.
5. App calls `supabase.auth.handle(url)` (e.g. in `onOpenURL`).
6. Supabase validates the token and emits a `PASSWORD_RECOVERY` auth event (and may set a session).
7. App shows “Set new password” and calls `auth.update(user: UserAttributes(password: newPassword))`.
8. User is updated and can sign in with the new password.
