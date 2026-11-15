# Franando Shop API — Bakong KHQR payments

This is your existing **Dart Frog + MongoDB** backend, extended with Bakong KHQR payment generation, server-side payment verification, and an in-app customer notification after a verified payment.

> **Important:** QR generation is not a money transfer. The customer scans the KHQR in Bakong or a supported bank app and approves the transfer. Your server must then confirm the transaction through Bakong Open API. Do not mark an order paid from a frontend callback or from the fact that a QR was scanned.

## 1. Requirements

- Dart SDK compatible with this project's `pubspec.yaml` (Dart 3.3+)
- Dart Frog CLI
- MongoDB
- Python 3.9+
- Python packages in `tools/requirements.txt` for PNG rendering
- A valid Bakong account ID and Bakong Open API token

## 2. Configure secrets

Copy `.env.example` to `.env` and fill in your own values. Never commit `.env` or send it to a public repository.

```env
MONGO_URI=mongodb://localhost:27017/franando_shop
JWT_SECRET=replace_with_a_long_random_secret
BAKONG_ACCOUNT=your_bakong_account_id@bank
BAKONG_MERCHANT_NAME=Franando Shop
BAKONG_MERCHANT_CITY=Phnom Penh
BAKONG_TOKEN=your_private_bakong_open_api_token
BAKONG_API_BASE=https://api-bakong.nbc.gov.kh
```

For SIT/sandbox, use the base URL supplied by Bakong for your SIT account. Keep the token private. If a real token was ever committed, pasted into a sample file, or shared, revoke/renew it in the Bakong Open API portal before production.

The shop currently stores order totals in USD. If you want to let a customer pay those orders in KHR, configure the store's agreed exchange rate:

```env
BAKONG_USD_KHR_RATE=4100
```

The value above is only an example; set the rate your business actually uses. Without this setting, the backend rejects USD-to-KHR conversion instead of guessing a rate. If no conversion is needed, leave it blank and request USD.

## 3. Install and run

```bash
cp .env.example .env
# Edit .env before running

dart pub get
dart run bin/seed.dart
dart_frog dev
```

The API runs at `http://localhost:8080` by default. All payment and notification endpoints below require `Authorization: Bearer <your_login_token>`.

## 4. Payment flow

### Step A — Login and create an order

Use your existing `POST /auth/login`, then create an order using `POST /orders` as usual. The order must have `paymentMethod: "bakong"`.

Example request body (use your actual shipping fields required by your app):

```json
{
  "paymentMethod": "bakong",
  "shippingAddress": {
    "name": "Customer Name",
    "phone": "012345678",
    "address": "Phnom Penh"
  }
}
```

Save the returned order `_id`.

### Step B — Generate a dynamic KHQR

`POST /payments/bakong-qr`

Headers:

```http
Authorization: Bearer YOUR_LOGIN_JWT
Content-Type: application/json
```

Body:

```json
{
  "orderId": "YOUR_ORDER_OBJECT_ID",
  "currency": "USD"
}
```

Successful response (example shape):

```json
{
  "success": true,
  "data": {
    "paymentId": "...",
    "qr": "000201...",
    "md5": "32_character_md5_hash",
    "amount": 25.5,
    "currency": "USD",
    "expiresAt": "2026-01-01T00:10:00.000Z",
    "expiresInSeconds": 600,
    "status": "pending",
    "checkPaymentUrl": "/payments/bakong-qr?md5=..."
  }
}
```

The `qr` value is the KHQR payload string. Render it as a QR image using the Python helper below, or render it in your frontend with a QR-code library. The QR lifetime is 10 minutes; after expiry, create a fresh QR.

### Step C — Create the PNG QR image with Python

Install the helper dependency:

```bash
python -m pip install -r tools/requirements.txt
```

Save the backend response as `payment-response.json`, then run:

```bash
python tools/render_khqr.py --payload-file payment-response.json --output public/khqr-payment.png
```

Or pass the exact `qr` string directly:

```bash
python tools/render_khqr.py --payload '000201...' --output khqr-payment.png
```

This script only renders the KHQR string returned by the Dart backend. It does not invent a KHQR payload, initiate a transfer, or verify a payment.

### Step D — Customer scans and pays

The customer scans the displayed QR with Bakong or a supported banking app and confirms the transfer in that app.

### Step E — Poll Bakong from your backend

After the customer says they have paid, your frontend should poll your authenticated backend endpoint every 3–5 seconds until it returns `paid`, `expired`, or the UI's timeout is reached:

`GET /payments/bakong-qr?md5=THE_MD5_FROM_STEP_B`

Possible responses:

```json
{ "success": true, "data": { "status": "pending" } }
{ "success": true, "data": { "status": "paid", "transactionHash": "..." } }
{ "success": true, "data": { "status": "expired" } }
```

The backend calls Bakong's `POST /v1/check_transaction_by_md5` using the private API token. It checks the returned receiver account, currency, and amount against the saved payment before updating anything. A mismatch is rejected and is not treated as paid.

### Step F — Customer notification

After the order changes from unpaid to paid, the backend creates one in-app notification in MongoDB:

`GET /notifications`

The notification contains `type: "payment_success"`, the order ID, payment ID, transaction hash, title, and body. Your frontend can poll `/notifications` or refresh it after the payment endpoint returns `paid`, then display a toast/banner. Mark it read with the existing `PUT /notifications` endpoint.

This implementation provides an **in-app notification record**. It does not send SMS, email, Firebase push, or WebSocket messages; those require separate provider configuration.

## 5. Security and production checklist

- Keep `BAKONG_TOKEN` only on the backend in `.env` / a secret manager. Never send it to the browser or mobile app.
- Use HTTPS in production.
- Start with Bakong SIT credentials and a test merchant account; scan and verify a real SIT transaction before switching to production.
- Confirm the exact `toAccountId` value returned by Bakong matches your configured `BAKONG_ACCOUNT` in your environment.
- Verify that the amount and currency in the Bakong response match the saved payment. This code does that before setting `paid`.
- The API token may expire. Renew or replace it through the Bakong Open API portal when required.
- The QR generator dependency `khqr_generator` is a community-maintained Dart package, not an official NBC SDK. NBC's integration documentation recommends its KHQR SDK. Before production, validate QR generation against NBC's current KHQR test vectors / SIT and consider replacing the community generator with the officially supplied SDK if available for your server platform.
- This implementation's `GET /payments/bakong-qr` is a polling endpoint, not a webhook. The frontend must poll it while the QR is active.
- Reconcile payments and orders in monitoring. A customer payment can succeed even if the customer's browser disconnects.

## 6. Existing API routes

The rest of your existing Franando Shop endpoints remain in place. Relevant routes:

| Method | Route | Purpose |
|---|---|---|
| POST | `/auth/login` | Get customer JWT |
| POST | `/orders` | Create order |
| POST | `/payments/bakong-qr` | Generate dynamic KHQR |
| GET | `/payments/bakong-qr?md5=...` | Verify transaction status |
| GET | `/notifications` | Read customer notifications |
| PUT | `/notifications` | Mark notification(s) read |

## 7. Notes about this package

The archive supplied for this work did not include a usable local Dart SDK in the execution environment, so I could not run `dart pub get`, `dart analyze`, or a Bakong SIT transaction here. Run those checks in your development environment before deployment. The code is prepared for the existing Dart Frog/MongoDB structure, but successful live transfers cannot be guaranteed without your Bakong credentials, merchant account configuration, and SIT validation.
