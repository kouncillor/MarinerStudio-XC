
import SwiftUI

struct WeatherDetailsForMapView: View {
    let windSpeed: String
    let windDirection: String
    let windGusts: String
    let visibility: String
    let pressure: String
    let humidity: String
    let dewPoint: String
    let precipitation: String
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Current Conditions")
                .font(.headline)
                .padding(.top, 8)
            
            Divider()
            
            // Weather detail grid
            VStack(spacing: 25) {
                // Wind
                DetailRowForMap(
                    icon: "wind",
                    title: "Wind",
                    subtitle: windDirection,
                    value: windSpeed
                )
                
                // Gusts
                DetailRowForMap(
                    icon: "wind.snow",
                    title: "Gusts",
                    value: windGusts
                )
                
                // Visibility
                DetailRowForMap(
                    icon: "eye",
                    title: "Visibility",
                    value: visibility
                )
                
                // Pressure
                DetailRowForMap(
                    icon: "arrow.down.to.line",
                    title: "Pressure",
                    value: "\(pressure)\""
                )
                
                // Humidity
                DetailRowForMap(
                    icon: "humidity",
                    title: "Humidity",
                    value: "\(humidity)%"
                )
                
                // Dew Point
                DetailRowForMap(
                    icon: "drop",
                    title: "Dew Point",
                    value: "\(dewPoint)°"
                )
                
                // Precipitation
                DetailRowForMap(
                    icon: "cloud.rain",
                    title: "24-hr Precip Estimate",
                    value: "\(precipitation) in"
                )
            }
            .padding()
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.tertiarySystemBackground))
                .shadow(radius: 2)
        )
    }
}

struct DetailRowForMap: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
                .foregroundColor(.primary.opacity(0.8))
                .padding(.trailing, 16)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Text(value)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}

struct WeatherDetailsForMapView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            WeatherDetailsForMapView(
                windSpeed: "10 mph",
                windDirection: "from N",
                windGusts: "15 mph",
                visibility: "10 mi",
                pressure: "30.12",
                humidity: "65",
                dewPoint: "55.1",
                precipitation: "0.25"
            )
            .padding()
        }
        .background(Color(UIColor.systemGroupedBackground))
    }
}
