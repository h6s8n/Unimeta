//+------------------------------------------------------------------+
//|                                                       Config.mqh |
//|                                  Copyright 2024                    |
//|                                                                   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property link      ""
#property version   "1.00"

// تعریف ثابت‌های مورد نیاز
#define M_PI 3.14159265358979323846

// ساختار اصلی تنظیمات
struct SSettings
{
    // --- پارامترهای ورودی ---
    int EmaPeriod;           // دوره EMA
    int Lookback;            // تعداد کندل‌های مورد بررسی
    double MinSlopeAngle;    // حداقل زاویه شیب
    double MaxStopLossATR;   // حداکثر حد ضرر بر اساس ATR
    double LotSize;          // حجم معامله
    double RiskRewardRatio;  // نسبت ریسک به ریوارد
    double MinVectorLength;  // حداقل طول بردار برای تایید روند
    double MaxVectorLength;  // حداکثر طول بردار برای تایید روند
    bool AllowTrading;       // اجازه معامله
    double MaxStopLoss;      // حداکثر حد ضرر

    // --- تنظیمات ظاهری ---
    color LineColor;         // رنگ خط
    int LineWidth;          // ضخامت خط
    color SignalColor;      // رنگ سیگنال
    int ArrowSize;         // اندازه فلش
    int ArrowDistance;     // فاصله فلش از کندل

    // تنظیم مقادیر پیش‌فرض
    void SetDefaults()
    {
        // پارامترهای اصلی
        EmaPeriod = 20;
        Lookback = 50;
        MinSlopeAngle = 30.0;
        MaxStopLossATR = 2.0;
        LotSize = 0.01;
        RiskRewardRatio = 1.0;
        MinVectorLength = 3.0;
        MaxVectorLength = 10.0;
        AllowTrading = true;
        MaxStopLoss = 2.0;
        
        // تنظیمات ظاهری
        LineColor = clrBlue;
        LineWidth = 1;
        SignalColor = clrYellow;
        ArrowSize = 3;
        ArrowDistance = 5;
    }
    
    // بارگذاری تنظیمات از پارامترهای ورودی
    void LoadFromInputs(
        int inpEmaPeriod,
        int inpLookback,
        color inpLineColor,
        int inpLineWidth,
        color inpSignalColor,
        int inpArrowSize,
        int inpArrowDistance,
        double inpMinSlopeAngle,
        double inpMaxStopLossATR,
        double inpLotSize,
        double inpRiskRewardRatio,
        double inpMinVectorLength,
        double inpMaxVectorLength,
        bool inpAllowTrading,
        double inpMaxStopLoss
    )
    {
        EmaPeriod = inpEmaPeriod;
        Lookback = inpLookback;
        LineColor = inpLineColor;
        LineWidth = inpLineWidth;
        SignalColor = inpSignalColor;
        ArrowSize = inpArrowSize;
        ArrowDistance = inpArrowDistance;
        MinSlopeAngle = inpMinSlopeAngle;
        MaxStopLossATR = inpMaxStopLossATR;
        LotSize = inpLotSize;
        RiskRewardRatio = inpRiskRewardRatio;
        MinVectorLength = inpMinVectorLength;
        MaxVectorLength = inpMaxVectorLength;
        AllowTrading = inpAllowTrading;
        MaxStopLoss = inpMaxStopLoss;
    }
};
