# KindleDrop

A native macOS app for sending PDFs and documents to your Amazon Kindle.

## How it works

KindleDrop sends documents to your Kindle via email. Every Kindle has a unique `@kindle.com` email address — when you email a PDF there, Amazon automatically converts and delivers it to your device.

## Setup

### 1️⃣ Find your Kindle email address

1. Go to [Amazon → Manage Your Content and Devices](https://www.amazon.com/hz/mycd/myu)
2. Click the **Devices** tab
3. Find your Kindle device and note its email (ends in `@kindle.com`)

### 2️⃣ Add your sender email to Amazon's approved list

1. In the same **Devices** page, scroll to **Personal Document Settings**
2. Under **Approved Personal Document Email List**, add the email address you'll send from

### 3️⃣ Configure SMS / App Password

For Gmail: you need an [App Password](https://support.google.com/accounts/answer/185833) (not your regular password).
For other providers: use your regular SMTP credentials.

### 4️⃣ Launch KindleDrop and configure

Open the app → **Settings** → enter your SMTP settings and Kindle email.

## Features

- **Drag & drop** PDF files onto the app window
- **File picker** — click "Browse Files…" to select documents
- **Supports** PDF, EPUB, DOCX, TXT, HTML, images (Amazon supported types)
- **Secure** — passwords stored in macOS Keychain
- **Send history** — track what you've sent and when
- **Connection test** — verify SMTP settings before sending
- **Quick link** — opens Amazon Send to Kindle page in your browser

## Build from source

```bash
cd ~/Projects/KindleDrop
./build.sh
# Opens KindleDrop.app in Finder
open KindleDrop.app
```

## Requirements

- macOS 14 (Sonoma) or later
- An Amazon account with a Kindle device or app
- SMTP credentials for your email provider
