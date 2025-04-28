//+------------------------------------------------------------------+
//|                                               TrendAnalyzer.mqh  |
//| تحلیل روند و مدیریت خطوط روند                                    |
//+------------------------------------------------------------------+

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
//| کلاس تحلیل روند                                                  |
//+------------------------------------------------------------------+
class CTrendAnalyzer
{
private:
    SSettings m_settings;                // تنظیمات
    struct TrendLineInfo
    {
        string name;
        double length;
        datetime end_time;
        double angle;
        datetime times[];   // آرایه زمان‌ها
        double prices[];    // آرایه قیمت‌ها
    };
    TrendLineInfo trend_lines[];
    int m_trend_count;                   // تعداد خطوط روند
    string m_last_highlighted;           // آخرین خط هایلایت شده

public:
    //--- Constructor
    CTrendAnalyzer(const SSettings &settings)
    {
        m_settings = settings;
        m_trend_count = 0;
        m_last_highlighted = "";
    }

    //--- Reset trend lines
    void Reset()
    {
        ArrayFree(trend_lines);
        m_trend_count = 0;
    }

    //--- محاسبه شیب EMA
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
        return (n * sum_xy - sum_x * sum_y) / (n * sum_x2 - sum_x * sum_x);
    }

    //--- بررسی تغییر جهت شیب
    bool IsSlopeDirectionChanged(double current_slope, double prev_slope)
    {
        return (current_slope * prev_slope <= 0);
    }

    //--- اضافه کردن خط روند جدید
    void AddTrendLine(string name, double length, datetime end_time, double angle)
    {
        TrendLineInfo info;
        info.name = name;
        info.length = length;
        info.end_time = end_time;
        info.angle = angle;
        ArrayResize(trend_lines, ArraySize(trend_lines) + 1);
        trend_lines[ArraySize(trend_lines) - 1] = info;
        m_trend_count++;
    }

    //--- محاسبه زاویه بین دو نقطه
    double CalculateAngle(datetime time1, double price1, datetime time2, double price2)
    {
        double delta_y = price2 - price1;
        double delta_x = (double)((time2 - time1) / PeriodSeconds(PERIOD_M5));
        if(delta_x == 0) return 0;
        double chart_height_points = ChartGetDouble(0, CHART_PRICE_MAX) - ChartGetDouble(0, CHART_PRICE_MIN);
        int chart_width_bars = (int)ChartGetInteger(0, CHART_WIDTH_IN_BARS);
        if(chart_height_points == 0 || chart_width_bars == 0) return 0;
        double normalized_dy = delta_y / chart_height_points * chart_width_bars;
        double normalized_dx = delta_x;
        return MathArctan(normalized_dy/normalized_dx) * 180.0 / M_PI;
    }

    //--- محاسبه طول بردار
    double CalculateVectorLength(datetime time1, double price1, datetime time2, double price2)
    {
        double delta_y = price2 - price1;
        double delta_x = (double)((time2 - time1) / PeriodSeconds(PERIOD_M5));
        int chart_width_pixels = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
        int chart_height_pixels = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
        if(chart_width_pixels == 0 || chart_height_pixels == 0) return 0;
        double chart_height_points = ChartGetDouble(0, CHART_PRICE_MAX) - ChartGetDouble(0, CHART_PRICE_MIN);
        int chart_width_bars = (int)ChartGetInteger(0, CHART_WIDTH_IN_BARS);
        double pixels_per_bar = (double)chart_width_pixels / chart_width_bars;
        double pixels_per_point = (double)chart_height_pixels / (chart_height_points / _Point);
        double dx_pixels = delta_x * pixels_per_bar;
        double dy_pixels = (delta_y / _Point) * pixels_per_point;
        return MathSqrt(MathPow(dx_pixels, 2) + MathPow(dy_pixels, 2)) / 20.0;
    }

    //--- دریافت آخرین خط روند معتبر
    bool GetLastValidTrendLine(string &name, double &length, double &angle)
    {
        string latest_name = "";
        double latest_length = 0;
        double latest_angle = 0;
        datetime latest_time = 0;
        for(int i = 0; i < m_trend_count; i++)
        {
            if(trend_lines[i].length <= m_settings.MinVectorLength) continue;
            if(trend_lines[i].end_time > latest_time)
            {
                latest_time = trend_lines[i].end_time;
                latest_name = trend_lines[i].name;
                latest_length = trend_lines[i].length;
                latest_angle = trend_lines[i].angle;
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

    int GetTrendLinesCount() { return ArraySize(trend_lines); }

    bool GetTrendLineInfo(int index, string &name, double &length, datetime &end_time, double &angle, datetime &times[], double &prices[])
    {
        if(index < 0 || index >= ArraySize(trend_lines)) return false;
        name = trend_lines[index].name;
        length = trend_lines[index].length;
        end_time = trend_lines[index].end_time;
        angle = trend_lines[index].angle;
        ArrayCopy(times, trend_lines[index].times);
        ArrayCopy(prices, trend_lines[index].prices);
        return true;
    }
};
