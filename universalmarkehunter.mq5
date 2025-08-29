//+------------------------------------------------------------------+
//|                                       UniversalMarketHunter.mq5  |
//| A Multi-Market Adaptive EA by Marts & Dayz                |
//|                         Copyright 2025                           |
//+------------------------------------------------------------------+
#property copyright "Marts & Dayz Collaboration"
#property link      "https://www.mql5.com"
#property version   "2.0"
#property description "The ultimate adaptive EA. Combines multiple strategies and risk"
#property description "profiles to trade Forex, Metals (XAUUSD), and Crypto (BTCUSD)."

#include <Trade\Trade.mqh>
#include <PositionInfo.mqh>

//--- MASTER CONTROL PANEL ---
input group "--- 1. Market Personality ---"
enum ENUM_MARKET_MODE
{
    MODE_FOREX_SCALPING, // For major pairs like GBPUSD, EURUSD. Fast & tight.
    MODE_METALS_TREND,   // For XAUUSD. Catches strong, volatile trends.
    MODE_CRYPTO_VOLATILITY // For BTCUSD. Adapts to extreme volatility.
};
input ENUM_MARKET_MODE Market_Mode = MODE_FOREX_SCALPING;

input group "--- 2. Strategy Engine ---"
enum ENUM_STRATEGY
{
    STRATEGY_BB_BREAKOUT,    // Volatility breakout using Bollinger Bands
    STRATEGY_ENGULFING_PA    // Price Action using Volume-Confirmed Engulfing Candles
};
input ENUM_STRATEGY      Strategy_Engine = STRATEGY_BB_BREAKOUT;

//--- STRATEGY INPUTS (Only relevant inputs for the chosen strategy will be used) ---
input group "--- Bollinger Band Strategy Settings ---"
input int                BB_Period           = 20;
input double             BB_Deviation        = 2.0;

input group "--- Engulfing Pattern Strategy Settings ---"
input int                Volume_MA_Period    = 20;
input double             Volume_Multiplier   = 1.5;

input group "--- Universal Trend Filter ---"
input int                Trend_EMA_Period    = 50;

//--- DYNAMIC RISK & TRADE MANAGEMENT (ATR-BASED) ---
input group "--- 3. Risk & Position Sizing ---"
input double             Risk_Percent_Per_Trade = 1.0;
input long               Magic_Number           = 202601;
input string             Allowed_Symbols        = "XAUUSD,GBPUSD,EURUSD,BTCUSD"; // Safety: comma-separated list
input double             Max_Spread_Percent     = 0.05; // Max spread as % of Ask price (0.05% is robust)

input group "--- 4. Stop Loss & Take Profit (ATR Multipliers) ---"
input double             SL_ATR_Multiplier      = 1.5;  // Adjusted based on Market Mode
input double             TP_ATR_Multiplier      = 2.5;  // Adjusted based on Market Mode
input int                ATR_Period             = 14;

input group "--- 5. Advanced Profit Protection ---"
input bool               Use_Breakeven_Stop     = true;
input double             Breakeven_Trigger_ATR  = 1.0;
input bool               Use_Trailing_Stop      = true;
input double             Trailing_Start_ATR     = 1.2;
input double             Trailing_Distance_ATR  = 1.8;

//--- GLOBAL VARIABLES ---
CTrade        trade;
CPositionInfo position;
int           ema_handle, atr_handle, bb_handle, vol_ma_handle;
static datetime last_bar_time = 0;

