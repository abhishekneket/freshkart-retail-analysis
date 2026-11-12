# FreshKart: Insights and Recommendations

*Practice project on synthetic data. Figures are for delivered orders, January 2024 to December 2025.*

## Key insights

1. **Deep discounting is erasing profit.** Delivered sales with discounts above 20% generated a combined loss of ₹3.57 lakh (margin −6.8% in the 21–30% band and −27.4% above 30%), while undiscounted sales earned a 25.1% margin.

2. **Furniture is the main source of this leakage.** Furniture accounts for 73% of all sales sold at more than 20% discount. Its discounted sales run at a −21.1% margin versus +16.0% on the rest, pulling the category's overall margin down to 3.9%, the lowest of the five categories (Fashion leads at 39.6%).

3. **Cash on Delivery drives cancellations.** COD orders are cancelled at 17.7%, four times the UPI rate (4.4%), representing ₹3.83 lakh in cancelled order value across the two years.

**Supporting context:** net sales grew 15.8% year on year (₹85.1 lakh in 2024 to ₹98.6 lakh in 2025), with October and November contributing 25% of annual sales. Fashion has the highest return rate at 12.5% (₹2.70 lakh in returned value). 54.9% of customers with a delivered order placed more than one order.

## Recommendations

1. **Cap discounts at 20%, starting with Furniture.** Introduce an approval step for any discount above 20%. Bringing Furniture's heavily discounted sales back to its normal 16% margin would recover roughly ₹5–8 lakh of gross profit over two years (estimate, assuming similar volumes).

2. **Reduce Cash on Delivery cancellations through prepaid nudges.** Offer a small prepaid incentive (such as instant UPI cashback) and add confirmation calls or messages for high-value COD orders. Track the COD cancellation rate monthly against a target of under 10%.

## Next steps (if this were a live engagement)

- Validate the discount finding by store and month before changing policy.
- Investigate Fashion returns by product and size to separate quality issues from sizing issues.
- Automate the pipeline: scheduled export from the database to the Power BI semantic model, with a daily summary to the category head.
