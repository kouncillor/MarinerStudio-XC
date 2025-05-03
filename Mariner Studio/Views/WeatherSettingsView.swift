import SwiftUI

/// View for weather-related settings
struct WeatherSettingsView: View {
    // MARK: - Properties
    @AppStorage("useMetricUnits") private var useMetricUnits = false
    @AppStorage("showHourlyDetails") private var showHourlyDetails = true
    @AppStorage("defaultWeatherTab") private var defaultWeatherTab = 0
    @AppStorage("alertsEnabled") private var alertsEnabled = true
    @AppStorage("autoRefreshEnabled") private var autoRefreshEnabled = true
    @AppStorage("autoRefreshInterval") private var autoRefreshInterval = 30 // minutes
    
    // MARK: - Body
    var body: some View {
        Form {
            // Units Section
            Section(header: Text("Units")) {
                Toggle("Use Metric Units", isOn: $useMetricUnits)
                    .onChange(of: useMetricUnits) { newValue in
                        // Would notify other parts of the app that the units preference changed
                        NotificationCenter.default.post(
                            name: Notification.Name("UnitsPreferenceChanged"),
                            object: nil,
                            userInfo: ["useMetricUnits": newValue]
                        )
                    }
                
                if useMetricUnits {
                    Text("Temperature: °C, Wind: km/h, Precipitation: mm")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Temperature: °F, Wind: mph, Precipitation: in")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Display Options Section
            Section(header: Text("Display Options")) {
                Toggle("Show Hourly Details", isOn: $showHourlyDetails)
                
                Picker("Default View", selection: $defaultWeatherTab) {
                    Text("Current").tag(0)
                    Text("Hourly").tag(1)
                    Text("Daily").tag(2)
                    Text("Map").tag(3)
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            // Weather Alerts Section
            Section(header: Text("Weather Alerts")) {
                Toggle("Enable Weather Alerts", isOn: $alertsEnabled)
                
                if alertsEnabled {
                    NavigationLink(destination: AlertSettingsView()) {
                        Text("Configure Alert Types")
                    }
                }
            }
            
            // Refresh Settings Section
            Section(header: Text("Refresh Settings")) {
                Toggle("Auto-Refresh Weather Data", isOn: $autoRefreshEnabled)
                
                if autoRefreshEnabled {
                    Picker("Refresh Interval", selection: $autoRefreshInterval) {
                        Text("15 minutes").tag(15)
                        Text("30 minutes").tag(30)
                        Text("1 hour").tag(60)
                        Text("3 hours").tag(180)
                    }
                    .pickerStyle(DefaultPickerStyle())
                }
            }
            
            // Data Sources Section
            Section(header: Text("Data Sources")) {
                NavigationLink(destination: DataSourceInfoView()) {
                    Text("About Weather Data")
                }
                
                Button(action: {
                    // Would open the Open-Meteo website
                    UIApplication.shared.open(URL(string: "https://open-meteo.com/")!)
                }) {
                    HStack {
                        Text("Visit Open-Meteo")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                    }
                }
            }
            
            // About Section
            Section(header: Text("About")) {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Weather Settings")
    }
}

/// View for configuring alert settings
struct AlertSettingsView: View {
    @AppStorage("alertSevereStorms") private var alertSevereStorms = true
    @AppStorage("alertExtremeTemperatures") private var alertExtremeTemperatures = true
    @AppStorage("alertFlood") private var alertFlood = true
    @AppStorage("alertWind") private var alertWind = true
    @AppStorage("alertSnow") private var alertSnow = true
    
    var body: some View {
        Form {
            Toggle("Severe Storms", isOn: $alertSevereStorms)
            Toggle("Extreme Temperatures", isOn: $alertExtremeTemperatures)
            Toggle("Flooding", isOn: $alertFlood)
            Toggle("High Winds", isOn: $alertWind)
            Toggle("Snow & Ice", isOn: $alertSnow)
            
            Section(header: Text("Alert Radius")) {
                Slider(value: .constant(50), in: 10...100, step: 5) {
                    Text("50 miles")
                } minimumValueLabel: {
                    Text("10")
                } maximumValueLabel: {
                    Text("100")
                }
            }
        }
        .navigationTitle("Alert Settings")
    }
}

/// View for showing information about data sources
struct DataSourceInfoView: View {
    var body: some View {
        List {
            Section(header: Text("Primary Data Source")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Open-Meteo")
                        .font(.headline)
                    
                    Text("Open-Meteo is an open-source weather API offering free access to weather forecast data. The service combines multiple data sources into a single easy-to-use API.")
                        .font(.body)
                    
                    Text("Data is sourced from various weather models including NOAA GFS, DWD ICON, and ECMWF IFS.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
            
            Section(header: Text("Weather Models")) {
                DataSourceRow(
                    name: "GFS (Global Forecast System)",
                    description: "NOAA's operational weather prediction system providing medium-range forecasts",
                    updateFrequency: "4 times daily"
                )
                
                DataSourceRow(
                    name: "ICON (Icosahedral Nonhydrostatic)",
                    description: "German weather service's global numerical weather prediction model",
                    updateFrequency: "4 times daily"
                )
                
                DataSourceRow(
                    name: "ECMWF (European Centre for Medium-Range Weather Forecasts)",
                    description: "Weather prediction model known for accuracy in medium-range forecasts",
                    updateFrequency: "2 times daily"
                )
            }
            
            Section(header: Text("Terms of Use")) {
                Text("Weather data is provided for personal use only. Open-Meteo data is available under Attribution 4.0 International (CC BY 4.0) license.")
                    .font(.caption)
            }
        }
        .navigationTitle("Data Sources")
    }
}

/// Reusable row for displaying data source information
struct DataSourceRow: View {
    let name: String
    let description: String
    let updateFrequency: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(name)
                .font(.headline)
            
            Text(description)
                .font(.body)
                .foregroundColor(.primary)
            
            HStack {
                Text("Updates:")
                    .font(.caption)
                    .fontWeight(.bold)
                
                Text(updateFrequency)
                    .font(.caption)
            }
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 5)
    }
}

#Preview {
    NavigationView {
        WeatherSettingsView()
    }
}
