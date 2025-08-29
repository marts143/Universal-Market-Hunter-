# Universal Market Hunter EA

[span_0](start_span)[span_1](start_span)A highly adaptive, multi-market Expert Advisor (EA) for MetaTrader 5, engineered to trade different asset classes with unique, pre-configured "personalities"[span_0](end_span)[span_1](end_span).

## Key Features

- **[span_2](start_span)Multi-Market Personalities:** Comes with built-in trading modes specifically tuned for Forex, Metals (XAUUSD), and Crypto (BTCUSD)[span_2](end_span). [span_3](start_span)[span_4](start_span)The EA automatically adjusts its risk parameters to match the unique volatility of each market[span_3](end_span)[span_4](end_span).
- **[span_5](start_span)Dual Strategy Engine:** The user can select between two distinct trading strategies[span_5](end_span):
    1.  **[span_6](start_span)Bollinger Band Breakout:** A volatility-based strategy to capture strong breakout moves[span_6](end_span).
    2.  **[span_7](start_span)[span_8](start_span)Engulfing Price Action:** A price action-based strategy that uses volume confirmation to identify high-probability reversal patterns[span_7](end_span)[span_8](end_span).
- **Fully Dynamic Risk Management:** All trade management is based on the Average True Range (ATR) indicator, making it highly adaptive to changing market conditions. This includes:
    - [span_9](start_span)ATR-based Stop Loss and Take Profit levels[span_9](end_span).
    - [span_10](start_span)An ATR-based breakeven function to protect profits[span_10](end_span).
    - [span_11](start_span)An ATR-based trailing stop to lock in gains as a trade moves in your favor[span_11](end_span).
- **[span_12](start_span)[span_13](start_span)[span_14](start_span)[span_15](start_span)Robust Safety Features:** Includes built-in protection like a list of allowed symbols to trade and an advanced spread filter to avoid trading during unfavorable conditions[span_12](end_span)[span_13](end_span)[span_14](end_span)[span_15](end_span).

## Technologies Used

- **Language:** MQL5
- **Platform:** MetaTrader 5

## How to Use

1.  Attach the EA to a chart in MetaTrader 5.
2.  [span_16](start_span)In the Inputs tab, select the `Market_Mode` that matches your asset (e.g., `MODE_METALS_TREND` for XAUUSD)[span_16](end_span).
3.  [span_17](start_span)Choose your preferred `Strategy_Engine` (e.g., `STRATEGY_BB_BREAKOUT`)[span_17](end_span).
4.  [span_18](start_span)Set your `Risk_Percent_Per_Trade` to manage your risk automatically[span_18](end_span).
