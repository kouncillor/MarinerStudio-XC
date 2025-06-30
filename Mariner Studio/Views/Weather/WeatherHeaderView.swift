import SwiftUI

struct WeatherHeaderView: View {
    let temperature: String
    let feelsLike: String
    let weatherDescription: String
    let weatherImage: String
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 16) {
            // Main weather display with temperature and icon
            HStack(alignment: .center, spacing: 24) {
                // Weather icon
                weatherIcon
                    .frame(width: 80, height: 80)
                    .padding(.leading, 20)
                
                // Temperature display
                Text("\(temperature)°")
                    .font(.system(size: 72, weight: .medium))
                    .foregroundColor(.orange)
                
                // Temperature symbol icon
                Image(systemName: "thermometer")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                    .foregroundColor(.orange.opacity(0.8))
                    .padding(.horizontal, 5)
            }
            
            // Feels like temperature
            Text("FEELS LIKE \(feelsLike)°")
                .font(.headline)
                .foregroundColor(.secondary)
            
            // Weather description
            Text(weatherDescription)
                .font(.title2)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.tertiarySystemBackground))
                .shadow(radius: 2)
        )
    }
    
    // Dynamically generate weather icon based on the image name
    private var weatherIcon: some View {
        Group {
            if weatherImage.contains("sun") {
                Image(systemName: "sun.max.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.yellow)
            } else if weatherImage.contains("moon") {
                Image(systemName: "moon.stars.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.indigo)
            } else if weatherImage.contains("rain") || weatherImage.contains("drizzle") {
                Image(systemName: "cloud.rain.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.blue)
            } else if weatherImage.contains("snow") {
                Image(systemName: "snow")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.cyan)
            } else if weatherImage.contains("cloud") {
                Image(systemName: "cloud.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.gray)
            } else if weatherImage.contains("storm") || weatherImage.contains("thunder") {
                Image(systemName: "cloud.bolt.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.purple)
            } else if weatherImage.contains("fog") {
                Image(systemName: "cloud.fog.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.gray)
            } else {
                // Default icon
                Image(systemName: "questionmark.circle")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.gray)
            }
        }
    }
}

#Preview {
    VStack {
        WeatherHeaderView(
            temperature: "72",
            feelsLike: "75",
            weatherDescription: "Partly Cloudy",
            weatherImage: "fewcloudssixseven"
        )
        .padding()
        
        WeatherHeaderView(
            temperature: "32",
            feelsLike: "28",
            weatherDescription: "Snow Showers",
            weatherImage: "snowsixseven"
        )
        .padding()
    }
    .background(Color(UIColor.systemGroupedBackground))
}
