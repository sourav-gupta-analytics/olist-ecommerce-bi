# Project 03 SQL walkthrough

Project folder mein ye command run karo. Isse synthetic reports locally banengi aur real dataset ke bina query flow samajh aa jayega.

```powershell
python -B run.py --fixture --out build/fixture
```

## Grain aur joins

**Grain** ka matlab hai ek row kya represent karti hai. Orders mein ek row ek order hai. Order items mein ek row ek item line hai. Payments mein ek row ek payment entry hai. Agar ek order ki 2 item lines aur 3 payment entries hain, toh dono detail tables direct join karne par 6 rows banengi. Agar items R$60 aur R$40 ke hain, toh naive join merchandise sales R$300 dikha dega. Actual item total R$100 hai.

Is project mein pehle items aur payments ko alag-alag `GROUP BY order_id` se one-row-per-order totals mein convert karte hain. Phir `LEFT JOIN` use karke har source order ko model mein retain karte hain, including orders jinke items ya payments missing hain.

**Interview line** — “I defined order grain and aggregated both one-to-many sources before joining. That prevented fanout and preserved orders with missing detail for reconciliation.”

## KPIs aur window functions

- **Merchandise sales** delivered orders ke item prices ka total hai. Freight aur recorded payments separate totals hain. Payment reconciliation mein item price plus freight ko recorded payments se compare karte hain.
- **AOV** ka denominator delivered orders with items hai. Agar merchandise sales R$300 hain aur 3 delivered orders mein se 2 ke items recorded hain, toh observed AOV R$150 hai. Eligible order count saath mein dekho, taaki coverage clear rahe.
- **Month-over-month growth** mein previous month nikalne ke liye `LAG()` use hota hai. Pehle calendar month rows banate hain, taaki missing month skip na ho. Previous base zero ho ya incomplete period comparison ho, toh percentage ko unavailable treat karte hain.
- **CTE** ek named intermediate query hai. Monthly analysis ko calendar, monthly totals, aur comparison mein padhoge toh har step ka input aur output clear dikhega. `CASE WHEN` business rules lagata hai, jaise delivery ko on-time ya late group karna.

## Customers aur retention

RFM mein **recency** analysis cutoff aur customer ki last qualifying purchase ke beech days ka gap hai, **frequency** delivered order count hai, aur **monetary** delivered merchandise spend hai. `customer_unique_id` repeat activity ko group karta hai. Recency aur monetary ke scores mein equal values ko equal rank milta hai. Frequency mein 1 se 5+ orders ko fixed score milta hai, isliye one-time buyers ka score stable rehta hai.

**Cohort** yahan un customers ka group hai jinki first observed delivered purchase same month mein thi. Agar April cohort mein 100 customers the aur June mein unmein se 12 ne delivered purchase ki, toh month 2 retention 12% hai. Unhe May mein order karna zaroori nahi tha. Full calendar month observe hua aur customer activity zero thi, toh cell 0% hoga. Olist report January 2017 se August 2018 ke cohort starts dikhati hai. Earlier purchases first purchase detect karne mein help karti hain. Study window ke baad ke cells report mein omit hote hain.

**90-day repeat rate** ka denominator woh customers hain jinki first delivered purchase ke baad study cutoff tak poore 90 din observe ho sakte hain. Cohort retention specific calendar months ka activity rate hai. 90-day repeat rate ek fixed window mein second delivered purchase ka rate hai. Olist mein September–October 2018 ke tail mein koi delivered purchase observed nahi thi, isliye customer follow-up ke liye August 31 cutoff use hota hai.

## Delivery aur profitability

Calendar dates compare karne se estimated din par aayi delivery on time count hoti hai. State dashboard ka late-rate denominator eligible delivered orders with both actual and estimated dates hai. Rows aur metrics release karne ke liye sample-size floor apply hota hai. Interview mein numerator aur denominator dono bolo.

`09_seller_volume_tiers` sellers ko delivered-order volume ke basis par group karta hai. Ek order mein multiple sellers hon, toh har involved seller ke volume mein order ek baar count hota hai. Merchandise value har seller ki apni lines se calculate hoti hai. Isi liye tier-level seller-order counts ko add karke marketplace order count nikalne se double counting ho sakti hai.

`10_product_volume_tiers` mein pehle har product ki delivered item lines count hoti hain. Phir products ko line-count tiers mein group kiya jata hai. Dataset mein separate quantity field nahi hai, isliye metric ko item-line count bolna precise hai.

Margin sensitivity report modeled contribution dikhati hai. Example ke liye, R$100 merchandise sales par 65% COGS, 3% processing aur 5% fulfillment assume karne se modeled contribution R$27 aata hai. Cost inputs hypothetical hain. Observed profit claim ke liye validated costs, fees, refunds, aur actual settlement data chahiye.

## Practice

1. `01_monthly_kpis` mein ek AOV row ko merchandise sales aur eligible order count se recalculate karo.
2. `05_cohort_retention` ki kisi row mein cohort age, cohort size aur active customers identify karo. Manually percentage nikalo.
3. `08_margin_scenarios` mein COGS assumption 65% se 75% compare karo. Processing aur fulfillment fixed hon toh modeled margin 10 percentage points girti hai.
4. SQL optimize karna ho toh baseline query ka `EXPLAIN QUERY PLAN` dekho. Join key par indexed `SEARCH` aur full `SCAN` identify karo. Full scan aggregate ke liye expected ho sakta hai, isliye change ko runtime aur equal results dono se verify karo.
