#!/usr/bin/env python3
"""Render an already-generated KHQR payload as a PNG image.

This script does NOT create a payment payload or verify payment. Pass the exact
`qr` string returned by POST /payments/bakong-qr.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import qrcode
from qrcode.constants import ERROR_CORRECT_M


def load_payload(args: argparse.Namespace) -> str:
    if args.payload:
        return args.payload.strip()
    if args.payload_file:
        raw = Path(args.payload_file).read_text(encoding="utf-8")
        try:
            parsed = json.loads(raw)
            if isinstance(parsed, dict):
                value = parsed.get("qr") or (parsed.get("data") or {}).get("qr")
                if value:
                    return str(value).strip()
        except json.JSONDecodeError:
            pass
        return raw.strip()
    return sys.stdin.read().strip()


def main() -> int:
    parser = argparse.ArgumentParser(description="Create a PNG image from a Bakong KHQR payload")
    source = parser.add_mutually_exclusive_group()
    source.add_argument("--payload", help="Exact KHQR string returned by your backend")
    source.add_argument("--payload-file", help="Text file or JSON API response containing the qr field")
    parser.add_argument("--output", default="khqr-payment.png", help="Output PNG path (default: khqr-payment.png)")
    parser.add_argument("--box-size", type=int, default=12)
    parser.add_argument("--border", type=int, default=4)
    args = parser.parse_args()

    payload = load_payload(args)
    if not payload:
        parser.error("Provide --payload, --payload-file, or pipe the backend response to stdin.")
    if not payload.startswith("000201") or "6304" not in payload:
        parser.error("Input does not look like an EMV/KHQR payload. Use the exact backend qr value.")

    qr = qrcode.QRCode(
        version=None,
        error_correction=ERROR_CORRECT_M,
        box_size=max(4, args.box_size),
        border=max(4, args.border),
    )
    qr.add_data(payload)
    qr.make(fit=True)
    image = qr.make_image(fill_color="black", back_color="white")
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    image.save(output)
    print(f"KHQR image saved: {output.resolve()}")
    print("Reminder: this image only encodes the supplied payload; payment must be verified by Bakong Open API.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())