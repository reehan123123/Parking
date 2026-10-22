import argparse
import sys

from common import (
    add_common_arguments,
    authenticated_page,
    edit_parking,
    read_credentials,
    require_account_confirmation,
)


def main() -> int:
    parser = argparse.ArgumentParser(description="Edit one marked parking record.")
    parser.add_argument("--plate", required=True)
    parser.add_argument("--total-charge", type=float, required=True)
    parser.add_argument("--paid-amount", type=float, default=0)
    parser.add_argument("--fully-paid", action="store_true")
    parser.add_argument("--confirm-account", required=True)
    add_common_arguments(parser)
    args = parser.parse_args()

    credentials = read_credentials()
    require_account_confirmation(args.confirm_account, credentials.username)
    with authenticated_page(credentials, headed=args.headed) as page:
        edit_parking(
            page,
            plate=args.plate.upper(),
            total_charge=args.total_charge,
            paid_amount=args.paid_amount,
            fully_paid=args.fully_paid,
        )
    print(f"Edited test parking record: {args.plate.upper()}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"Edit parking failed: {error}", file=sys.stderr)
        raise SystemExit(1) from error
