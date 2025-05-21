//import SwiftUI
//
//struct DailyForecastView: View {
//    let forecasts: [DailyForecastItem]
//    let onForecastSelected: (DailyForecastItem) -> Void
//    
//    @State private var expandedForecastId: UUID? = nil
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 12) {
//            // Section header
//            Text("7-DAY FORECAST")
//                .font(.headline)
//                .fontWeight(.semibold)
//                .padding(.vertical, 4)
//            
//            // Forecast header row
//            ForecastHeaderRow()
//            
//            // Forecast items
//            if forecasts.isEmpty {
//                Text("No forecast data available")
//                    .font(.subheadline)
//                    .foregroundColor(.secondary)
//                    .frame(maxWidth: .infinity, alignment: .center)
//                    .padding()
//            } else {
//                ForEach(forecasts) { forecast in
//                    DailyForecastRowView(
//                        forecast: forecast,
//                        isExpanded: forecast.id == expandedForecastId,
//                        isToday: forecast.isToday
//                    )
//                    .contentShape(Rectangle())
//                    .onTapGesture {
//                        withAnimation(.easeInOut(duration: 0.3)) {
//                            if expandedForecastId == forecast.id {
//                                expandedForecastId = nil
//                            } else {
//                                expandedForecastId = forecast.id
//                            }
//                        }
//                        
//                        // Also trigger the navigation callback
//                        onForecastSelected(forecast)
//                    }
//                    
//                    if forecast.id != forecasts.last?.id {
//                        Divider()
//                            .padding(.leading)
//                    }
//                }
//            }
//        }
//        .padding()
//        .background(
//            RoundedRectangle(cornerRadius: 12)
//                .fill(Color(UIColor.tertiarySystemBackground))
//                .shadow(radius: 2)
//        )
//    }
//}
//
//struct ForecastHeaderRow: View {
//    var body: some View {
//        HStack {
//            Text("Date")
//                .frame(width: 60, alignment: .leading)
//            
//            Image(systemName: "thermometer")
//                .frame(width: 60)
//            
//            Image(systemName: "moon.stars")
//                .frame(width: 40)
//            
//            Image(systemName: "wind")
//                .frame(width: 40)
//            
//            Image(systemName: "eye")
//                .frame(width: 40)
//            
//            Image(systemName: "arrow.down.to.line")
//                .frame(width: 40)
//        }
//        .font(.caption)
//        .foregroundColor(.secondary)
//        .padding(.vertical, 8)
//        .padding(.horizontal, 4)
//        .background(Color(UIColor.systemBlue).opacity(0.1))
//        .cornerRadius(8)
//    }
//}
//
//struct DailyForecastRowView: View {
//    let forecast: DailyForecastItem
//    let isExpanded: Bool
//    let isToday: Bool
//    
//    var body: some View {
//        VStack(spacing: 0) {
//            // Main row content
//            HStack(alignment: .center) {
//                // Date column
//                VStack(alignment: .leading, spacing: 2) {
//                    Text(forecast.dayOfWeek)
//                        .font(.headline)
//                        .fontWeight(.bold)
//                    
//                    Text(forecast.dateDisplay)
//                        .font(.caption)
//                        .foregroundColor(.secondary)
//                    
//                    if isToday {
//                        Text("TODAY")
//                            .font(.caption2)
//                            .fontWeight(.semibold)
//                            .foregroundColor(.blue)
//                    }
//                }
//                .frame(width: 60, alignment: .leading)
//                
//                // Temperature column
//                VStack(spacing: 4) {
//                    TemperaturePill(
//                        temperature: Int(forecast.high.rounded()),
//                        isHigh: true
//                    )
//                    
//                    TemperaturePill(
//                        temperature: Int(forecast.low.rounded()),
//                        isHigh: false
//                    )
//                }
//                .frame(width: 60)
//                
//                // Moon phase column
//                VStack(spacing: 6) {
//                    moonPhaseIcon
//                        .frame(width: 24, height: 24)
//                    
//                    Image(systemName: forecast.isWaxingMoon ? "arrow.up" : "arrow.down")
//                        .foregroundColor(forecast.isWaxingMoon ? .green : .red)
//                        .font(.caption)
//                }
//                .frame(width: 40)
//                
//                // Wind column
//                VStack(alignment: .center, spacing: 2) {
//                    Text(forecast.windDirection)
//                        .font(.caption)
//                    
//                    Text("\(Int(forecast.windSpeed))")
//                        .font(.caption)
//                    
//                    Text("\(Int(forecast.windGusts))")
//                        .font(.caption2)
//                        .foregroundColor(.secondary)
//                }
//                .frame(width: 40)
//                
//                // Visibility column
//                VStack(alignment: .center, spacing: 4) {
//                    Text(forecast.visibility)
//                        .font(.caption)
//                    
//                    weatherIcon
//                        .frame(width: 24, height: 24)
//                }
//                .frame(width: 40)
//                
//                // Pressure column
//                VStack(alignment: .center, spacing: 2) {
//                    Text(String(format: "%.1f", forecast.pressure))
//                        .font(.caption)
//                    
//                    Text("inHg")
//                        .font(.caption2)
//                        .foregroundColor(.secondary)
//                }
//                .frame(width: 40)
//            }
//            .padding(.vertical, 8)
//            .background(
//                isToday ?
//                    Color.green.opacity(0.1) :
//                    (forecast.rowIndex % 2 == 0 ?
//                        Color(UIColor.secondarySystemBackground) :
//                        Color.clear)
//            )
//            
//            // Expanded details
//            if isExpanded {
//                VStack(alignment: .leading, spacing: 8) {
//                    Text("Tap for hourly forecast")
//                        .font(.callout)
//                        .foregroundColor(.secondary)
//                        .padding(.top, 4)
//                    
//                    if !forecast.description.isEmpty {
//                        Text(forecast.description)
//                            .font(.callout)
//                            .foregroundColor(.primary)
//                    }
//                }
//                .frame(maxWidth: .infinity, alignment: .leading)
//                .padding()
//                .background(Color(UIColor.systemGray6))
//                .transition(.scale.combined(with: .opacity))
//            }
//        }
//        .cornerRadius(8)
//    }
//    
//    // Dynamic weather icon based on weather code
//    private var weatherIcon: some View {
//        Group {
//            if forecast.weatherImage.contains("sun") {
//                Image(systemName: "sun.max.fill")
//                    .foregroundColor(.yellow)
//            } else if forecast.weatherImage.contains("fewclouds") {
//                Image(systemName: "cloud.sun.fill")
//                    .foregroundColor(.gray)
//            } else if forecast.weatherImage.contains("cloud") || forecast.weatherImage.contains("overcast") {
//                Image(systemName: "cloud.fill")
//                    .foregroundColor(.gray)
//            } else if forecast.weatherImage.contains("rain") || forecast.weatherImage.contains("drizzle") {
//                Image(systemName: "cloud.rain.fill")
//                    .foregroundColor(.blue)
//            } else if forecast.weatherImage.contains("snow") {
//                Image(systemName: "snowflake")
//                    .foregroundColor(.cyan)
//            } else if forecast.weatherImage.contains("storm") || forecast.weatherImage.contains("thunder") {
//                Image(systemName: "cloud.bolt.fill")
//                    .foregroundColor(.purple)
//            } else if forecast.weatherImage.contains("fog") {
//                Image(systemName: "cloud.fog.fill")
//                    .foregroundColor(.gray)
//            } else {
//                Image(systemName: "questionmark.circle")
//                    .foregroundColor(.gray)
//            }
//        }
//    }
//    
//    // Dynamic moon phase icon
//    private var moonPhaseIcon: some View {
//        Group {
//            if forecast.moonPhaseIcon.contains("newmoon") {
//                Image(systemName: "moonphase.new.moon")
//                    .foregroundColor(.indigo)
//            } else if forecast.moonPhaseIcon.contains("waxingcrescent") {
//                Image(systemName: "moonphase.waxing.crescent")
//                    .foregroundColor(.indigo)
//            } else if forecast.moonPhaseIcon.contains("firstquarter") {
//                Image(systemName: "moonphase.first.quarter")
//                    .foregroundColor(.indigo)
//            } else if forecast.moonPhaseIcon.contains("waxinggibbous") {
//                Image(systemName: "moonphase.waxing.gibbous")
//                    .foregroundColor(.indigo)
//            } else if forecast.moonPhaseIcon.contains("fullmoon") {
//                Image(systemName: "moonphase.full.moon")
//                    .foregroundColor(.indigo)
//            } else if forecast.moonPhaseIcon.contains("waninggibbous") {
//                Image(systemName: "moonphase.waning.gibbous")
//                    .foregroundColor(.indigo)
//            } else if forecast.moonPhaseIcon.contains("lastquarter") {
//                Image(systemName: "moonphase.last.quarter")
//                    .foregroundColor(.indigo)
//            } else if forecast.moonPhaseIcon.contains("waningcrescent") {
//                Image(systemName: "moonphase.waning.crescent")
//                    .foregroundColor(.indigo)
//            } else {
//                Image(systemName: "moonphase.new.moon")
//                    .foregroundColor(.indigo)
//            }
//        }
//    }
//}
//
//struct TemperaturePill: View {
//    let temperature: Int
//    let isHigh: Bool
//    
//    var body: some View {
//        Text("\(temperature)°")
//            .font(.caption)
//            .fontWeight(.medium)
//            .foregroundColor(.white)
//            .padding(.horizontal, 8)
//            .padding(.vertical, 4)
//            .background(
//                RoundedRectangle(cornerRadius: 4)
//                    .fill(isHigh ? Color.green : Color.blue)
//            )
//            .frame(width: 40)
//    }
//}



























import SwiftUI

struct DailyForecastView: View {
    let forecasts: [DailyForecastItem]
    let onForecastSelected: (DailyForecastItem) -> Void
    
    @State private var expandedForecastId: UUID? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            Text("7-DAY FORECAST")
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.vertical, 4)
            
            // Forecast header row
            ForecastHeaderRow()
            
            // Forecast items
            if forecasts.isEmpty {
                Text("No forecast data available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(forecasts) { forecast in
                    DailyForecastRowView(
                        forecast: forecast,
                        isExpanded: forecast.id == expandedForecastId,
                        isToday: forecast.isToday
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            if expandedForecastId == forecast.id {
                                expandedForecastId = nil
                            } else {
                                expandedForecastId = forecast.id
                            }
                        }
                        
                        // Also trigger the navigation callback
                        onForecastSelected(forecast)
                    }
                    
                    if forecast.id != forecasts.last?.id {
                        Divider()
                            .padding(.leading)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.tertiarySystemBackground))
                .shadow(radius: 2)
        )
    }
}

