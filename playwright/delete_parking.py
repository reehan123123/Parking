import argparse
import sys

from common import (
    add_common_arguments,
    authenticated_page,
    delete_parking,
    read_credentials,
    require_account_confirmation,
)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Delete one explicitly confirmed marked test record."
    )
    parser.add_argument("--plate", required=True)
    parser.add_argument("--confirm-account", required=True)
    parser.add_argument(
        "--confirm-delete",
        action="store_true",
        help="Confirm deletion of this PWTEST record.",
    )
    add_common_arguments(parser)
    args = parser.parse_args()

    if not args.confirm_delete:
        parser.error("Pass --confirm-delete to authorize the UI deletion.")
    credentials = read_credentials()
    require_account_confirmation(args.confirm_account, credentials.username)
    with authenticated_page(credentials, headed=args.headed) as page:
        delete_parking(page, args.plate.upper())
    print(f"Deleted test parking record: {args.plate.upper()}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"Delete parking failed: {error}", file=sys.stderr)
        raise SystemExit(1) from error
