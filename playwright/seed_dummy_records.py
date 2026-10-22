import argparse
import sys
from datetime import datetime
import uuid

from common import (
    TEST_CONTACT_NUMBER,
    TEST_PLATE_PREFIX,
    add_common_arguments,
    authenticated_page,
    create_parking,
    read_credentials,
    require_account_confirmation,
)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Create a persistent batch of marked parking test records."
    )
    parser.add_argument("--count", type=int, default=20)
    parser.add_argument("--confirm-account", required=True)
    parser.add_argument(
        "--batch-id",
        default=f"{datetime.now():%y%m%d%H%M}{uuid.uuid4().hex[:2].upper()}",
        help="Optional unique suffix to identify this batch.",
    )
    add_common_arguments(parser)
    args = parser.parse_args()

    if not 1 <= args.count <= 50:
        parser.error("--count must be between 1 and 50.")
    batch_id = args.batch_id.upper()
    if not batch_id.isalnum() or not 4 <= len(batch_id) <= 16:
        parser.error("--batch-id must contain 4-16 letters or digits.")

    credentials = read_credentials()
    require_account_confirmation(args.confirm_account, credentials.username)
    created: list[str] = []

    with authenticated_page(credentials, headed=args.headed) as page:
        for index in range(1, args.count + 1):
            plate = f"{TEST_PLATE_PREFIX}{batch_id}{index:02d}"
            total_charge = float(50 + ((index - 1) % 8) * 25)
            payment_type = (index - 1) % 3
            fully_paid = payment_type == 0
            paid_amount = (
                total_charge
                if fully_paid
                else total_charge / 2
                if payment_type == 1
                else 0
            )
            duration = 1 + (index % 6)
            unit = "Days" if index % 5 == 0 else "Hours"
            create_parking(
                page,
                plate=plate,
                duration=duration,
                unit=unit,
                total_charge=total_charge,
                paid_amount=paid_amount,
                fully_paid=fully_paid,
                contact_number=TEST_CONTACT_NUMBER,
            )
            created.append(plate)
            status = (
                "paid"
                if fully_paid
                else "partially paid"
                if paid_amount > 0
                else "unpaid"
            )
            print(f"[{index}/{args.count}] Created {plate} ({status}).")

    print(
        f"Created {len(created)} persistent test records. "
        f"Batch id: {batch_id}. Plates: {', '.join(created)}"
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"Seed run stopped: {error}", file=sys.stderr)
        raise SystemExit(1) from error
