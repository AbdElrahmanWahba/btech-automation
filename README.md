# B.tech — Search & Add-to-Cart Automation

[![Robot Framework Tests](https://github.com/AbdElrahmanWahba/btech-automation/actions/workflows/tests.yml/badge.svg)](https://github.com/AbdElrahmanWahba/btech-automation/actions/workflows/tests.yml)

End-to-end UI test that automates the B.tech storefront (https://btech.com/en):

1. Open the B.tech website
2. Search for **iphone17**
3. Select the first search result and **assert it renders a real image**
4. Add that product to the cart
5. Open the cart and confirm the item is there

Built with **Robot Framework** + **Browser Library** (Playwright under the hood),
using the **Page Object Model**: the test reads as a plain business scenario,
while every selector and low-level action lives in the resource file.

**Author:** Abdelrahman Wahba

---

## Demo

The clip below is recorded by the test itself (Browser Library / Playwright video),
showing the full flow running end to end:

![Demo of the B.tech search & add-to-cart test](docs/demo.gif)

> Prefer full quality? Download the original video: [docs/demo.webm](docs/demo.webm).
>
> To regenerate it yourself: `robot -v RECORD:True -v HEADLESS:False tests/btech_purchase_flow.robot`
> (the `.webm` is saved under `results/browser/video/…`).

---

## Project structure

```
btech-automation/
├─ requirements.txt                      # Python dependencies
├─ tests/
│  └─ btech_purchase_flow.robot          # The readable test scenario (WHAT)
├─ resources/
│  └─ btech_keywords.resource            # Page Object: locators + keywords (HOW)
└─ results/                              # Robot log.html / report.html / output.xml
```

---

## Setup (one time)

> Requires **Python 3.11–3.13** and **Node.js** (Browser Library uses Playwright).
> Note: `grpcio` (a dependency) has no wheels for Python 3.14 yet, so use 3.13.

```bash
# 1. Create and activate a virtual environment (Python 3.13)
py -3.13 -m venv .venv
.venv\Scripts\activate            # Windows PowerShell/CMD
# source .venv/bin/activate       # macOS/Linux

# 2. Install Python dependencies
pip install -r requirements.txt

# 3. Download the Playwright browsers (one time, ~a few hundred MB)
rfbrowser init
```

---

## How to run

All commands assume the virtual environment is active and you are in the
`btech-automation/` folder.

### Headless (default — good for CI)

```bash
robot --outputdir results tests/btech_purchase_flow.robot
```

### Headed (watch the browser drive the site)

```bash
robot --outputdir results -v HEADLESS:False tests/btech_purchase_flow.robot
```

If your venv isn't activated, prefix with the interpreter:

```bash
.venv\Scripts\python.exe -m robot --outputdir results tests/btech_purchase_flow.robot
```

### Reports

After a run, open:

- `results/report.html` — high-level pass/fail summary
- `results/log.html` — step-by-step log with screenshots on failure

---

## Locators used (and why)

The site exposes clean, purpose-built attributes, so we prefer those over
brittle CSS/XPath paths:

| Element              | Locator                                             | Why                                              |
|----------------------|-----------------------------------------------------|--------------------------------------------------|
| Search box           | `[data-testid="search-input"] >> visible=true`      | Stable test id; `visible=true` picks the shown copy (desktop vs mobile) |
| First result         | `[data-testid="product-card"] >> nth=0`             | Every tile is tagged `product-card`              |
| Product image        | `... >> [data-testid="product-card-thumbnail"] img` | Scoped to the first card's thumbnail             |
| Add to cart ("+")    | `... >> button[aria-label="Increase quantity"]`     | B.tech adds to cart via a quantity stepper       |
| Cart icon            | `[data-testid="cart-trigger"]`                       | Stable test id in the header                     |
| Cart drawer / item   | `[data-testid="cart-drawer"]` / `...-drawer-item`   | Cart is a slide-over drawer, not a page          |

## Notes on the real site

- **Search submit:** the search field submits on **Enter** and the app routes to
  `/en/s?q=<term>`; the test waits for the product grid to confirm navigation.
- **Add to cart is a stepper:** the orange "+" is an *Increase quantity* control.
  The first click takes the quantity 0 → 1 (adds the item); we then wait for the
  card's *Decrease quantity* button to appear as proof.
- **Cart is a drawer:** clicking the cart icon opens a slide-over panel (the URL
  does not change); we assert the drawer is visible and holds ≥ 1 line item.
- **Cookie banner:** handled defensively — dismissed only if it actually appears.

## Meaningful image assertion

The image check does more than "an `<img>` exists". For the first result it:

1. reads the `src` and asserts it is a real `http(s)` URL, non-empty, and not a
   placeholder; then
2. reads the DOM `naturalWidth` property and asserts it is `> 0`, proving the
   browser actually decoded and rendered pixels (not a broken image).

---

## Design Notes & Assumptions

This section documents the engineering judgement behind the test — deliberately,
because how you *define* "correct" matters as much as the code that checks it.

### What the task asked, and what I implemented

The task said: *"select the first search result and assert it has an image."*
I implemented that literally — the test takes the **first product card** on the
results grid and asserts it renders a real image (a non-empty `http(s)` `src`,
not a placeholder, with `naturalWidth > 0`).

### Assumptions and limitations I identified

- **"First result has an image" does not prove it is the actual iPhone 17.**
  The first card could easily be an **accessory** — a case, screen protector, or
  charger — which also renders a perfectly valid product image. The image
  assertion would still pass, even though the product isn't the phone.

- **Asserting the title contains "iPhone" is not enough either.** Accessories
  carry the model name in their titles too (e.g. *"iPhone 17 Case"* or
  *"iPhone 17 Screen Protector"*), so a substring check on the title would not
  reliably distinguish the phone from its accessories.

- **The deeper root cause is the test data itself.** Depending on *"the first
  search result"* means depending on **search ranking**, which is inherently
  unstable — it shifts with ads, promotions, sponsored placements, and
  algorithm changes. That makes a test built on "first result" **non-deterministic
  by design**, regardless of how solid the assertions around it are.

### More robust approaches (future improvements — intentionally not implemented)

These are noted as options, not built, to keep this implementation faithful to
the task as written:

- **Assert on product category/type rather than the title** — verify the first
  result is actually a *phone* (not an accessory), e.g. via a category badge,
  breadcrumb, or product-type attribute on the card / product page.
- **Don't rely on "first result" at all** — search for a **specific model or
  SKU** that returns a single deterministic product, or drive the test with
  **controlled test data**, so the assertion target is stable across runs.

### Conclusion

A test is only as good as its definition of "correct." Rather than silently
hard-coding an assumption about what the first result *should* be, the right
engineering move is to **surface this ambiguity and align on the intended
success criteria** first. This implementation therefore follows the task exactly
as written, while documenting the trade-off so the intended behaviour can be
confirmed and tightened when needed.