//+------------------------------------------------------------------+
//| Expert Initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
{
    trade.SetExpertMagicNumber(Magic_Number);
    trade.SetMarginMode();

    //--- Initialize ALL possible indicator handles ---
    ema_handle = iMA(_Symbol, _Period, Trend_EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
    atr_handle = iATR(_Symbol, _Period, ATR_Period);
    bb_handle  = iBands(_Symbol, _Period, BB_Period, 0, BB_Deviation, PRICE_CLOSE);
    vol_ma_handle = iMA(_Symbol, _Period, Volume_MA_Period, 0, MODE_SMA, VOLUME_TICK);

    if(ema_handle==INVALID_HANDLE || atr_handle==INVALID_HANDLE)
    {
        Print("CRITICAL ERROR: Failed to create core EMA/ATR handles.");
        return(INIT_FAILED);
    }
    
    //--- Log the chosen personality and strategy ---
    Print("Universal Market Hunter Initialized.");
    Print("Market Personality: ", EnumToString(Market_Mode));
    Print("Strategy Engine: ", EnumToString(Strategy_Engine));
    
    //--- Auto-adjust parameters based on Market Personality ---
    // These are SUGGESTED starting points. You can still override them in the inputs.
    switch(Market_Mode)
    {
        case MODE_FOREX_SCALPING:
            // No changes needed, default inputs are tuned for this.
            Print("Forex Scalping profile loaded. Using tight, fast parameters.");
            break;
        case MODE_METALS_TREND:
            // Widen stops for Gold's volatility
            SL_ATR_Multiplier = 2.0;
            TP_ATR_Multiplier = 3.5;
            Print("Metals Trend profile loaded. Using wider ATR settings for XAUUSD.");
            break;
        case MODE_CRYPTO_VOLATILITY:
            // Widen stops even more for Crypto's extreme moves
            SL_ATR_Multiplier = 2.5;
            TP_ATR_Multiplier = 4.0;
            Max_Spread_Percent = 0.1; // Allow slightly wider spreads
            Print("Crypto Volatility profile loaded. Using very wide ATR and volume confirmation.");
            break;
    }
    
    return(INIT_SUCCEEDED);
}


//+------------------------------------------------------------------+
//| Checks for a new trade signal (runs once per bar)                |
//+------------------------------------------------------------------+
void CheckForNewTradeSignal()
{
    datetime current_bar_time = (datetime)SeriesInfoInteger(_Symbol, _Period, SERIES_LASTBAR_DATE);
    if(last_bar_time == current_bar_time) return;
    last_bar_time = current_bar_time;

    // --- Pre-Trade Safety Filters ---
    if (PositionSelect(_Symbol) && PositionGetInteger(POSITION_MAGIC) == Magic_Number) return;
    if (!IsSymbolAllowed(_Symbol)) return;
    if (!IsSpreadOK()) return;

    bool buy_signal = false;
    bool sell_signal = false;

    // --- STRATEGY ROUTER ---
    // The bot decides which logic to use based on your input setting
    switch(Strategy_Engine)
    {
        case STRATEGY_BB_BREAKOUT:
            buy_signal = Check_BB_Breakout_Signal(true);
            sell_signal = Check_BB_Breakout_Signal(false);
            break;
        case STRATEGY_ENGULFING_PA:
            buy_signal = Check_Engulfing_Signal(true);
            sell_signal = Check_Engulfing_Signal(false);
            break;
    }

    // --- EXECUTE TRADE ---
    if(buy_signal || sell_signal)
    {
        ExecuteTrade(buy_signal);
    }
}

//--- STRATEGY 1: Bollinger Band Breakout Logic ---
bool Check_BB_Breakout_Signal(bool for_buy)
{
    double ema_val[1], bb_upper[1], bb_lower[1];
    MqlRates price_data[2];

    if(CopyBuffer(ema_handle, 0, 1, 1, ema_val)<1 ||
       CopyBuffer(bb_handle, 1, 1, 1, bb_upper)<1 ||
       CopyBuffer(bb_handle, 2, 1, 1, bb_lower)<1 ||
       CopyRates(_Symbol, _Period, 1, 2, price_data)<2) return false;

    if(for_buy)
    {
        return price_data[0].close > ema_val[0] && price_data[0].close > bb_upper[0] && price_data[1].close <= bb_upper[0];
    }
    else
    {
        return price_data[0].close < ema_val[0] && price_data[0].close < bb_lower[0] && price_data[1].close >= bb_lower[0];
    }
}

//--- STRATEGY 2: Engulfing Pattern Logic ---
bool Check_Engulfing_Signal(bool for_buy)
{
    double ema_val[1], vol_ma_val[1];
    MqlRates price_data[2];
    long volume_data[2];

    if(CopyBuffer(ema_handle, 0, 1, 1, ema_val)<1 ||
       CopyBuffer(vol_ma_handle, 0, 1, 1, vol_ma_val)<1 ||
       CopyRates(_Symbol, _Period, 1, 2, price_data)<2 ||
       CopyTickVolume(_Symbol, _Period, 1, 2, volume_data)<2) return false;

    bool hasHighVolume = volume_data[0] > (vol_ma_val[0] * Volume_Multiplier);
    if(!hasHighVolume) return false;

    if(for_buy)
    {
        bool isUptrend = price_data[0].close > ema_val[0];
        bool isBullishEngulfing = price_data[0].close > price_data[1].open && price_data[0].open < price_data[1].close && price_data[0].close > price_data[1].high;
        return isUptrend && isBullishEngulfing;
    }
    else
    {
        bool isDowntrend = price_data[0].close < ema_val[0];
        bool isBearishEngulfing = price_data[0].close < price_data[1].open && price_data[0].open > price_data[1].close && price_data[0].close < price_data[1].low;
        return isDowntrend && isBearishEngulfing;
    }
}


//--- UNIVERSAL TRADE EXECUTION ---
void ExecuteTrade(bool is_buy)
{
    double atr_val[1];
    if(CopyBuffer(atr_handle, 0, 0, 1, atr_val)<1) return;
    double atr_in_points = atr_val[0];
    
    double lot_size = CalculateLotSize(atr_in_points * SL_ATR_Multiplier);
    if(lot_size <= 0) return;
    
    double stop_loss_price = 0;
    double take_profit_price = 0;
    
    if(is_buy)
    {
        double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        stop_loss_price = price - (atr_in_points * SL_ATR_Multiplier);
        take_profit_price = price + (atr_in_points * TP_ATR_Multiplier);
        trade.Buy(lot_size, _Symbol, price, stop_loss_price, take_profit_price, "UMH Buy");
    }
    else
    {
        double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        stop_loss_price = price + (atr_in_points * SL_ATR_Multiplier);
        take_profit_price = price - (atr_in_points * TP_ATR_Multiplier);
        trade.Sell(lot_size, _Symbol, price, stop_loss_price, take_profit_price, "UMH Sell");
    }
}

//--- UNIVERSAL HELPER FUNCTIONS & MANAGEMENT (Best of all bots) ---

// From ScalpingEA - Safety feature
bool IsSymbolAllowed(string symbol)
{
    return StringFind(Allowed_Symbols, symbol) != -1;
}

// From CryptoVolatilityHunter - Robust spread check
bool IsSpreadOK()
{
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    if(ask <= 0) return false;
    double spread_percent = ((ask - bid) / ask) * 100.0;
    return (spread_percent <= Max_Spread_Percent);
}

// From MomentumScalperPro - The best trade management logic
void ManageOpenPositions()
{
    if(!position.Select(_Symbol) || position.Magic() != Magic_Number) return;

    double atr_val[1];
    if(CopyBuffer(atr_handle, 0, 0, 1, atr_val)<1) return;
    double current_atr_points = atr_val[0];
    
    double open_price = position.PriceOpen();
    double current_sl = position.StopLoss();
    double current_tp = position.TakeProfit();
    
    if(Use_Breakeven_Stop && current_sl != open_price)
    {
        if(position.PositionType() == POSITION_TYPE_BUY && SymbolInfoDouble(_Symbol, SYMBOL_BID) >= open_price + (current_atr_points * Breakeven_Trigger_ATR))
        {
            trade.PositionModify(_Symbol, open_price, current_tp);
            return;
        }
        else if(position.PositionType() == POSITION_TYPE_SELL && SymbolInfoDouble(_Symbol, SYMBOL_ASK) <= open_price - (current_atr_points * Breakeven_Trigger_ATR))
        {
            trade.PositionModify(_Symbol, open_price, current_tp);
            return;
        }
    }
    
    if(Use_Trailing_Stop)
    {
        double new_sl = 0;
        if(position.PositionType() == POSITION_TYPE_BUY)
        {
            double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            if(current_price > open_price + (current_atr_points * Trailing_Start_ATR))
            {
                new_sl = current_price - (current_atr_points * Trailing_Distance_ATR);
                if(new_sl > current_sl) trade.PositionModify(_Symbol, new_sl, current_tp);
            }
        }
        else if(position.PositionType() == POSITION_TYPE_SELL)
        {
            double current_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            if(current_price < open_price - (current_atr_points * Trailing_Start_ATR))
            {
                new_sl = current_price + (current_atr_points * Trailing_Distance_ATR);
                if(new_sl < current_sl || current_sl == 0) trade.PositionModify(_Symbol, new_sl, current_tp);
            }
        }
    }
}

// The rest of the essential functions (OnDeinit, OnTick, CalculateLotSize) are similar to the professional versions above and are included here for completeness.

void OnDeinit(const int reason)
{
    IndicatorRelease(ema_handle);
    IndicatorRelease(atr_handle);
    IndicatorRelease(bb_handle);
    IndicatorRelease(vol_ma_handle);
    Print("Universal Market Hunter Deinitialized.");
}

void OnTick()
{
    ManageOpenPositions();
    CheckForNewTradeSignal();
}

double CalculateLotSize(double stop_loss_in_points)
{
    double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double risk_amount = account_balance * (Risk_Percent_Per_Trade / 100.0);
    double sl_money_per_lot;
    if(!SymbolInfoDouble(_Symbol, SYMBOL_CALC_MODE_MONEY_HEDGED, sl_money_per_lot, stop_loss_in_points) || sl_money_per_lot <= 0) return 0.0;
    
    double calculated_lot = risk_amount / sl_money_per_lot;
    double volume_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    calculated_lot = floor(calculated_lot / volume_step) * volume_step;
    
    double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    if(calculated_lot < min_lot) calculated_lot = min_lot;
    
    return calculated_lot;
}

//+------------------------------------------------------------------+
