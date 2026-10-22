import argparse
import sys

from playwright.sync_api import Page

from common import (
    add_common_arguments,
    authenticated_page,
    create_parking,
    delete_parking,
    edit_parking,
    generate_test_plate,
    read_credentials,
    require_account_confirmation,
)


def run_crud_smoke(page: Page, plate: str) -> None:
    print(f"CRUD smoke temporary record: {plate}", flush=True)
    create_parking(
        page,
        plate=plate,
        duration=2,
        unit="Hours",
        total_charge=100,
        paid_amount=0,
    )
    edit_parking(
        page,
        plate=plate,
        total_charge=150,
        paid_amount=50,
    )
    delete_parking(page, plate)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Add, edit, and delete one temporary marked record."
    )
    parser.add_argument("--confirm-account", required=True)
    add_common_arguments(parser)
    args = parser.parse_args()

    credentials = read_credentials()
    require_account_confirmation(args.confirm_account, credentials.username)
    plate = generate_test_plate()

    with authenticated_page(credentials, headed=args.headed) as page:
        run_crud_smoke(page, plate)

    print(f"CRUD smoke test passed for temporary record {plate}; it was deleted.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"CRUD smoke test failed: {error}", file=sys.stderr)
        raise SystemExit(1) from error
