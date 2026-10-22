from __future__ import annotations

import getpass
import os
import re
import time
import uuid
from contextlib import contextmanager
from dataclasses import dataclass
from datetime import datetime
from typing import Iterator
from urllib.parse import urlparse

from playwright.sync_api import (
    Locator,
    Page,
    sync_playwright,
)


DEFAULT_BASE_URL = "https://parking-85u.pages.dev/"
TEST_PLATE_PREFIX = "PWTEST"
TEST_CONTACT_NUMBER = "9999999999"
DEFAULT_TIMEOUT_MS = 20_000


@dataclass(frozen=True)
class Credentials:
    base_url: str
    username: str
    password: str


def read_credentials() -> Credentials:
    base_url = os.environ.get("PARKING_BASE_URL", DEFAULT_BASE_URL).strip()
    if not base_url:
        raise ValueError("Set PARKING_BASE_URL to the app URL.")
    if urlparse(base_url).scheme not in {"http", "https"}:
        raise ValueError("PARKING_BASE_URL must use http or https.")

    username = os.environ.get("PARKING_USERNAME", "").strip()
    if not username:
        username = input("Parking test account email: ").strip()
    password = os.environ.get("PARKING_PASSWORD", "")
    if not password:
        password = getpass.getpass("Parking test account password: ")
    if not username or not password:
        raise ValueError("A test account email and password are required.")
    return Credentials(base_url=base_url, username=username, password=password)


@contextmanager
def authenticated_page(
    credentials: Credentials | None = None,
    *,
    headed: bool = False,
) -> Iterator[Page]:
    credentials = credentials or read_credentials()
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(headless=not headed)
        context = browser.new_context(
            viewport={"width": 1440, "height": 1000},
            accept_downloads=False,
        )
        page = context.new_page()
        page.set_default_timeout(DEFAULT_TIMEOUT_MS)
        try:
            sign_in(page, credentials)
            yield page
        finally:
            try:
                sign_out(page, credentials.base_url)
            finally:
                context.close()
                browser.close()


def sign_in(page: Page, credentials: Credentials) -> None:
    page.goto(credentials.base_url, wait_until="domcontentloaded", timeout=45_000)
    enable_flutter_semantics(page)
    page.get_by_role("button", name="Sign in", exact=True).wait_for(
        state="visible", timeout=30_000
    )

    email_field = find_field(page, "Email address", input_type="email")
    if email_field is None:
        if _has_visible_button(page, "New Parking Entry") or (
            "Parking overview" in page.locator("body").inner_text()
        ):
            return
        raise RuntimeError(
            "The sign-in form was not found at PARKING_BASE_URL. "
            "Check the URL and the deployed app."
        )

    password_field = find_field(page, "Password", input_type="password")
    if password_field is None:
        raise RuntimeError("The sign-in password field was not found.")

    _fill_field(page, email_field, credentials.username)
    _fill_field(page, password_field, credentials.password)
    click_button(page, "Sign in")

    deadline = time.monotonic() + 45
    while time.monotonic() < deadline:
        if _has_visible_button(page, "New Parking Entry") or (
            "Parking overview" in page.locator("body").inner_text()
        ):
            return
        page.wait_for_timeout(250)

    raise RuntimeError(
        "Sign-in did not reach the parking app. The account may be invalid, "
        "inactive, awaiting a password change, or missing an active tenant."
    )


def enable_flutter_semantics(page: Page) -> None:
    placeholder = page.locator("flt-semantics-placeholder")
    placeholder.wait_for(state="attached", timeout=30_000)
    placeholder.evaluate("element => element.click()")


def sign_out(page: Page, base_url: str) -> None:
    if find_field(page, "Email address", input_type="email") is not None:
        return
    if not _has_visible_button(page, "Sign out") and not _has_authenticated_shell(
        page
    ):
        return

    page.goto(base_url, wait_until="domcontentloaded", timeout=45_000)
    enable_flutter_semantics(page)

    deadline = time.monotonic() + 45
    while time.monotonic() < deadline:
        if find_field(page, "Email address", input_type="email") is not None:
            return
        if _has_visible_button(page, "Sign out"):
            break
        if _has_authenticated_shell(page):
            click_text(page, "Settings")
            break
        page.wait_for_timeout(250)

    page.get_by_role("button", name="Sign out", exact=True).wait_for(
        state="visible", timeout=15_000
    )
    click_button(page, "Sign out")
    page.get_by_role("button", name="Sign in", exact=True).wait_for(
        state="visible", timeout=30_000
    )


