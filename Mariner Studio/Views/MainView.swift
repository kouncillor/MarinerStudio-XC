import SwiftUI

struct MainView: View {
    @StateObject private var databaseService = DatabaseServiceImpl.getInstance()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // MAP
                    NavigationButton(
                        icon: "earthsixfour",
                        title: "MAP",
                        action: { print("Map tapped") }
                    )
                    
                    // WEATHER
                    NavigationButton(
                        icon: "weathersixseventwo",
                        title: "WEATHER",
                        action: { print("Weather tapped") }
                    )
                    
                    // TIDES
                    NavigationLink(destination: TidalHeightStationsView(databaseService: databaseService)) {
                        NavigationButtonContent(
                            icon: "tsixseven",
                            title: "TIDES"
                        )
                    }
                    
                    // CURRENTS
                    NavigationLink(destination: TidalCurrentStationsView(databaseService: databaseService)) {
                        NavigationButtonContent(
                            icon: "csixseven",
                            title: "CURRENTS"
                        )
                    }
                    
                    // NAV UNITS
                    NavigationLink(destination: NavUnitsView(databaseService: databaseService)) {
                        NavigationButtonContent(
                            icon: "nsixseven",
                            title: "NAV UNITS"
                        )
                    }
                    
                    // BUOYS
                    NavigationButton(
                        icon: "buoysixseven",
                        title: "BUOYS",
                        action: { print("Buoys tapped") }
                    )
                    
                    // TUGS
                    NavigationButton(
                        icon: "tugboatsixseven",
                        title: "TUGS",
                        action: { print("Tugs tapped") }
                    )
                    
                    // BARGES
                    NavigationButton(
                        icon: "bargesixseventwo",
                        title: "BARGES",
                        action: { print("Barges tapped") }
                    )
                    
                    // ROUTE
                    RouteButton(action: { print("Route tapped") })
                }
                .padding()
            }
            .navigationTitle("Mariner Studio")
        }
    }
}

struct NavigationButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            NavigationButtonContent(icon: icon, title: title)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct NavigationButtonContent: View {
    let icon: String
    let title: String
    
    var body: some View {
        HStack {
            Image(icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 67, height: 67)
                .padding(.leading, 5)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.largeTitle)
            }
            .padding(.leading, 20)
            .frame(height: 67)
            .padding(.vertical, 10)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color(UIColor.lightGray), lineWidth: 1)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
        )
    }
}

struct RouteButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image("tsixseven")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 67, height: 67)
                    .padding(.leading, 5)
                
                VStack(alignment: .leading) {
                    Text("Route")
                        .font(.headline)
                    Text("View Route from GPX File")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.leading, 10)
                .frame(height: 67)
                .padding(.vertical, 10)
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color(UIColor.lightGray), lineWidth: 1)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    MainView()
}
