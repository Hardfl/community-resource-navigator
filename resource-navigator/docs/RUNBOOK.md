# Staff Runbook — Community Resource Navigator

**For:** Caseworkers and program coordinators
**Updated:** December 2024
**Questions?** Ask the person who set this up, or email [your IT contact here]

---

## What is this tool?

The Community Resource Navigator helps you find the right resource for a client fast. Type what a client needs in plain English — the tool will search our database and use AI to explain which options fit best.

You don't need to know anything about databases, code, or AI to use it.

---

## How to open it

1. Find the file called **`index.html`** on your computer or shared drive
2. Double-click it — it will open in your web browser (Chrome or Firefox work best)
3. That's it. No login, no app to install.

---

## How to search

1. Type what your client needs in the search box. Use plain language, like you'd describe it to a colleague:
   - *"family needs emergency shelter tonight"*
   - *"single mom looking for food assistance"*
   - *"client recently released needs housing"*

2. Optionally click a **category chip** (Housing, Food, Health, etc.) to narrow results

3. Click **Search**

4. Read the **Claude's recommendation** box — this is the AI's summary of which resources fit and why

5. Click any resource card to see more detail, including **intake notes** (practical tips before you make a referral)

---

## How to add or update a resource

You don't need to touch any code. All the resource data lives in a spreadsheet.

1. Open the file: `data/resources_raw.csv`
   - On a Mac: right-click → Open With → Numbers or Excel
   - On Windows: double-click to open in Excel

2. Each row is one organization. Fill in all the columns you can:

| Column | What to put | Example |
|---|---|---|
| `org_name` | Full name of the organization | Bridge House Shelter |
| `category` | One of: `housing`, `food`, `health`, `environment`, `humanitarian` | housing |
| `service_description` | What they offer, in a sentence or two | Emergency overnight shelter for women and families |
| `eligibility` | Who can use the service | Women & families only |
| `address` | Street address | 82 Pine Avenue |
| `phone` | Phone number | 555-0188 |
| `hours` | When they're open | Mon-Fri 9am-5pm |
| `capacity` | How many people they can serve | 14 beds |
| `last_verified` | Date you confirmed this info | 2025-01-15 |

3. Save the file

4. Tell the data owner (the person who set this up) — they'll run a short script that loads your changes into the tool

> ⚠️ Don't change the column headers. Don't delete any existing rows unless the organization has permanently closed.

---

## Verifying resources by phone

Resources go out of date fast. Once a week, pick 2–3 organizations from the list and call them to confirm:

- Are they still operating?
- Are the hours correct?
- Is their capacity accurate?
- Any changes to eligibility?

After confirming, update the `last_verified` column in the spreadsheet with today's date. This tells the system the info is fresh.

---

## Reading the gap report

Every month, your data owner will share a **gap report** — a summary of searches that returned zero results. This is valuable data: it shows you where client needs aren't being met.

Example gap report excerpt:
```
TOP UNMET NEEDS (searches with zero matches)
--------------------------------------------
  5x  single man shelter tonight
  4x  mental health bilingual
  3x  utility shutoff help weekend
  2x  pet-friendly emergency housing
```

Bring these to your next team meeting. Each line represents real clients who didn't get a referral. Use this to prioritize outreach to new partner organizations.

---

## What the dashboards show


<img width="1308" height="687" alt="image" src="https://github.com/user-attachments/assets/86d5d6c8-e17d-42bf-a890-913b069dae6a" />



<img width="1072" height="522" alt="image" src="https://github.com/user-attachments/assets/39e8449b-55fb-4c29-bc93-6e040cc4da85" />



**Impact dashboard tab:**
- Total searches this month
- How many searches found a match
- Most common client needs


<img width="1067" height="376" alt="image" src="https://github.com/user-attachments/assets/3147fb20-530d-4d69-8978-1c9746f017ca" />


<img width="1043" height="303" alt="image" src="https://github.com/user-attachments/assets/efdc5006-e1f6-4af4-84fa-1aecf4c1e519" />



**Data & gaps tab:**
- Which fields are missing in your resource data
- Where coverage is lowest (shown in red)
- Specific unmet needs identified by the AI

---

## Frequently asked questions

**Is client information stored anywhere?**
No. The search box does not save client names, case numbers, or personal information. It only logs the search term (like "family needs housing") and whether a match was found. No identifying information is collected.

**Can I trust the AI recommendations?**
Use them as a starting point, not a final answer. Claude reads the resource descriptions and gives you a plain-language summary — but you should always verify eligibility and availability before making a referral. The intake notes on each card will remind you of key things to check.

**What if the AI gives wrong information?**
This can happen if the resource data in the spreadsheet is out of date, or if the AI misreads a description. If you notice an error, flag it to your data owner and update the spreadsheet. The AI is only as good as the data it reads.

**The tool isn't working / I'm getting an error**
Try refreshing the page first. If it still doesn't work, let your data owner know — they may need to check the API key or update the resource data.

---

## Who to contact

| Need | Contact |
|---|---|
| Add or update a resource | Your data owner|
| Technical issue with the tool | Your IT contact |
| Question about a specific resource | Call the organization directly |
| Request a new feature | Your data owner |
