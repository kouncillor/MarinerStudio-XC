//
//  RouteMenuView.swift
//  Mariner Studio
//
//  Created by Timothy Russell on 5/23/25.
//


import SwiftUI

struct RouteMenuView: View {
    @EnvironmentObject var serviceProvider: ServiceProvider
    
    let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                // Open GPX File
                NavigationLink(destination: createGpxView()) {
                    RouteMenuButtonContent(
                        icon: "doc.fill",
                        title: "OPEN GPX FILE",
                        isSystemIcon: true,
                        iconColor: .blue
                    )
                }
                
                // Download Routes
                NavigationLink(destination: DownloadRoutesView()) {
                    RouteMenuButtonContent(
                        icon: "arrow.down.circle.fill",
                        title: "DOWNLOAD ROUTES",
                        isSystemIcon: true,
                        iconColor: .green
                    )
                }
                
                // Create New Route
                NavigationLink(destination: CreateRouteView()) {
                    RouteMenuButtonContent(
                        icon: "plus.circle.fill",
                        title: "CREATE NEW ROUTE",
                        isSystemIcon: true,
                        iconColor: .orange
                    )
                }
            }
            .padding()
        }
        .navigationTitle("Routes")
        .navigationBarTitleDisplayMode(.large)
    }
    
    // Create GPX view with proper services
    private func createGpxView() -> some View {
        let gpxService = GpxServiceImpl()
        let routeCalculationService = RouteCalculationServiceImpl()
        
        let gpxViewModel = GpxViewModel(
            gpxService: gpxService,
            routeCalculationService: routeCalculationService,
            navigationService: { parameters in
                // Handle navigation if needed - can be empty for now
                // since we're not doing the complex route details navigation
            }
        )
        
        return GpxView(viewModel: gpxViewModel)
    }
}

struct RouteMenuButtonContent: View {
    let icon: String
    let title: String
    let isSystemIcon: Bool
    let iconColor: Color?

    init(icon: String, title: String, isSystemIcon: Bool = false, iconColor: Color? = nil) {
        self.icon = icon
        self.title = title
        self.isSystemIcon = isSystemIcon
        self.iconColor = iconColor
    }

    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            Group {
                if isSystemIcon {
                    Image(systemName: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                        .foregroundColor(iconColor ?? .accentColor)
                } else {
                    Image(icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 67, height: 67)
                }
            }

            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color(UIColor.lightGray), lineWidth: 1)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
        )
        .frame(minHeight: 120)
    }
}