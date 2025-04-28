//+------------------------------------------------------------------+
//| DrawingTypes.mqh                                                 |
//| ساختارهای داده مشترک برای بخش رسم                               |
//+------------------------------------------------------------------+

// ساختار اطلاعات خط روند
struct TrendLineInfo {
    string name;           // نام خط
    double length;         // طول خط
    datetime end_time;     // زمان پایان
    double angle;          // زاویه
    datetime times[];      // آرایه زمان‌ها
    double prices[];       // آرایه قیمت‌ها
};

// ساختار اطلاعات سیگنال
struct SignalInfo {
    string name;           // نام سیگنال
    datetime time;         // زمان سیگنال
    double price;          // قیمت سیگنال
    bool is_buy;           // نوع سیگنال (خرید/فروش)
};
