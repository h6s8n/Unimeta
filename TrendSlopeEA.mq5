//+------------------------------------------------------------------+
//|                                                   TrendSlopeEA.mq5 |
//|                                  Copyright 2024                    |
//|                                                                   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property link      ""
#property version   "1.00"

// Include necessary modules
#include "Include/Settings/Config.mqh"
#include "Include/Analysis/TrendAnalyzer.mqh"
#include "Include/Trading/TradeManager.mqh"
#include "Include/Signals/SignalManager.mqh"
#include "Include/Drawing/DrawManager.mqh"

// Input parameters
input int    InpEmaPeriod        = 20;      // EMA Period
input int    InpLookback         = 50;      // Lookback Period
input color  InpLineColor        = clrBlue; // Line Color
input int    InpLineWidth        = 1;       // Line Width
input color  InpSignalColor      = clrYellow; // Signal Color
input int    InpArrowSize        = 3;       // Arrow Size
input int    InpArrowDistance    = 5;       // Arrow Distance
input double InpMinSlopeAngle    = 30.0;    // Minimum Slope Angle
input double InpMinVectorLength  = 3.0;     // Minimum Vector Length
input double InpMaxVectorLength  = 10.0;    // Maximum Vector Length
input double InpMaxStopLossATR   = 2.0;     // Maximum Stop Loss (ATR)
input double InpLotSize          = 0.01;    // Lot Size
input double InpRiskRewardRatio  = 1.0;     // Risk/Reward Ratio
input bool   InpAllowTrading     = true;    // Allow Trading
input double InpMaxStopLoss      = 2.0;     // Maximum Stop Loss (Points)

// Global variables
SSettings g_settings;
CTrendAnalyzer* trendAnalyzer = NULL;
CTradeManager* tradeManager = NULL;
CSignalManager* signalManager = NULL;
CDrawManager* drawManager = NULL;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize settings
    g_settings.LoadFromInputs(
        InpEmaPeriod,
        InpLookback,
        InpLineColor,
        InpLineWidth,
        InpSignalColor,
        InpArrowSize,
        InpArrowDistance,
        InpMinSlopeAngle,
        InpMaxStopLossATR,
        InpLotSize,
        InpRiskRewardRatio,
        InpMinVectorLength,
        InpMaxVectorLength,
        InpAllowTrading,
        InpMaxStopLoss
    );
    
    // Initialize modules
    trendAnalyzer = new CTrendAnalyzer(g_settings);
    tradeManager = new CTradeManager(g_settings);
    signalManager = new CSignalManager(g_settings);
    drawManager = new CDrawManager(g_settings, trendAnalyzer);
    
    // Initialize indicators
    if(!signalManager.Initialize())
    {
        Print("Failed to initialize indicators");
        return INIT_FAILED;
    }
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Clean up
    if(trendAnalyzer != NULL) delete trendAnalyzer;
    if(tradeManager != NULL) delete tradeManager;
    if(signalManager != NULL) delete signalManager;
    if(drawManager != NULL) delete drawManager;
    
    // Clear all objects
    ObjectsDeleteAll(0, "TrendLine_");
    ObjectsDeleteAll(0, "Signal_");
}

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
// Add static variables for trend detection
static double prev_slope = 0;
static int last_trend_bar = -1;

void OnTick()
{
    // Update indicators
    if(!signalManager.Update())
    {
        Print("Failed to update indicators");
        return;
    }
    
    // Get EMA values
    double ema_values[];
    ArraySetAsSeries(ema_values, true);
    if(!signalManager.GetEMAValues(ema_values, g_settings.Lookback))
    {
        Print("Failed to get EMA values");
        return;
    }
    
    // محاسبه شیب فعلی
    double slope = trendAnalyzer.CalculateEMASlope(ema_values, 0, 5);

    // اگر تغییر جهت شیب داشتیم و کندل جدید است
    if(trendAnalyzer.IsSlopeDirectionChanged(slope, prev_slope) && last_trend_bar != iBarShift(_Symbol, PERIOD_M5, TimeCurrent()))
    {
        datetime t1 = iTime(_Symbol, PERIOD_M5, 10);
        double p1 = iClose(_Symbol, PERIOD_M5, 10);
        datetime t2 = iTime(_Symbol, PERIOD_M5, 0);
        double p2 = iClose(_Symbol, PERIOD_M5, 0);

        string trend_name = "TrendLine_" + IntegerToString(TimeCurrent());
        drawManager.DrawTrendLine(trend_name, t1, p1, t2, p2, clrBlue);
        drawManager.DisplayAngle(trend_name, t1, p1, t2, p2);

        last_trend_bar = iBarShift(_Symbol, PERIOD_M5, TimeCurrent());
    }
    prev_slope = slope;

    // بررسی سیگنال خرید/فروش و رسم فلش
    bool is_buy_signal = signalManager.IsValidSignal(ema_values, 0);
    bool is_sell_signal = signalManager.IsValidSignal(ema_values, 0);

    if(is_buy_signal)
        drawManager.DrawSignalArrow(0, true);
    if(is_sell_signal)
        drawManager.DrawSignalArrow(0, false);

    // Check if we can trade
    if(!g_settings.AllowTrading || tradeManager.HasOpenPositions())
    {
        Print("Trading not allowed or has open positions");
        return;
    }
    
    // Get trend line information
    string trend_line_name;
    double trend_length, trend_angle;
    if(!trendAnalyzer.GetLastValidTrendLine(trend_line_name, trend_length, trend_angle))
    {
        Print("No valid trend line found");
        return;
    }
    
    Print("Trend Line: ", trend_line_name);
    Print("Length: ", trend_length);
    Print("Angle: ", trend_angle);
    
    // Check for buy signal
    Print("Buy Signal: ", is_buy_signal);
    
    if(is_buy_signal && tradeManager.CheckTradeConditions(true, trend_line_name, trend_length, trend_angle))
    {
        Print("Opening BUY position");
        if(tradeManager.OpenPosition(true))
        {
            drawManager.DrawSignalArrow(0, true);
        }
    }
    
    // Check for sell signal
    Print("Sell Signal: ", is_sell_signal);
    
    if(is_sell_signal && tradeManager.CheckTradeConditions(false, trend_line_name, trend_length, trend_angle))
    {
        Print("Opening SELL position");
        if(tradeManager.OpenPosition(false))
        {
            drawManager.DrawSignalArrow(0, false);
        }
    }
}

//+------------------------------------------------------------------+
//| ChartEvent function                                                |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long& lparam, const double& dparam, const string& sparam)
{
    if(id == CHARTEVENT_OBJECT_CLICK)
    {
        if(StringFind(sparam, "TrendLine_") == 0)
        {
            double angle = 0.0;
            drawManager.HighlightTrendLine(sparam, angle);
        }
    }
}