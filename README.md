# KindleDrop

A lightweight macOS app for sending PDFs and documents to your Amazon Kindle using Amazon's official Send to Kindle web service.

## How it works

KindleDrop loads [Amazon's Send to Kindle page](https://www.amazon.com/gp/sendtokindle) directly in the app window. Sign in once with your Amazon account, then upload files using Amazon's own interface — just like using the website in your browser.

- No SMTP configuration needed
- No email addresses to manage
- No credentials stored in the app
- Uses Amazon's official upload service

## Build from source

```bash
cd ~/Projects/KindleDrop
./build.sh
open KindleDrop.app
```

## Requirements

- macOS 14 (Sonoma) or later
- An Amazon account with a Kindle device or Kindle app
