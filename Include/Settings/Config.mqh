//+------------------------------------------------------------------+
//|                                                      Config.mqh  |
//| تنظیمات کلی اکسپرت                                                |
//+------------------------------------------------------------------+




// ساختار اصلی تنظیمات
struct SSettings
{
    // پارامترهای ورودی
    int    EmaPeriod;         // دوره EMA
    int    Lookback;          // تعداد کندل برای تحلیل
    color  LineColor;         // رنگ خط روند
    int    LineWidth;         // ضخامت خط روند
    color  SignalColor;       // رنگ فلش سیگنال
    int    ArrowSize;         // اندازه فلش
    int    ArrowDistance;     // فاصله فلش از کندل
    double MinSlopeAngle;     // حداقل زاویه شیب
    double MinVectorLength;   // حداقل طول بردار
    double MaxVectorLength;   // حداکثر طول بردار
    double MaxStopLossATR;    // حداکثر استاپ‌لاس بر اساس ATR
    double LotSize;           // حجم معامله
    double RiskRewardRatio;   // نسبت ریسک به ریوارد
    bool   AllowTrading;      // اجازه معامله
    double MaxStopLoss;       // حداکثر استاپ‌لاس (بر حسب پوینت)

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
