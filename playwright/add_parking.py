import argparse
import sys

from common import (
    add_common_arguments,
    authenticated_page,
    create_parking,
    generate_test_plate,
    read_credentials,
    require_account_confirmation,
)


def main() -> int:
    parser = argparse.ArgumentParser(description="Add one marked parking record.")
    parser.add_argument("--plate", default=None)
    parser.add_argument("--duration", type=int, default=4)
    parser.add_argument(
        "--unit",
        choices=("Minutes", "Hours", "Days", "Months"),
        default="Hours",
    )
    parser.add_argument("--total-charge", type=float, default=100)
    parser.add_argument("--paid-amount", type=float, default=0)
    parser.add_argument("--fully-paid", action="store_true")
    parser.add_argument("--confirm-account", required=True)
    add_common_arguments(parser)
    args = parser.parse_args()

    credentials = read_credentials()
    require_account_confirmation(args.confirm_account, credentials.username)
    plate = (args.plate or generate_test_plate()).upper()

    with authenticated_page(credentials, headed=args.headed) as page:
        create_parking(
            page,
            plate=plate,
            duration=args.duration,
            unit=args.unit,
            total_charge=args.total_charge,
            paid_amount=args.paid_amount,
            fully_paid=args.fully_paid,
        )
    print(f"Created test parking record: {plate}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"Add parking failed: {error}", file=sys.stderr)
        raise SystemExit(1) from error