struct ForecastHeaderRow: View {
    var body: some View {
        HStack {
            Text("Date")
                .frame(width: 60, alignment: .leading)
            
            Image(systemName: "thermometer")
                .frame(width: 60)
                .foregroundColor(.orange)
            
            Image(systemName: "moon.stars")
                .frame(width: 40)
                .foregroundColor(.yellow)
            
            Image(systemName: "wind")
                .frame(width: 40)
                .foregroundColor(.blue)
            
            Image(systemName: "eye")
                .frame(width: 40)
                .foregroundColor(.green)
            
            Image(systemName: "arrow.down.to.line")
                .frame(width: 40)
                .foregroundColor(.purple)
        }
        .font(.caption)
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(Color(UIColor.systemBlue).opacity(0.1))
        .cornerRadius(8)
    }
}

struct DailyForecastRowView: View {
    let forecast: DailyForecastItem
    let isExpanded: Bool
    let isToday: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Main row content
            HStack(alignment: .center) {
                // Date column
                VStack(alignment: .leading, spacing: 2) {
                    Text(forecast.dayOfWeek)
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Text(forecast.dateDisplay)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if isToday {
                        Text("TODAY")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                }
                .frame(width: 60, alignment: .leading)
                
                // Temperature column
                VStack(spacing: 4) {
                    TemperaturePill(
                        temperature: Int(forecast.high.rounded()),
                        isHigh: true
                    )
                    
                    TemperaturePill(
                        temperature: Int(forecast.low.rounded()),
                        isHigh: false
                    )
                }
                .frame(width: 60)
                
                // Moon phase column
                VStack(spacing: 6) {
                    moonPhaseIcon
                        .frame(width: 24, height: 24)
                    
                    Image(systemName: forecast.isWaxingMoon ? "arrow.up" : "arrow.down")
                        .foregroundColor(forecast.isWaxingMoon ? .green : .red)
                        .font(.caption)
                }
                .frame(width: 40)
                
                // Wind column
                VStack(alignment: .center, spacing: 2) {
                    Text(forecast.windDirection)
                        .font(.caption)
                    
                    Text("\(Int(forecast.windSpeed))")
                        .font(.caption)
                    
                    Text("\(Int(forecast.windGusts))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(width: 40)
                
                // Visibility column
                VStack(alignment: .center, spacing: 4) {
                    Text(forecast.visibility)
                        .font(.caption)
                    
                    weatherIcon
                        .frame(width: 24, height: 24)
                }
                .frame(width: 40)
                
                // Pressure column
                VStack(alignment: .center, spacing: 2) {
                    Text(String(format: "%.1f", forecast.pressure))
                        .font(.caption)
                    
                    Text("inHg")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(width: 40)
            }
            .padding(.vertical, 8)
            .background(
                isToday ?
                    Color.green.opacity(0.1) :
                    (forecast.rowIndex % 2 == 0 ?
                        Color(UIColor.secondarySystemBackground) :
                        Color.clear)
            )
            
            // Expanded details
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tap for hourly forecast")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                    
                    if !forecast.description.isEmpty {
                        Text(forecast.description)
                            .font(.callout)
                            .foregroundColor(.primary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(UIColor.systemGray6))
                .transition(.scale.combined(with: .opacity))
            }
        }
        .cornerRadius(8)
    }
    
    // Dynamic weather icon based on weather code
    private var weatherIcon: some View {
        Group {
            if forecast.weatherImage.contains("sun") {
                Image(systemName: "sun.max.fill")
                    .foregroundColor(.yellow)
            } else if forecast.weatherImage.contains("fewclouds") {
                Image(systemName: "cloud.sun.fill")
                    .foregroundColor(.gray)
            } else if forecast.weatherImage.contains("cloud") || forecast.weatherImage.contains("overcast") {
                Image(systemName: "cloud.fill")
                    .foregroundColor(.gray)
            } else if forecast.weatherImage.contains("rain") || forecast.weatherImage.contains("drizzle") {
                Image(systemName: "cloud.rain.fill")
                    .foregroundColor(.blue)
            } else if forecast.weatherImage.contains("snow") {
                Image(systemName: "snowflake")
                    .foregroundColor(.cyan)
            } else if forecast.weatherImage.contains("storm") || forecast.weatherImage.contains("thunder") {
                Image(systemName: "cloud.bolt.fill")
                    .foregroundColor(.purple)
            } else if forecast.weatherImage.contains("fog") {
                Image(systemName: "cloud.fog.fill")
                    .foregroundColor(.gray)
            } else {
                Image(systemName: "questionmark.circle")
                    .foregroundColor(.gray)
            }
        }
    }
    
    // Dynamic moon phase icon
    private var moonPhaseIcon: some View {
        Group {
            if forecast.moonPhaseIcon.contains("newmoon") {
                Image(systemName: "moonphase.new.moon")
                    .foregroundColor(.indigo)
            } else if forecast.moonPhaseIcon.contains("waxingcrescent") {
                Image(systemName: "moonphase.waxing.crescent")
                    .foregroundColor(.indigo)
            } else if forecast.moonPhaseIcon.contains("firstquarter") {
                Image(systemName: "moonphase.first.quarter")
                    .foregroundColor(.indigo)
            } else if forecast.moonPhaseIcon.contains("waxinggibbous") {
                Image(systemName: "moonphase.waxing.gibbous")
                    .foregroundColor(.indigo)
            } else if forecast.moonPhaseIcon.contains("fullmoon") {
                Image(systemName: "moonphase.full.moon")
                    .foregroundColor(.indigo)
            } else if forecast.moonPhaseIcon.contains("waninggibbous") {
                Image(systemName: "moonphase.waning.gibbous")
                    .foregroundColor(.indigo)
            } else if forecast.moonPhaseIcon.contains("lastquarter") {
                Image(systemName: "moonphase.last.quarter")
                    .foregroundColor(.indigo)
            } else if forecast.moonPhaseIcon.contains("waningcrescent") {
                Image(systemName: "moonphase.waning.crescent")
                    .foregroundColor(.indigo)
            } else {
                Image(systemName: "moonphase.new.moon")
                    .foregroundColor(.indigo)
            }
        }
    }
}

struct TemperaturePill: View {
    let temperature: Int
    let isHigh: Bool
    
    var body: some View {
        Text("\(temperature)°")
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isHigh ? Color.green : Color.blue)
            )
            .frame(width: 40)
    }
}
