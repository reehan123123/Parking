import argparse
import sys

from common import add_common_arguments, authenticated_page, read_credentials


def main() -> int:
    parser = argparse.ArgumentParser(description="Check tenant account sign-in.")
    add_common_arguments(parser)
    args = parser.parse_args()

    credentials = read_credentials()
    with authenticated_page(credentials, headed=args.headed):
        print("Login succeeded and the parking app shell is available.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"Login check failed: {error}", file=sys.stderr)
        raise SystemExit(1) from error