def find_field(
    page: Page,
    label: str,
    *,
    input_type: str | None = None,
) -> Locator | None:
    candidates: list[Locator] = [
        page.get_by_label(label, exact=True),
        page.get_by_role("textbox", name=label, exact=True),
    ]
    if input_type is not None:
        candidates.append(page.locator(f'input[type="{input_type}"]'))

    for locator in candidates:
        count = locator.count()
        for index in range(count):
            candidate = locator.nth(index)
            if candidate.is_visible() and candidate.is_enabled():
                return candidate
    return None


def click_button(page: Page, name: str) -> None:
    locator = page.get_by_role("button", name=name, exact=True)
    if _click_first_visible(locator):
        return
    click_text(page, name)


def click_text(page: Page, text: str) -> None:
    locator = page.get_by_text(text, exact=True)
    if _click_first_visible(locator):
        return
    for role in ("menuitem", "option"):
        control = page.get_by_role(role, name=text, exact=True)
        if _click_first_visible(control):
            return
    button = page.get_by_role(
        "button",
        name=re.compile(rf"^{re.escape(text)}(?:\b|$)"),
    )
    if _click_first_visible(button):
        return
    raise RuntimeError(f"Could not find a visible '{text}' control.")


def _click_first_visible(locator: Locator) -> bool:
    for index in range(locator.count()):
        candidate = locator.nth(index)
        if candidate.is_visible() and candidate.is_enabled():
            candidate.click()
            return True
    return False


def set_checkbox(page: Page, label: str, checked: bool) -> None:
    submit_button = page.get_by_role(
        "button",
        name=re.compile(r"^(?:Save|Update) parking entry$"),
    )
    submit_button.first.wait_for(state="attached", timeout=5_000)
    submit_button.first.scroll_into_view_if_needed()

    for role in ("checkbox", "switch"):
        locator = page.get_by_role(role, name=label, exact=False)
        if locator.count():
            locator.first.wait_for(state="visible", timeout=5_000)
        for index in range(locator.count()):
            candidate = locator.nth(index)
            if candidate.is_visible() and candidate.is_enabled():
                if candidate.is_checked() != checked:
                    candidate.press("Space")
                    deadline = time.monotonic() + 5
                    while time.monotonic() < deadline:
                        if candidate.is_checked() == checked:
                            return
                        page.wait_for_timeout(50)
                    raise RuntimeError(
                        f"The '{label}' checkbox did not change state."
                    )
                return
    if not _click_first_visible(page.get_by_text(label, exact=True)):
        raise RuntimeError(f"Could not find the '{label}' checkbox.")


def create_parking(
    page: Page,
    *,
    plate: str,
    duration: int = 4,
    unit: str = "Hours",
    total_charge: float = 100,
    paid_amount: float = 0,
    fully_paid: bool = False,
    contact_number: str = TEST_CONTACT_NUMBER,
) -> None:
    click_button(page, "New Parking Entry")
    page.get_by_role("textbox", name="Vehicle registration", exact=True).wait_for(
        state="visible", timeout=10_000
    )

    required_fields = (
        ("Vehicle registration", plate),
        ("Contact number", contact_number),
        ("Allowed duration", str(duration)),
        ("Total charge", _format_amount(total_charge)),
    )
    for label, value in required_fields:
        field = find_field(page, label)
        if field is None:
            raise RuntimeError(f"The '{label}' field was not found.")
        _fill_field(page, field, value)

    unit_field = page.get_by_label("Unit", exact=True)
    if unit_field.count() == 0:
        unit_field = page.get_by_role("combobox", name="Unit", exact=True)
    if unit_field.count() == 0:
        unit_field = page.get_by_role(
            "button",
            name=re.compile(r"\b(?:Minutes|Hours|Days|Months)\b"),
        )
    if unit_field.count() == 0:
        unit_field = page.get_by_text("Minutes", exact=True)
    if not _click_first_visible(unit_field):
        raise RuntimeError("The parking duration unit control was not found.")
    page.get_by_role("menuitem", name=unit, exact=True).wait_for(
        state="visible", timeout=5_000
    )
    click_text(page, unit)

    set_checkbox(page, "Fully paid", fully_paid)
    if not fully_paid:
        paid_field = find_field(page, "Amount paid")
        if paid_field is None:
            raise RuntimeError("The 'Amount paid' field was not found.")
        _fill_field(page, paid_field, _format_amount(paid_amount))

    set_checkbox(page, "Continue without photo", True)
    click_button(page, "Save parking entry")

    page.get_by_text(re.compile(re.escape(plate))).first.wait_for(
        state="visible", timeout=30_000
    )


