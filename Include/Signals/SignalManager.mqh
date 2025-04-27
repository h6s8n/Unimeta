//+------------------------------------------------------------------+
//|                                               SignalManager.mqh  |
//| مدیریت سیگنال‌ها و اندیکاتورهای EMA و ATR                        |
//+------------------------------------------------------------------+

#include "../Settings/Config.mqh"

//+------------------------------------------------------------------+
//| کلاس مدیریت سیگنال‌ها                                              |
//+------------------------------------------------------------------+
class CSignalManager
{
private:
    int m_ema_handle;         // هندل اندیکاتور EMA
    int m_atr_handle;         // هندل اندیکاتور ATR
    double m_atr;             // مقدار ATR فعلی
    SSettings m_settings;     // تنظیمات
    
    //--- بررسی معتبر بودن سایز کندل
    bool IsValidSize(double total_size, double body_size)
    {
        // سایز باید حداقل 60% از ATR باشد
        if(total_size <= m_atr * 0.6) return false;
        
        // بدنه باید حداقل 40% از کل سایز باشد
        if(body_size < total_size * 0.4) return false;
        
        return true;
    }
    
public:
    //--- Constructor
    CSignalManager(const SSettings &settings)
    {
        m_settings = settings;
        m_ema_handle = INVALID_HANDLE;
        m_atr_handle = INVALID_HANDLE;
        m_atr = 0;
    }
    
    //--- Destructor
    ~CSignalManager()
    {
        if(m_ema_handle != INVALID_HANDLE) IndicatorRelease(m_ema_handle);
        if(m_atr_handle != INVALID_HANDLE) IndicatorRelease(m_atr_handle);
    }
    
