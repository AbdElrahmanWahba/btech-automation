*** Settings ***
# ---------------------------------------------------------------------------
# Page Object Model — RESOURCE FILE
# ---------------------------------------------------------------------------
# This file is the "Page Object" layer of the suite. It holds:
#   1. All LOCATORS (as variables), so selectors live in exactly one place.
#   2. All KEYWORDS (the reusable actions), so the .robot test stays a clean,
#      readable business scenario with no raw selectors in it.
# If B.tech changes its markup, we only touch this file — never the test.
#
# Author: Abdelrahman Wahba
# ---------------------------------------------------------------------------

Library     Browser
Library     Collections


*** Variables ***
# --- Configuration -----------------------------------------------------------
${BASE_URL}                 https://btech.com/en
${SEARCH_TERM}              iphone17
${BROWSER}                  chromium
# HEADLESS is passed from the command line (-v HEADLESS:False to watch it run).
# Defaults to True so the suite is CI-friendly out of the box.
${HEADLESS}                 True
# Generous default timeout: the real site is content-heavy and can be slow.
${TIMEOUT}                  45s
# Pause after every step, so the flow is easy to watch during a demo.
# Set it to 0s for fast/CI runs, e.g.  -v STEP_PAUSE:0s
${STEP_PAUSE}               3s
# Optional video recording of the run (opt-in, off by default so CI stays fast).
# Enable with:  -v RECORD:True   -> a .webm is saved under results/video/
# NOTE: forward slashes on purpose — the path is embedded in a dict literal, and
# Windows backslashes would be read as escape sequences there.
${RECORD}                   ${False}
${VIDEO_DIR}                results/video

# --- Locators ----------------------------------------------------------------
# We prefer stable, semantic attributes that the B.tech developers put there on
# purpose (data-testid, aria-label) over brittle CSS/XPath paths. These survive
# style/layout changes and read almost like documentation.

# The search box exists twice in the DOM (desktop + mobile). ">> visible=true"
# tells Playwright to act on whichever copy is actually shown for the viewport.
${SEARCH_INPUT}             [data-testid="search-input"] >> visible=true

# Every product tile on the results grid carries data-testid="product-card".
${PRODUCT_CARD}             [data-testid="product-card"]
# "The first search result" = the first product card in the grid.
${FIRST_CARD}               ${PRODUCT_CARD} >> nth=0
# The product thumbnail wrapper, and the <img> inside the FIRST card.
${FIRST_CARD_IMAGE}         ${FIRST_CARD} >> [data-testid="product-card-thumbnail"] img
# Title text of the first card (used only for a friendly log message).
${FIRST_CARD_TITLE}         ${FIRST_CARD} >> [data-testid="product-card-title"]
# The orange "+" on a card. B.tech implements "add to cart" as a quantity
# stepper: the first click on "Increase quantity" moves 0 -> 1, i.e. adds it.
${FIRST_CARD_ADD}           ${FIRST_CARD} >> button[aria-label="Increase quantity"]
# After a successful add, the same card reveals a "Decrease quantity" button
# (the "- 1 +" stepper). Its appearance is our definitive proof the add worked.
${FIRST_CARD_DECREASE}      ${FIRST_CARD} >> button[aria-label="Decrease quantity"]

# Header cart icon, and the slide-over cart drawer that opens when it's clicked.
${CART_TRIGGER}             [data-testid="cart-trigger"]
${CART_DRAWER}              [data-testid="cart-drawer"]
${CART_DRAWER_ITEM}         [data-testid="cart-drawer-item"]
# The numeric badge (a <span>) on the header cart icon. Unlike the on-card
# stepper (which updates optimistically), this badge reflects the REAL cart
# state, so it only shows a count once the backend has registered the item.
${CART_BADGE}               ${CART_TRIGGER} >> css=span


*** Keywords ***
Open B.tech Website
    [Documentation]    Launches the browser and opens the B.tech home page.
    ...                Headless mode is controlled by the ${HEADLESS} variable.
    New Browser    ${BROWSER}    headless=${HEADLESS}
    # A realistic desktop viewport so the desktop layout (and its locators) load.
    # When RECORD is enabled, Playwright records a .webm of the whole session;
    # otherwise we open a plain context (no recording overhead).
    IF    ${RECORD}
        New Context
        ...    viewport={'width': 1366, 'height': 900}
        ...    recordVideo={'dir': '${VIDEO_DIR}', 'size': {'width': 1366, 'height': 900}}
    ELSE
        New Context    viewport={'width': 1366, 'height': 900}
    END
    # Apply our default wait to every action BEFORE we navigate.
    Set Browser Timeout    ${TIMEOUT}
    # Open a blank page first, then navigate waiting only for the DOM to be
    # ready. B.tech is media-heavy, so waiting for the full "load" event (all
    # images/ads) is slow and flaky; "domcontentloaded" is enough for us to act.
    New Page
    Go To    ${BASE_URL}    wait_until=domcontentloaded
    # The landing page can occasionally show a cookie/consent popup — dismiss it
    # if present so it can't sit on top of the search box.
    Dismiss Cookie Banner If Present
    # Sanity check that we really are on the search-capable page.
    Wait For Elements State    ${SEARCH_INPUT}    visible
    Sleep    ${STEP_PAUSE}    reason=Pause so the step is easy to watch.

Dismiss Cookie Banner If Present
    [Documentation]    Best-effort close of a cookie / consent banner.
    ...                Never fails the test if no banner is shown — B.tech does
    ...                not always render one, so this is purely defensive.
    ${count}=    Get Element Count
    ...    text="Accept" >> visible=true
    IF    ${count} > 0
        Run Keyword And Ignore Error    Click    text="Accept" >> visible=true
    END

