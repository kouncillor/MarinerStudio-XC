//
//  VoyagePlanMenuView.swift
//  Mariner Studio
//
//  Created for voyage planning navigation.
//

import SwiftUI

struct VoyagePlanMenuView: View {
    @StateObject private var viewModel = VoyagePlanMenuViewModel()
    @EnvironmentObject var serviceProvider: ServiceProvider
    
    let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                // Favorite Routes
                NavigationLink(destination: VoyagePlanFavoritesView()) {
                    VoyagePlanMenuButtonContent(
                        icon: "star.fill",
                        title: "FAVORITE ROUTES",
                        subtitle: "Plan Voyages with Saved Routes",
                        isSystemIcon: true,
                        iconColor: .yellow
                    )
                }
                
                // All Routes
                NavigationLink(destination: VoyagePlanRoutesView(allRoutesService: serviceProvider.allRoutesService)) {
                    VoyagePlanMenuButtonContent(
                        icon: "list.bullet",
                        title: "ALL ROUTES",
                        subtitle: "Plan Voyages with Any Route",
                        isSystemIcon: true,
                        iconColor: .blue
                    )
                }
            }
            .padding()
            
            // Error message
            if !viewModel.errorMessage.isEmpty {
                Text(viewModel.errorMessage)
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                    .padding()
            }
        }
        .navigationTitle("Voyage Plan")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.green, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .withHomeButton()
        .onAppear {
            print("🗺️ VOYAGE_PLAN_MENU: View appeared")
        }
    }
    
    // MARK: - Helper Methods
    
    /// Placeholder destination for stubbed navigation links
    private func destinationPlaceholder(_ title: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "map")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("\(title) Integration")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("This will navigate to \(title) for voyage planning.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Text("Coming Soon!")
                .font(.headline)
                .foregroundColor(.blue)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
        .withHomeButton()
    }
}

// MARK: - Voyage Plan Menu Button Content

struct VoyagePlanMenuButtonContent: View {
    let icon: String
    let title: String
    let subtitle: String?
    let isSystemIcon: Bool
    let iconColor: Color?

    init(icon: String, title: String, subtitle: String? = nil, isSystemIcon: Bool = false, iconColor: Color? = nil) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
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
                        .frame(width: 50, height: 50)
                        .foregroundColor(iconColor ?? .accentColor)
                } else {
                    Image(icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 55, height: 55)
                }
            }

            VStack(spacing: 2) {
                Text(title)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color(UIColor.lightGray), lineWidth: 1)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
        )
        .frame(minHeight: subtitle != nil ? 140 : 120)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        VoyagePlanMenuView()
            .environmentObject(ServiceProvider())
    }
}