    //--- راه‌اندازی اندیکاتورها
    bool Initialize()
    {
        // ایجاد اندیکاتور EMA
        m_ema_handle = iMA(_Symbol, PERIOD_CURRENT, m_settings.EmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
        if(m_ema_handle == INVALID_HANDLE)
        {
            Print("Error creating EMA indicator");
            return false;
        }
        
        // ایجاد اندیکاتور ATR
        m_atr_handle = iATR(_Symbol, PERIOD_CURRENT, 14);
        if(m_atr_handle == INVALID_HANDLE)
        {
            Print("Error creating ATR indicator");
            return false;
        }
        
        // انتظار برای آماده شدن داده‌ها
        int waited = 0;
        while(BarsCalculated(m_ema_handle) < 100 && waited < 50)
        {
            Sleep(100);
            waited++;
        }
        
        if(BarsCalculated(m_ema_handle) < 100)
        {
            Print("Failed to get enough data for EMA calculation");
            return false;
        }
        
        return true;
    }
    
    //--- به‌روزرسانی اندیکاتورها
    bool Update()
    {
        // محاسبه ATR
        double atr_buffer[];
        ArraySetAsSeries(atr_buffer, true);
        if(CopyBuffer(m_atr_handle, 0, 0, 1, atr_buffer) != 1)
        {
            Print("Error copying ATR values");
            return false;
        }
        m_atr = atr_buffer[0];
        return true;
    }
    
    //--- دریافت مقادیر EMA
    bool GetEMAValues(double &ema_values[], int count)
    {
        ArraySetAsSeries(ema_values, true);
        return (CopyBuffer(m_ema_handle, 0, 0, count, ema_values) == count);
    }
    
    //--- دریافت مقدار ATR
    double GetATR()
    {
        return m_atr;
    }
    
    //--- بررسی سیگنال معتبر
    bool IsValidSignal(const double &ema_values[], int index)
    {
        if(index >= ArraySize(ema_values)-1) return false;
        
        double high = iHigh(_Symbol, PERIOD_M5, index);
        double low = iLow(_Symbol, PERIOD_M5, index);
        double open = iOpen(_Symbol, PERIOD_M5, index);
        double close = iClose(_Symbol, PERIOD_M5, index);
        double ema = ema_values[index];
        
        // محاسبه سایزها
        double total_size = high - low;
        double body_size = MathAbs(close - open);
        
        // بررسی سایز
        if(!IsValidSize(total_size, body_size))
        {
            if(index == 0) Print("Size check failed - Total: ", DoubleToString(total_size/_Point, 1), 
                                ", Body: ", DoubleToString(body_size/_Point, 1),
                                ", ATR: ", DoubleToString(m_atr/_Point, 1));
            return false;
        }
        
        // بررسی قطع EMA
        if(close > open) // کندل صعودی
        {
            bool is_valid = (low <= ema && close > ema); // قطع از پایین
            if(index == 0) Print("Bullish candle check - Low: ", DoubleToString(low, _Digits), 
                                ", Close: ", DoubleToString(close, _Digits),
                                ", EMA: ", DoubleToString(ema, _Digits),
                                ", Valid: ", is_valid ? "Yes" : "No");
            return is_valid;
        }
        else // کندل نزولی
        {
            bool is_valid = (high >= ema && close < ema); // قطع از بالا
            if(index == 0) Print("Bearish candle check - High: ", DoubleToString(high, _Digits),
                                ", Close: ", DoubleToString(close, _Digits),
                                ", EMA: ", DoubleToString(ema, _Digits),
                                ", Valid: ", is_valid ? "Yes" : "No");
            return is_valid;
        }
    }
    
    //--- بررسی سیگنال دو کندل متوالی
    bool IsConsecutiveSignal(const double &ema_values[], int index)
    {
        if(index >= ArraySize(ema_values)-2) return false;
        
        // دریافت داده‌های هر دو کندل
        double high1 = iHigh(_Symbol, PERIOD_M5, index);
        double low1 = iLow(_Symbol, PERIOD_M5, index);
        double open1 = iOpen(_Symbol, PERIOD_M5, index);
        double close1 = iClose(_Symbol, PERIOD_M5, index);
        
        double high2 = iHigh(_Symbol, PERIOD_M5, index+1);
        double low2 = iLow(_Symbol, PERIOD_M5, index+1);
        double open2 = iOpen(_Symbol, PERIOD_M5, index+1);
        double close2 = iClose(_Symbol, PERIOD_M5, index+1);
        
        double ema = ema_values[index];
        
        // بررسی جهت یکسان کندل‌ها
        bool is_first_bullish = close1 > open1;
        bool is_second_bullish = close2 > open2;
        
        if(is_first_bullish != is_second_bullish) return false;  // باید هم جهت باشند
        
        // محاسبه سایزهای ترکیبی
        double total_size = MathMax(high1, high2) - MathMin(low1, low2);
        double total_body = MathAbs(close1 - open1) + MathAbs(close2 - open2);
        
        // بررسی سایز
        if(!IsValidSize(total_size, total_body)) return false;
        
        // بررسی قطع EMA
        if(is_first_bullish)  // هر دو صعودی
        {
            return (MathMin(low1, low2) <= ema && close1 > ema);
        }
        else  // هر دو نزولی
        {
            return (MathMax(high1, high2) >= ema && close1 < ema);
        }
    }
    
    //--- بررسی سیگنال لمس EMA
    bool IsTouchSignal(const double &ema_values[], int index)
    {
        if(index >= ArraySize(ema_values)-1) return false;
        
        double high = iHigh(_Symbol, PERIOD_M5, index);
        double low = iLow(_Symbol, PERIOD_M5, index);
        double open = iOpen(_Symbol, PERIOD_M5, index);
        double close = iClose(_Symbol, PERIOD_M5, index);
        double ema = ema_values[index];
        
        // محاسبه سایزها
        double total_size = high - low;
        double body_size = MathAbs(close - open);
        
        // بررسی سایز
        if(!IsValidSize(total_size, body_size)) return false;
        
        // بررسی لمس EMA
        bool touches_ema = (ema >= low && ema <= high);
        
        // برای کندل‌های صعودی، باید از پایین لمس کند
        if(close > open)
        {
            return touches_ema && low <= ema && MathAbs(close - ema) <= total_size * 0.3;
        }
        // برای کندل‌های نزولی، باید از بالا لمس کند
        else
        {
            return touches_ema && high >= ema && MathAbs(close - ema) <= total_size * 0.3;
        }
    }
};
