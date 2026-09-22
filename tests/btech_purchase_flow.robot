*** Settings ***
# ---------------------------------------------------------------------------
# TEST SUITE — B.tech search & add-to-cart flow
# ---------------------------------------------------------------------------
# This file is deliberately kept as a clean, human-readable scenario.
# All selectors and low-level actions live in the Page Object resource file,
# so anyone can read this test top-to-bottom and understand the business flow
# without seeing a single CSS selector.
#
# Author: Abdelrahman Wahba
# ---------------------------------------------------------------------------

Documentation       End-to-end check of the B.tech storefront: search for a
...                 product, verify the first result shows a real image, add
...                 it to the cart, and open the cart.
Resource            ../resources/btech_keywords.resource

# Clean up the browser whether the test passes or fails.
Test Teardown       Close Browser Session


*** Test Cases ***
Search For iPhone 17 And Add First Result To Cart
    [Documentation]    Automates the full happy-path scenario on btech.com.
    [Tags]    smoke    e2e    btech

    # 1. Open the B.tech website.
    Open B.tech Website

    # 2. Search for "iphone17".
    Search For Product    iphone17

    # 3. Select the first search result and assert it has a real image.
    Assert First Result Has An Image

    # 4. Add that first result to the cart.
    Add First Result To Cart

    # 5. Navigate to the cart and confirm the item is there.
    Navigate To Cart
