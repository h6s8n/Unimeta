//+------------------------------------------------------------------+
//|                                                   TrendSlopeEA.mq5 |
//|                                  Copyright 2024                    |
//|                                                                   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property link      ""
#property version   "1.00"

#define M_PI 3.14159265358979323846

#include <Trade\Trade.mqh>
#include "Include/Drawing/DrawingTypes.mqh"
#include "Include/Drawing/TrendLineDrawer.mqh"
#include "Include/Drawing/SmoothLineDrawer.mqh"
#include "Include/Drawing/SignalDrawer.mqh"

// Input parameters
input int    InpEmaPeriod = 20;        // EMA Period
input int    InpLookback = 50;         // Number of bars to analyze
input color  InpLineColor = clrBlue;   // Line color
input int    InpLineWidth = 1;         // Line width
input color  InpSignalColor = clrYellow;   // Signal arrow color
input int    InpArrowSize = 3;         // Arrow size
input int    InpArrowDistance = 5;     // Arrow distance from candle (in points)
input double InpMinSlopeAngle = 30.0;     // Minimum Slope Angle (degrees)
input double InpMaxStopLossATR = 2.0;     // Maximum Stop Loss (ATR multiplier)
input double InpLotSize = 0.01;        // Lot Size
input double InpRiskRewardRatio = 1.0;    // Risk to Reward ratio (1.0 = 1:1, 2.0 = 1:2)
input double InpMinVectorLength = 3.0;    // Minimum Vector Length for Trend Confirmation (3-10)
input double InpMaxVectorLength = 10.0;   // Maximum Vector Length for Trend Confirmation (3-10)
input bool   InpAllowTrading = true;   // Allow Trading
input double InpMaxStopLoss = 2.0;       // Maximum Stop Loss in points

// Global variables
int g_ema_handle;
int g_atr_handle;
bool g_initialized = false;
double g_atr = 0;  // Added ATR value

// Drawing objects
CTrendLineDrawer* trend_drawer = NULL;
CSmoothLineDrawer* smooth_drawer = NULL;
CSignalDrawer* signal_drawer = NULL;

// Trade object
CTrade trade;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
    // Reset position flags
    g_initialized = false;
    
    // Initialize trade object
    trade.SetExpertMagicNumber(123456);
    trade.SetMarginMode();
    trade.SetTypeFillingBySymbol(_Symbol);
    trade.SetDeviationInPoints(10);
    
    // Initialize drawing objects
    trend_drawer = new CTrendLineDrawer(InpLineColor, InpLineWidth);
    smooth_drawer = new CSmoothLineDrawer(trend_drawer);
    signal_drawer = new CSignalDrawer(InpSignalColor, InpArrowSize, InpArrowDistance);
    
    // Clear all objects
    ObjectsDeleteAll(0, "TrendInfo_");
    ObjectsDeleteAll(0, "TrendArrow_");
    
    // Chart settings
    ChartSetInteger(0, CHART_MODE, CHART_CANDLES);
    ChartSetInteger(0, CHART_SHOW_GRID, false);
    ChartSetInteger(0, CHART_SHOW_VOLUMES, false);
    ChartSetInteger(0, CHART_SHOW_ASK_LINE, true);
    ChartSetInteger(0, CHART_SHOW_BID_LINE, true);
    
    // Initialize indicators
    g_ema_handle = iMA(_Symbol, PERIOD_CURRENT, InpEmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
    if(g_ema_handle == INVALID_HANDLE)
    {
        Print("Error creating EMA indicator");
        return INIT_FAILED;
    }
    
    g_atr_handle = iATR(_Symbol, PERIOD_CURRENT, 14);
    if(g_atr_handle == INVALID_HANDLE)
    {
        Print("Error creating ATR indicator");
        return INIT_FAILED;
    }
    
    // Wait for data
    int waited = 0;
    while(BarsCalculated(g_ema_handle) < 100 && waited < 50)
    {
        Sleep(100);
        waited++;
    }
    
    if(BarsCalculated(g_ema_handle) < 100)
    {
        Print("Failed to get enough data for EMA calculation");
        return INIT_FAILED;
    }
    
    ChartRedraw();
    g_initialized = true;
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Clean up drawing objects
    if(trend_drawer != NULL) delete trend_drawer;
    if(smooth_drawer != NULL) delete smooth_drawer;
    if(signal_drawer != NULL) delete signal_drawer;
    
    // Clean up indicators
    if(g_ema_handle != INVALID_HANDLE) IndicatorRelease(g_ema_handle);
    if(g_atr_handle != INVALID_HANDLE) IndicatorRelease(g_atr_handle);
}

