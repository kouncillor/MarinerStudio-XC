//
//  RoutesMenuView.swift
//  Mariner Studio
//
//  Created by Timothy Russell on 5/22/25.
//


import SwiftUI

struct RoutesMenuView: View {
    // We'll use environment objects for service dependencies
    @EnvironmentObject var serviceProvider: ServiceProvider

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Favorites - Star Icon
                NavigationLink(destination: Text("Route Favorites - Coming Soon")) {
                    MenuButtonContentRoutes(
                        iconType: .system("star.fill"),
                        title: "FAVORITES",
                        color: .yellow
                    )
                }
                
                // Load GPX File - Document Icon
                NavigationLink(destination: Text("Load GPX File - Coming Soon")) {
                    MenuButtonContentRoutes(
                        iconType: .system("doc.badge.plus"),
                        title: "LOAD GPX FILE",
                        color: .blue
                    )
                }
                
                // Create New Route - Plus Icon
                NavigationLink(destination: Text("Create New Route - Coming Soon")) {
                    MenuButtonContentRoutes(
                        iconType: .system("plus.circle.fill"),
                        title: "CREATE NEW ROUTE",
                        color: .green
                    )
                }
            }
            .padding()
        }
        .navigationTitle("Routes")
        .withHomeButton()
    }
}

// Creating a MenuButtonContent structure specifically for Routes to avoid conflicts
struct MenuButtonContentRoutes: View {
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

#Preview {
    NavigationView {
        RoutesMenuView()
            .environmentObject(ServiceProvider())
    }
}