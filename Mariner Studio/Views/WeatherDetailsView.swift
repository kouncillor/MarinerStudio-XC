
import SwiftUI

struct WeatherDetailsView: View {
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
                // Wind - using SF Symbol with blue color
                DetailRow(
                    iconSource: .system("wind", .blue),
                    title: "Wind",
                    subtitle: windDirection,
                    value: windSpeed
                )
                
                // Gusts - using custom image with red color
                DetailRow(
                    iconSource: .system("wind", .red),
                    title: "Gusts",
                    value: windGusts
                )
                
                // Visibility - using SF Symbol with green color
                DetailRow(
                    iconSource: .custom("visibilitysixseven"),
                    title: "Visibility",
                    value: visibility
                )
                
                // Pressure - using SF Symbol with purple color
                DetailRow(
                    iconSource: .custom("pressuresixseven", .purple),
                    title: "Pressure",
                    value: "\(pressure)\""
                )
                
                // Humidity - using SF Symbol with cyan color
                DetailRow(
                    iconSource: .system("humidity", .cyan),
                    title: "Humidity",
                    value: "\(humidity)%"
                )
                
                // Dew Point - using SF Symbol with orange color
                DetailRow(
                    iconSource: .system("drop", .orange),
                    title: "Dew Point",
                    value: "\(dewPoint)°"
                )
                
                // Precipitation - using SF Symbol with default color
                DetailRow(
                    iconSource: .system("cloud.rain"),
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

struct DetailRow: View {
    let iconSource: IconSource
    let title: String
    var subtitle: String? = nil
    let value: String
    
    var body: some View {
        HStack {
            // Display either SF Symbol or custom image based on iconSource
            Group {
                switch iconSource {
                case .system(let name, let color):
                    Image(systemName: name)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(color ?? .primary.opacity(0.8))
                case .custom(let name, let color):
                    Image(name)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(color ?? .primary.opacity(0.8))
                }
            }
            .frame(width: 24, height: 24)
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


