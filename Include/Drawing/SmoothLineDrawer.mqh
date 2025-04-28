#include "TrendLineDrawer.mqh"

//+------------------------------------------------------------------+
//| SmoothLineDrawer.mqh                                             |
//| کلاس رسم خطوط صاف                                                |
//+------------------------------------------------------------------+
class CSmoothLineDrawer {
private:
    CTrendLineDrawer* m_trend_drawer;  // اشاره‌گر به رسم‌کننده خط روند

public:
    // Constructor
    CSmoothLineDrawer(CTrendLineDrawer* trend_drawer) {
        m_trend_drawer = trend_drawer;
    }

    // رسم خط صاف
    void DrawSmoothLine(const string &name, 
                       datetime &times[], 
                       double &prices[]) {
        if(ArraySize(times) < 2 || ArraySize(prices) < 2) return;
        
        for(int i = 0; i < ArraySize(times) - 1; i++) {
            m_trend_drawer.DrawTrendLine(name + "_" + IntegerToString(i),
                                       times[i], prices[i],
                                       times[i+1], prices[i+1]);
        }
    }

    // رسم همه خطوط صاف
    void DrawAllSmoothLines(TrendLineInfo &lines[]) {
        for(int i = 0; i < ArraySize(lines); i++) {
            DrawSmoothLine(lines[i].name, lines[i].times, lines[i].prices);
        }
    }
};