//+------------------------------------------------------------------+
//| Check if candle size is valid                                     |
//+------------------------------------------------------------------+
bool IsValidSize(double total_size, double body_size)
{
    // Size should be at least 60% of ATR
    if(total_size <= g_atr * 0.6) return false;
    
    // Body should be at least 40% of total size
    if(body_size < total_size * 0.4) return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Check if candle is valid signal                                   |
//+------------------------------------------------------------------+
bool IsValidSignal(const double &ema_values[], int index)
{
    if(index >= ArraySize(ema_values)-1) return false;
    
    double high = iHigh(_Symbol, PERIOD_M5, index);
    double low = iLow(_Symbol, PERIOD_M5, index);
    double open = iOpen(_Symbol, PERIOD_M5, index);
    double close = iClose(_Symbol, PERIOD_M5, index);
    double ema = ema_values[index];
    
    // Calculate sizes
    double total_size = high - low;
    double body_size = MathAbs(close - open);
    
    // Check size first
    if(!IsValidSize(total_size, body_size))
    {
        if(index == 0) Print("Size check failed - Total: ", DoubleToString(total_size/_Point, 1), 
                            ", Body: ", DoubleToString(body_size/_Point, 1),
                            ", ATR: ", DoubleToString(g_atr/_Point, 1));
        return false;
    }
    
    // Check EMA cross
    if(close > open) // Bullish candle
    {
        bool is_valid = (low <= ema && close > ema); // Cross from below
        if(index == 0) Print("Bullish candle check - Low: ", DoubleToString(low, _Digits), 
                            ", Close: ", DoubleToString(close, _Digits),
                            ", EMA: ", DoubleToString(ema, _Digits),
                            ", Valid: ", is_valid ? "Yes" : "No");
        return is_valid;
    }
    else // Bearish candle
    {
        bool is_valid = (high >= ema && close < ema); // Cross from above
        if(index == 0) Print("Bearish candle check - High: ", DoubleToString(high, _Digits),
                            ", Close: ", DoubleToString(close, _Digits),
                            ", EMA: ", DoubleToString(ema, _Digits),
                            ", Valid: ", is_valid ? "Yes" : "No");
        return is_valid;
    }
}

//+------------------------------------------------------------------+
//| Check if two consecutive candles form a valid signal              |
//+------------------------------------------------------------------+
bool IsConsecutiveSignal(const double &ema_values[], int index)
{
    if(index >= ArraySize(ema_values)-2) return false;
    
    // Get data for both candles
    double high1 = iHigh(_Symbol, PERIOD_M5, index);
    double low1 = iLow(_Symbol, PERIOD_M5, index);
    double open1 = iOpen(_Symbol, PERIOD_M5, index);
    double close1 = iClose(_Symbol, PERIOD_M5, index);
    
    double high2 = iHigh(_Symbol, PERIOD_M5, index+1);
    double low2 = iLow(_Symbol, PERIOD_M5, index+1);
    double open2 = iOpen(_Symbol, PERIOD_M5, index+1);
    double close2 = iClose(_Symbol, PERIOD_M5, index+1);
    
    double ema = ema_values[index];
    
    // Check if both candles are in same direction
    bool is_first_bullish = close1 > open1;
    bool is_second_bullish = close2 > open2;
    
    if(is_first_bullish != is_second_bullish) return false;  // Must be same direction
    
    // Calculate combined sizes
    double total_size = MathMax(high1, high2) - MathMin(low1, low2);
    double total_body = MathAbs(close1 - open1) + MathAbs(close2 - open2);
    
    // Check size first
    if(!IsValidSize(total_size, total_body)) return false;
    
    // Check EMA cross
    if(is_first_bullish)  // Both bullish
    {
        return (MathMin(low1, low2) <= ema && close1 > ema);
    }
    else  // Both bearish
    {
        return (MathMax(high1, high2) >= ema && close1 < ema);
    }
}

//+------------------------------------------------------------------+
//| Check if candle touches EMA                                       |
//+------------------------------------------------------------------+
bool IsTouchSignal(const double &ema_values[], int index)
{
    if(index >= ArraySize(ema_values)-1) return false;
    
    double high = iHigh(_Symbol, PERIOD_M5, index);
    double low = iLow(_Symbol, PERIOD_M5, index);
    double open = iOpen(_Symbol, PERIOD_M5, index);
    double close = iClose(_Symbol, PERIOD_M5, index);
    double ema = ema_values[index];
    
    // Calculate sizes
    double total_size = high - low;
    double body_size = MathAbs(close - open);
    
    // Check size first
    if(!IsValidSize(total_size, body_size)) return false;
    
    // Check if EMA is within candle range
    bool touches_ema = (ema >= low && ema <= high);
    
    // For bullish candles, should touch from below
    if(close > open)
    {
        return touches_ema && low <= ema && MathAbs(close - ema) <= total_size * 0.3;
    }
    // For bearish candles, should touch from above
    else
    {
        return touches_ema && high >= ema && MathAbs(close - ema) <= total_size * 0.3;
    }
}

//+------------------------------------------------------------------+
//| Calculate EMA slope                                               |
//+------------------------------------------------------------------+
double CalculateEMASlope(const double &ema_values[], int index, int period = 5)
{
    if(index >= ArraySize(ema_values)-period) return 0;
    
    double sum_x = 0, sum_y = 0, sum_xy = 0, sum_x2 = 0;
    int n = period;
    
    for(int i = 0; i < period; i++)
    {
        sum_x += i;
        sum_y += ema_values[index + i];
        sum_xy += i * ema_values[index + i];
        sum_x2 += i * i;
    }
    
    double slope = (n * sum_xy - sum_x * sum_y) / (n * sum_x2 - sum_x * sum_x);
    return slope;
}

//+------------------------------------------------------------------+
//| Check if slope direction changed                                  |
//+------------------------------------------------------------------+
bool IsSlopeDirectionChanged(double current_slope, double prev_slope)
{
    return (current_slope * prev_slope <= 0);
}

//+------------------------------------------------------------------+
//| Draw trend line based on slope                                    |
//+------------------------------------------------------------------+
void DrawTrendLine(string name, datetime time1, double price1, datetime time2, double price2, color line_color)
{
    ObjectCreate(0, name, OBJ_TREND, 0, time1, price1, time2, price2);
    ObjectSetInteger(0, name, OBJPROP_COLOR, line_color);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
    ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
    ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
}

//+------------------------------------------------------------------+
//| Calculate and display angle                                       |
//+------------------------------------------------------------------+
void DisplayAngle(string base_name, datetime time1, double price1, datetime time2, double price2)
{
    uint start_time = GetTickCount();
    Print("--- DisplayAngle Performance Log ---");
    Print("Starting angle calculation for line: ", base_name);
    
    // Calculate price change (Δy) and time change (Δx)
    double delta_y = price2 - price1;
    double delta_x = (double)((time2 - time1) / PeriodSeconds(PERIOD_M5));
    
    if(delta_x == 0) return;
    
    uint calc_start = GetTickCount();
    // Get chart scaling factors for angle calculation
    double chart_height_points = ChartGetDouble(0, CHART_PRICE_MAX) - ChartGetDouble(0, CHART_PRICE_MIN);
    int chart_width_bars = (int)ChartGetInteger(0, CHART_WIDTH_IN_BARS);
    
    if(chart_height_points == 0 || chart_width_bars == 0) return;
    
    // Calculate normalized changes for angle calculation
    double normalized_dy = delta_y / chart_height_points * chart_width_bars;
    double normalized_dx = delta_x;
    
    // Calculate angle in degrees
    double angle = MathArctan(normalized_dy/normalized_dx) * 180.0 / M_PI;
    Print("Time for angle calculation: ", GetTickCount() - calc_start, " ms");
    
    uint length_start = GetTickCount();
    // Calculate vector length in pixels
    int chart_width_pixels = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
    int chart_height_pixels = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
    
    if(chart_width_pixels == 0 || chart_height_pixels == 0) return;
    
    double pixels_per_bar = (double)chart_width_pixels / chart_width_bars;
    double pixels_per_point = (double)chart_height_pixels / (chart_height_points / _Point);
    
    double dx_pixels = delta_x * pixels_per_bar;
    double dy_pixels = (delta_y / _Point) * pixels_per_point;
    
    double vector_length = MathSqrt(MathPow(dx_pixels, 2) + MathPow(dy_pixels, 2));
    double scaled_length = vector_length / 20.0;
    Print("Time for length calculation: ", GetTickCount() - length_start, " ms");
    
    uint store_start = GetTickCount();
    // Store trend line information
    ArrayResize(trend_lines, trend_count + 1);
    trend_lines[trend_count].name = base_name;
    trend_lines[trend_count].length = scaled_length;
    trend_lines[trend_count].end_time = time2;
    trend_lines[trend_count].angle = angle;
    trend_count++;
    Print("Time to store trend info: ", GetTickCount() - store_start, " ms");
    
    uint display_start = GetTickCount();
    // Find the middle point of the line for text placement
    datetime time_mid = time1 + (time2 - time1)/2;
    double price_mid = price1 + (price2 - price1)/2;
    
    // Add some vertical offset for better visibility
    double price_offset = g_atr * 0.5;
    
    // Create angle text object
    string angle_name = "Angle_" + base_name;
    ObjectCreate(0, angle_name, OBJ_TEXT, 0, time_mid, price_mid + price_offset);
    ObjectSetString(0, angle_name, OBJPROP_TEXT, StringFormat("%.1f° (%.1f)", angle, scaled_length));
    ObjectSetInteger(0, angle_name, OBJPROP_COLOR, clrMagenta);
    ObjectSetInteger(0, angle_name, OBJPROP_FONTSIZE, 10);
    ObjectSetInteger(0, angle_name, OBJPROP_ANCHOR, ANCHOR_LOWER);
    ObjectSetString(0, angle_name, OBJPROP_FONT, "Arial Bold");
    Print("Time to create display objects: ", GetTickCount() - display_start, " ms");
    
    Print("=== Total DisplayAngle time: ", GetTickCount() - start_time, " ms ===");
}

//+------------------------------------------------------------------+
//| Check if there are any open positions                              |
//+------------------------------------------------------------------+
bool HasOpenPositions()
{
    int total = PositionsTotal();
    for(int i = total - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket <= 0) continue;
        
        if(PositionSelectByTicket(ticket))
        {
            string symbol = PositionGetString(POSITION_SYMBOL);
            if(symbol == _Symbol) return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Calculate current slope angle                                      |
//+------------------------------------------------------------------+
double CalculateCurrentAngle()
{
    double ema_values[];
    ArraySetAsSeries(ema_values, true);
    CopyBuffer(g_ema_handle, 0, 0, 3, ema_values);
    
    double dx = 2.0;  // Two bars time difference
    double dy = ema_values[0] - ema_values[2];
    
    return MathArctan(dy/dx) * 180.0 / M_PI;
}

//+------------------------------------------------------------------+
//| Get last valid trend line                                          |
//+------------------------------------------------------------------+
bool GetLastValidTrendLine()
{
    static datetime last_check_time = 0;
    datetime current_time = iTime(_Symbol, PERIOD_M5, 0);
    
    if(current_time == last_check_time) return false;
    last_check_time = current_time;
    
    Print("--- Checking for Valid Trend Lines ---");
    
    // Get the latest valid trend line from trend_drawer
    TrendLineInfo latest_trend;
    if(trend_drawer.GetLatestValidTrendLine(latest_trend))
    {
        Print("Found valid trend line: ", latest_trend.name);
        Print("Line length: ", latest_trend.length);
        
        trend_drawer.HighlightLine(latest_trend.name);
        
        // Update info box
        string infoBoxName = "TrendInfo_" + latest_trend.name;
        ObjectsDeleteAll(0, "TrendInfo_");
        
        if(ObjectCreate(0, infoBoxName, OBJ_LABEL, 0, 0, 0))
        {
            ObjectSetInteger(0, infoBoxName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
            ObjectSetInteger(0, infoBoxName, OBJPROP_XDISTANCE, 10);
            ObjectSetInteger(0, infoBoxName, OBJPROP_YDISTANCE, 10);
            ObjectSetInteger(0, infoBoxName, OBJPROP_COLOR, clrBlack);
            ObjectSetString(0, infoBoxName, OBJPROP_TEXT, 
                "Last Valid Line Length = " + DoubleToString(latest_trend.length, 1));
            ObjectSetInteger(0, infoBoxName, OBJPROP_FONTSIZE, 8);
        }
        
        return true;
    }
    
    Print("No valid trend line found");
    return false;
}

//+------------------------------------------------------------------+
//| Check trade conditions                                             |
//+------------------------------------------------------------------+
bool CheckTradeConditions(bool is_bullish_signal)
{
    Print("------- Checking Trade Conditions -------");
    Print("Signal Type: ", (is_bullish_signal ? "Bullish" : "Bearish"));
    
    if(!InpAllowTrading)
    {
        Print("Trading is not allowed by input parameter");
        return false;
    }
    
    if(HasOpenPositions())
    {
        Print("Has open positions, no new trades allowed");
        return false;
    }
    
    // Get the latest trend line from trend_drawer
    TrendLineInfo latest_trend;
    if(trend_drawer.GetLatestTrendLine(latest_trend))
    {
        Print("Latest trend line: ", latest_trend.name);
        Print("Trend line angle: ", latest_trend.angle);
        
        // Check if signal matches trend direction
        if(is_bullish_signal && latest_trend.angle <= 0)
        {
            Print("Rejecting bullish signal - Trend is bearish (angle: ", latest_trend.angle, ")");
            return false;
        }
        else if(!is_bullish_signal && latest_trend.angle >= 0)
        {
            Print("Rejecting bearish signal - Trend is bullish (angle: ", latest_trend.angle, ")");
            return false;
        }
        
        Print("Signal matches trend direction");
        return true;
    }
    
    Print("No valid trend line found");
    return false;
}

//+------------------------------------------------------------------+
//| Open new position                                                  |
//+------------------------------------------------------------------+
bool OpenPosition(bool is_buy)
{
    Print("=== Attempting to Open Position ===");
    
    if(!InpAllowTrading)
    {
        Print("Trading is not allowed (InpAllowTrading = false)");
        return false;
    }
    
    if(HasOpenPositions())
    {
        Print("Cannot open position - There are already open positions");
        return false;
    }
    
    // Calculate stop loss based on the signal candle
    double high = iHigh(_Symbol, PERIOD_M5, 1);
    double low = iLow(_Symbol, PERIOD_M5, 1);
    double stop_loss;
    
    // Get current price
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Calculate stop loss and take profit
    if(is_buy)
    {
        stop_loss = low - (10 * _Point); // Add some buffer
        double take_profit = ask + ((ask - stop_loss) * InpRiskRewardRatio);
        
        Print("Attempting BUY at ", ask, " SL: ", stop_loss, " TP: ", take_profit);
        return trade.Buy(InpLotSize, _Symbol, ask, stop_loss, take_profit, "Signal Trade");
    }
    else
    {
        stop_loss = high + (10 * _Point); // Add some buffer
        double take_profit = bid - ((stop_loss - bid) * InpRiskRewardRatio);
        
        Print("Attempting SELL at ", bid, " SL: ", stop_loss, " TP: ", take_profit);
        return trade.Sell(InpLotSize, _Symbol, bid, stop_loss, take_profit, "Signal Trade");
    }
}

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
void OnTick()
{
    if(!g_initialized) return;
    
    static datetime last_candle_time = 0;
    datetime current_candle_time = iTime(_Symbol, PERIOD_M5, 0);
    
    // Only process when a new candle forms
    if(current_candle_time == last_candle_time) 
    {
        return;  // Skip if not a new candle
    }
    
    Print("=== New Candle Detected ===");
    Print("Current candle time: ", TimeToString(current_candle_time));
    Print("Last candle time: ", TimeToString(last_candle_time));
    
    last_candle_time = current_candle_time;
    
    // Counter for signals
    static int single_bullish = 0;
    static int single_bearish = 0;
    static int consecutive_bullish = 0;
    static int consecutive_bearish = 0;
    static int touch_bullish = 0;
    static int touch_bearish = 0;
    
    // Check if we have enough data
    if(Bars(_Symbol, PERIOD_CURRENT) < 100)
    {
        Print("Not enough bars in the chart");
        return;
    }
    
    double ema_values[];
    ArraySetAsSeries(ema_values, true);
    
    // Make sure we get valid data
    if(CopyBuffer(g_ema_handle, 0, 0, 100, ema_values) != 100)
    {
        Print("Error copying EMA values");
        return;
    }
    
    // Calculate ATR using iATR indicator
    double atr_values[];
    ArraySetAsSeries(atr_values, true);
    if(CopyBuffer(g_atr_handle, 0, 0, 1, atr_values) != 1)
    {
        Print("Error copying ATR values");
        return;
    }
    g_atr = atr_values[0];
    
    // Set ATR for trend drawer
    trend_drawer.SetATR(g_atr);
    
    // Draw colored EMA line segments (historical)
    for(int i = 1; i < 99; i++)
    {
        double current_slope = CalculateEMASlope(ema_values, i);
        datetime time1 = iTime(_Symbol, PERIOD_M5, i);
        datetime time2 = iTime(_Symbol, PERIOD_M5, i+1);
        double price1 = ema_values[i];
        double price2 = ema_values[i+1];
        
        string ema_name = "EMA_" + IntegerToString(i);
        color ema_color = current_slope > 0 ? clrLime : clrRed;
        
        trend_drawer.DrawTrendLine(ema_name, time1, price1, time2, price2, ema_color);
    }
    
    // Draw slope change lines and calculate angles
    double prev_slope = 0;
    datetime prev_time = 0;
    double prev_price = 0;
    bool first_point = true;
    
    for(int i = 1; i < 100; i++)
    {
        double current_slope = CalculateEMASlope(ema_values, i);
        
        if(!first_point && IsSlopeDirectionChanged(current_slope, prev_slope))
        {
            datetime current_time = iTime(_Symbol, PERIOD_M5, i);
            double current_price = ema_values[i];
            
            string line_name = "Slope_" + IntegerToString(i);
            color line_color = current_slope > 0 ? clrLime : clrRed;
            
            trend_drawer.DrawTrendLine(line_name, prev_time, prev_price, current_time, current_price, line_color);
            trend_drawer.DisplayAngle(line_name, prev_time, prev_price, current_time, current_price);
            
            prev_time = current_time;
            prev_price = current_price;
        }
        else if(first_point)
        {
            prev_time = iTime(_Symbol, PERIOD_M5, i);
            prev_price = ema_values[i];
            first_point = false;
        }
        
        prev_slope = current_slope;
    }
    
    // Check for signal candles in history
    for(int i = 1; i < 100; i++)
    {
        if(IsValidSignal(ema_values, i))
        {
            bool is_up = iClose(_Symbol, PERIOD_M5, i) > iOpen(_Symbol, PERIOD_M5, i);
            SignalInfo signal;
            signal.name = "Signal_" + IntegerToString(i);
            signal.time = iTime(_Symbol, PERIOD_M5, i);
            signal.price = is_up ? iLow(_Symbol, PERIOD_M5, i) - (InpArrowDistance * _Point) 
                                : iHigh(_Symbol, PERIOD_M5, i) + (InpArrowDistance * _Point);
            signal.is_buy = is_up;
            
            signal_drawer.DrawSignal(signal);
            
            // Count signals
            if(is_up) single_bullish++;
            else single_bearish++;
            
            // Only consider trading on the most recent closed candle
            if(i == 1)
            {
                Print("=== Signal Found on Last Closed Candle ===");
                Print("Signal type: ", (is_up ? "BULLISH" : "BEARISH"));
                Print("Signal time: ", TimeToString(signal.time));
                Print("Signal price: ", DoubleToString(signal.price, _Digits));
                
                // Check if we can open a trade
                if(CheckTradeConditions(is_up))
                {
                    if(is_up)
                    {
                        Print("Attempting to open BUY position...");
                        OpenPosition(true);
                    }
                    else
                    {
                        Print("Attempting to open SELL position...");
                        OpenPosition(false);
                    }
                }
            }
        }
    }
    
    // Get last valid trend line
    GetLastValidTrendLine();
    
    // Draw smooth trend lines
    smooth_drawer.DrawAllSmoothLines();
    
    // Show signal counts and trading status
    string trading_status = "\nTrading: " + (InpAllowTrading ? "Enabled" : "Disabled");
    trading_status += "\nOpen Positions: " + (HasOpenPositions() ? "Yes" : "No");
    
    Comment("Signal Analysis:\n",
            "Single Candle Signals:\n",
            "  Bullish: ", single_bullish, "\n",
            "  Bearish: ", single_bearish, "\n",
            "Consecutive Candle Signals:\n",
            "  Bullish: ", consecutive_bullish, "\n",
            "  Bearish: ", consecutive_bearish, "\n",
            "Touch Signals:\n",
            "  Bullish: ", touch_bullish, "\n",
            "  Bearish: ", touch_bearish, "\n",
            "Total Signals: ", (single_bullish + single_bearish + 
                              consecutive_bullish + consecutive_bearish +
                              touch_bullish + touch_bearish), "\n",
            "ATR Value: ", DoubleToString(g_atr/_Point, 1), " points",
            trading_status);
    
    ChartRedraw();
}

//+------------------------------------------------------------------+
//| Returns true if a new bar has just been formed                     |
//+------------------------------------------------------------------+
bool IsNewBar()
{
    static datetime last_time = 0;
    datetime current_time = iTime(_Symbol, PERIOD_M5, 0);
    if(last_time == 0)
    {
        last_time = current_time;
        return false;
    }
    if(current_time != last_time)
    {
        last_time = current_time;
        return true;
    }
    return false;
}

void OnChartEvent(const int id, const long& lparam, const double& dparam, const string& sparam) {
    if(id == CHARTEVENT_OBJECT_CLICK) {
        if(StringFind(sparam, "TrendLine_") == 0) {
            trend_drawer.HighlightLine(sparam);
        }
    }
} 