Search For Product
    [Documentation]    Types the search term into the search box and lands on the
    ...                search RESULTS page (/en/s?q=<term>), then waits for the
    ...                product grid to render.
    ...
    ...                Site quirk: B.tech's search box is SPA-driven and does not
    ...                navigate on Enter (verified — pressing Enter leaves you on
    ...                the current page), and its autocomplete only offers
    ...                suggestion clicks that change the query text. So we type
    ...                the term (real interaction), attempt Enter, and if the app
    ...                did not route, we submit via the site's own canonical
    ...                results URL. Either way we assert we reached the results
    ...                page for the exact term we searched.
    [Arguments]    ${term}=${SEARCH_TERM}
    Wait For Elements State    ${SEARCH_INPUT}    visible
    # Fill the search field (clears any existing text first).
    Fill Text    ${SEARCH_INPUT}    ${term}
    # Attempt the natural submit: press Enter directly on the search field.
    Press Keys    ${SEARCH_INPUT}    Enter
    # Did the SPA route to the results page on its own? Give it a short window.
    ${on_results}=    Run Keyword And Return Status
    ...    Wait For Condition    Url    contains    /s?q=    timeout=5s
    # Fallback: submit deterministically via the site's canonical results URL.
    IF    not ${on_results}
        Go To    ${BASE_URL}/s?q=${term}    wait_until=domcontentloaded
    END
    # CRITICAL: prove we are on the search RESULTS page (/en/s?q=...). The home
    # page also contains product cards, so without this the test could silently
    # pass against the wrong page.
    Wait For Condition    Url    contains    /s?q=    timeout=${TIMEOUT}
    # Now wait for the results grid to render.
    Wait For Elements State    ${FIRST_CARD}    visible    timeout=${TIMEOUT}
    Sleep    ${STEP_PAUSE}    reason=Pause so the step is easy to watch.

Assert First Result Has An Image
    [Documentation]    Selects the first search result and proves it renders a
    ...                REAL image — an <img> whose src is a genuine, non-empty
    ...                URL (not empty and not a data:/placeholder), AND that the
    ...                browser actually decoded pixels for it (naturalWidth > 0).
    Wait For Elements State    ${FIRST_CARD_IMAGE}    visible
    # Friendly log line so the report shows WHICH product we validated.
    ${title}=    Get Text    ${FIRST_CARD_TITLE}
    Log    First result: ${title}

    # 1) The src attribute must be a real http(s) URL, not empty/placeholder.
    ${src}=    Get Attribute    ${FIRST_CARD_IMAGE}    src
    Should Not Be Empty    ${src}    The first product image has an empty src.
    Should Match Regexp    ${src}    ^https?://
    ...    msg=Image src is not a real URL (looks like a placeholder): ${src}
    Should Not Contain    ${src}    placeholder
    ...    msg=Image src points at a placeholder, not a real product photo.
    Log    Validated image src: ${src}

    # 2) The image must have actually LOADED. naturalWidth is 0 for broken or
    #    not-yet-decoded images, so > 0 proves real pixels were rendered.
    ${natural_width}=    Get Property    ${FIRST_CARD_IMAGE}    naturalWidth
    Should Be True    ${natural_width} > 0
    ...    msg=Image did not actually render (naturalWidth=${natural_width}).
    Log    Image rendered with naturalWidth=${natural_width}px
    Sleep    ${STEP_PAUSE}    reason=Pause so the step is easy to watch.

Add First Result To Cart
    [Documentation]    Clicks the orange "+" on the first card. On B.tech this
    ...                is an "Increase quantity" control; the first click adds
    ...                the product to the cart (quantity 0 -> 1).
    Wait For Elements State    ${FIRST_CARD_ADD}    visible
    Click    ${FIRST_CARD_ADD}
    # First proof (fast, optimistic): the card switches to the quantity stepper,
    # i.e. its "Decrease quantity" button becomes visible.
    Wait For Elements State    ${FIRST_CARD_DECREASE}    visible    timeout=${TIMEOUT}
    # Second proof (authoritative): the header cart badge shows a real count.
    # The on-card stepper appears instantly (optimistic UI), but the cart is
    # only truly updated once the backend responds — which can lag on slower
    # networks / CI. Waiting for the badge here removes that race before we
    # open the cart, so the drawer is never read while still empty.
    Wait For Elements State    ${CART_BADGE}    visible    timeout=${TIMEOUT}
    Log    First result added to cart (cart badge now shows a count).
    Sleep    ${STEP_PAUSE}    reason=Pause so the step is easy to watch.

Navigate To Cart
    [Documentation]    Opens the cart (a slide-over drawer on B.tech) and
    ...                verifies it is open and contains at least one line item.
    Click    ${CART_TRIGGER}
    Wait For Elements State    ${CART_DRAWER}    visible    timeout=${TIMEOUT}
    # Poll for a stable, non-empty item list. This guards against the brief
    # render flicker that can occur on slower networks, where the drawer paints
    # a moment before its line items are populated.
    Wait Until Keyword Succeeds    5x    1s    Cart Drawer Has At Least One Item

Cart Drawer Has At Least One Item
    [Documentation]    Helper: asserts the open cart drawer holds >= 1 line item.
    ...                Retried by the caller so a transient empty read is tolerated.
    Wait For Elements State    ${CART_DRAWER_ITEM}    visible
    ${items}=    Get Element Count    ${CART_DRAWER_ITEM}
    Should Be True    ${items} > 0    The cart drawer opened but is empty.
    Log    Cart opened with ${items} line item(s).
    Sleep    ${STEP_PAUSE}    reason=Pause so the step is easy to watch.

Close Browser Session
    [Documentation]    Tears down the browser after the test. Used in Teardown.
    Close Browser
