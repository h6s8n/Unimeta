//+------------------------------------------------------------------+
//|                                               TrendAnalyzer.mqh |
//|                                  Copyright 2024                    |
//|                                                                   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property link      ""
#property version   "1.00"

// Include settings
#include "../Settings/Config.mqh"

// ساختار نگهداری اطلاعات خط روند
struct STrendInfo
{
    string name;        // نام خط روند
    double length;      // طول خط روند
    datetime end_time;  // زمان پایان
    double angle;       // زاویه خط روند
};

//+------------------------------------------------------------------+
//| کلاس تحلیل روند                                                    |
//+------------------------------------------------------------------+
class CTrendAnalyzer
{
private:
    SSettings* m_settings;                // اشاره‌گر به تنظیمات
    STrendInfo m_trend_lines[];          // آرایه خطوط روند
    int m_trend_count;                   // تعداد خطوط روند
    string m_last_highlighted;           // آخرین خط هایلایت شده

public:
    //--- Constructor
    CTrendAnalyzer(SSettings* settings)
    {
        m_settings = settings;
        m_trend_count = 0;
        m_last_highlighted = "";
    }

    //--- Reset trend lines
    void Reset()
    {
        ArrayFree(m_trend_lines);
        m_trend_count = 0;
    }

    //--- محاسبه شیب EMA
    double CalculateEMASlope(const double &ema_values[], int index, int period = 5)
    {
        if(index >= ArraySize(ema_values)-period) return 0;
        
        // محاسبه رگرسیون خطی برای تعیین شیب
        double sum_x = 0, sum_y = 0, sum_xy = 0, sum_x2 = 0;
        int n = period;
        
        for(int i = 0; i < period; i++)
        {
            sum_x += i;
            sum_y += ema_values[index + i];
            sum_xy += i * ema_values[index + i];
            sum_x2 += i * i;
        }
        
        // فرمول شیب در رگرسیون خطی
        return (n * sum_xy - sum_x * sum_y) / (n * sum_x2 - sum_x * sum_x);
    }

    //--- بررسی تغییر جهت شیب
    bool IsSlopeDirectionChanged(double current_slope, double prev_slope)
    {
        return (current_slope * prev_slope <= 0);  // ضرب منفی نشان‌دهنده تغییر جهت است
    }

    //--- اضافه کردن خط روند جدید
    void AddTrendLine(string name, double length, datetime end_time, double angle)
    {
        ArrayResize(m_trend_lines, m_trend_count + 1);
        m_trend_lines[m_trend_count].name = name;
        m_trend_lines[m_trend_count].length = length;
        m_trend_lines[m_trend_count].end_time = end_time;
        m_trend_lines[m_trend_count].angle = angle;
        m_trend_count++;
    }

    //--- محاسبه زاویه بین دو نقطه
    double CalculateAngle(datetime time1, double price1, datetime time2, double price2)
    {
        // محاسبه تغییرات قیمت و زمان
        double delta_y = price2 - price1;
        double delta_x = (double)((time2 - time1) / PeriodSeconds(PERIOD_M5));
        
        if(delta_x == 0) return 0;
        
        // دریافت فاکتورهای مقیاس چارت برای محاسبه زاویه
        double chart_height_points = ChartGetDouble(0, CHART_PRICE_MAX) - ChartGetDouble(0, CHART_PRICE_MIN);
        int chart_width_bars = (int)ChartGetInteger(0, CHART_WIDTH_IN_BARS);
        
        if(chart_height_points == 0 || chart_width_bars == 0) return 0;
        
        // نرمال‌سازی تغییرات برای محاسبه زاویه
        double normalized_dy = delta_y / chart_height_points * chart_width_bars;
        double normalized_dx = delta_x;
        
        // محاسبه زاویه به درجه
        return MathArctan(normalized_dy/normalized_dx) * 180.0 / M_PI;
    }

    //--- محاسبه طول بردار
    double CalculateVectorLength(datetime time1, double price1, datetime time2, double price2)
    {
        // محاسبه تغییرات قیمت و زمان
        double delta_y = price2 - price1;
        double delta_x = (double)((time2 - time1) / PeriodSeconds(PERIOD_M5));
        
        // دریافت ابعاد چارت به پیکسل
        int chart_width_pixels = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
        int chart_height_pixels = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
        
        if(chart_width_pixels == 0 || chart_height_pixels == 0) return 0;
        
        // محاسبه فاکتورهای مقیاس
        double chart_height_points = ChartGetDouble(0, CHART_PRICE_MAX) - ChartGetDouble(0, CHART_PRICE_MIN);
        int chart_width_bars = (int)ChartGetInteger(0, CHART_WIDTH_IN_BARS);
        
        double pixels_per_bar = (double)chart_width_pixels / chart_width_bars;
        double pixels_per_point = (double)chart_height_pixels / (chart_height_points / _Point);
        
        // محاسبه طول به پیکسل
        double dx_pixels = delta_x * pixels_per_bar;
        double dy_pixels = (delta_y / _Point) * pixels_per_point;
        
        // محاسبه طول بردار و مقیاس‌بندی آن
        return MathSqrt(MathPow(dx_pixels, 2) + MathPow(dy_pixels, 2)) / 20.0;
    }

    //--- دریافت آخرین خط روند معتبر
    bool GetLastValidTrendLine(string &name, double &length, double &angle)
    {
        string latest_name = "";
        double latest_length = 0;
        double latest_angle = 0;
        datetime latest_time = 0;
        
        // جستجوی آخرین خط روند معتبر
        for(int i = 0; i < m_trend_count; i++)
        {
            if(m_trend_lines[i].length <= m_settings.MinVectorLength) continue;
            
            if(m_trend_lines[i].end_time > latest_time)
            {
                latest_time = m_trend_lines[i].end_time;
                latest_name = m_trend_lines[i].name;
                latest_length = m_trend_lines[i].length;
                latest_angle = m_trend_lines[i].angle;
            }
        }
        
        if(latest_name == "")
        {
            Print("No valid line found");
            return false;
        }
        
        name = latest_name;
        length = latest_length;
        angle = latest_angle;
        return true;
    }

    //--- متدهای دسترسی به آخرین خط هایلایت شده
    string GetLastHighlighted() { return m_last_highlighted; }
    void SetLastHighlighted(string name) { m_last_highlighted = name; }
};