def find_parking_record(page: Page, plate: str) -> None:
    search_field = find_field(page, "Search registration")
    if search_field is None:
        if _has_visible_button(page, "Cancel"):
            click_button(page, "Cancel")

        details_title = page.get_by_text("Parking Session", exact=True)
        if any(
            details_title.nth(index).is_visible()
            for index in range(details_title.count())
        ):
            plate_text = page.get_by_text(plate, exact=True)
            if any(
                plate_text.nth(index).is_visible()
                for index in range(plate_text.count())
            ):
                return

            if _has_visible_button(page, "Back"):
                click_button(page, "Back")

        search_field = find_field(page, "Search registration")
        if search_field is None:
            click_text(page, "History")
            page.get_by_role(
                "textbox",
                name="Search registration",
                exact=True,
            ).wait_for(
                state="visible",
                timeout=10_000,
            )
            search_field = find_field(page, "Search registration")
    if search_field is None:
        raise RuntimeError("The parking history search field was not found.")

    _fill_field(page, search_field, plate)
    session_card = page.get_by_role(
        "group",
        name=re.compile(re.escape(plate)),
    )
    session_card.wait_for(state="visible", timeout=15_000)
    session_card.click()
    page.get_by_text("Parking Session", exact=True).wait_for(
        state="visible", timeout=15_000
    )
    page.get_by_text(plate, exact=True).wait_for(state="visible", timeout=15_000)


def edit_parking(
    page: Page,
    *,
    plate: str,
    total_charge: float,
    paid_amount: float,
    fully_paid: bool = False,
) -> None:
    require_test_plate(plate)
    find_parking_record(page, plate)
    click_button(page, "Edit session")
    page.get_by_role("textbox", name="Total charge", exact=True).wait_for(
        state="visible", timeout=10_000
    )

    total_field = find_field(page, "Total charge")
    if total_field is None:
        raise RuntimeError("The 'Total charge' field was not found.")
    _fill_field(page, total_field, _format_amount(total_charge))

    contact_field = find_field(page, "Contact number")
    if contact_field is None:
        raise RuntimeError("The 'Contact number' field was not found.")
    _fill_field(page, contact_field, TEST_CONTACT_NUMBER)

    set_checkbox(page, "Fully paid", fully_paid)
    if not fully_paid:
        paid_field = find_field(page, "Amount paid")
        if paid_field is None:
            raise RuntimeError("The 'Amount paid' field was not found.")
        _fill_field(page, paid_field, _format_amount(paid_amount))

    click_button(page, "Update parking entry")
    page.get_by_text(plate, exact=True).wait_for(state="visible", timeout=30_000)


def delete_parking(page: Page, plate: str) -> None:
    require_test_plate(plate)
    find_parking_record(page, plate)
    click_button(page, "Delete session")
    page.get_by_text("Delete parking session?", exact=True).wait_for(
        state="visible", timeout=10_000
    )
    click_button(page, "Delete")

    page.get_by_role("textbox", name="Search registration", exact=True).wait_for(
        state="visible", timeout=20_000
    )
    session_card = page.get_by_role(
        "group",
        name=re.compile(re.escape(plate)),
    )
    deadline = time.monotonic() + 20
    while time.monotonic() < deadline:
        if session_card.count() == 0:
            return
        page.wait_for_timeout(250)
    raise RuntimeError(f"The test record '{plate}' remained visible after delete.")


def require_test_plate(plate: str) -> None:
    if not re.fullmatch(r"PWTEST[A-Z0-9]{6,32}", plate.upper()):
        raise ValueError(
            "Only generated test plates beginning with PWTEST can be edited "
            "or deleted by these resources."
        )


def require_account_confirmation(confirmation: str | None, username: str) -> None:
    if (confirmation or "").strip().casefold() != username.strip().casefold():
        raise ValueError(
            "For safety, pass --confirm-account with the exact signed-in email."
        )


def generate_test_plate() -> str:
    return f"{TEST_PLATE_PREFIX}{datetime.now():%y%m%d%H%M%S}{uuid.uuid4().hex[:4].upper()}"


def _fill_field(page: Page, field: Locator, value: str) -> None:
    field.click()
    page.keyboard.press("Control+A")
    page.keyboard.press("Backspace")
    page.keyboard.type(value, delay=30)


def _format_amount(value: float) -> str:
    if value < 0:
        raise ValueError("Amounts cannot be negative.")
    return f"{value:.2f}"


def _has_visible_button(page: Page, name: str) -> bool:
    locator = page.get_by_role("button", name=name, exact=True)
    return any(locator.nth(i).is_visible() for i in range(locator.count()))


def _has_authenticated_shell(page: Page) -> bool:
    if _has_visible_button(page, "New Parking Entry"):
        return True
    if "Parking overview" in page.locator("body").inner_text():
        return True
    navigation = page.get_by_role(
        "button",
        name=re.compile(r"^(Dashboard|History|Settings) Tab"),
    )
    return any(navigation.nth(i).is_visible() for i in range(navigation.count()))


def add_common_arguments(parser) -> None:
    parser.add_argument(
        "--headed",
        action="store_true",
        help="Show Chromium instead of running headless.",
    )
