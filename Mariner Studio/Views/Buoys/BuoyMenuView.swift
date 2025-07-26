//
//  BuoyMenuView.swift
//  Mariner Studio
//
//  Created by Timothy Russell on 5/15/25.
//


import SwiftUI

struct BuoyMenuView: View {
    // We'll use environment objects for service dependencies
    @EnvironmentObject var serviceProvider: ServiceProvider

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Favorites - Star Icon
                NavigationLink(destination: BuoyFavoritesView(
                    buoyFavoritesCloudService: serviceProvider.buoyFavoritesCloudService
                )) {
                    MenuButtonContentBuoy(
                        iconType: .system("star.fill"),
                        title: "FAVORITES",
                        color: .yellow
                    )
                }
                
                // Local Buoys - System Icon
                NavigationLink(destination: BuoyStationsView(
                    buoyService: BuoyServiceImpl(),
                    locationService: serviceProvider.locationService,
                    buoyFavoritesCloudService: serviceProvider.buoyFavoritesCloudService
                )) {
                    MenuButtonContentBuoy(
                        iconType: .system("location.fill"),
                        title: "LOCAL",
                        color: .green
                    )
                }
            }
            .padding()
        }
        .navigationTitle("Buoys")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.purple, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .withHomeButton()
        
    }
}

// Menu button content, following the pattern from other menu views
struct MenuButtonContentBuoy: View {
    // Enum to define icon type
    enum IconType {
        case system(String) // Holds SF Symbol name
        case custom(String) // Holds custom Asset name
    }

    let iconType: IconType 
    let title: String
    let color: Color

    var body: some View {
        HStack {
            // Create the correct image based on type
            Group {
                 switch iconType {
                 case .system(let name):
                     Image(systemName: name)
                         .resizable()
                         .aspectRatio(contentMode: .fit)
                         .foregroundColor(color)
                 case .custom(let name):
                     Image(name)
                         .resizable()
                         .aspectRatio(contentMode: .fit)
                         .foregroundColor(color)
                 }
            }
            .frame(width: 40, height: 40)
            .padding(.horizontal, 20)

            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .padding(.trailing, 10)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
}
