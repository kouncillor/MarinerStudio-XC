//
//  ImportPersonalRoutesView.swift
//  Mariner Studio
//
//  Created for importing personal route files from various sources.
//

import SwiftUI

struct ImportPersonalRoutesView: View {
    @StateObject private var viewModel: ImportPersonalRoutesViewModel
    
    init(allRoutesService: AllRoutesDatabaseService? = nil, gpxService: ExtendedGpxServiceProtocol? = nil, routeCalculationService: RouteCalculationService? = nil) {
        _viewModel = StateObject(wrappedValue: ImportPersonalRoutesViewModel(
            allRoutesService: allRoutesService,
            gpxService: gpxService,
            routeCalculationService: routeCalculationService
        ))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                headerView
                
                // Import Options
                importOptionsView
                
                // Recent Imports
                if !viewModel.importedRoutes.isEmpty {
                    recentImportsView
                }
                
                Spacer()
                
                // Messages
                messagesView
            }
            .padding()
            .navigationTitle("Import Routes")
            .navigationBarTitleDisplayMode(.large)
            .withHomeButton()
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.fill.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.purple)
            
            Text("Import Personal Routes")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Import route files from your device, cloud storage, or other apps")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical)
    }
    
    // MARK: - Import Options
    
    private var importOptionsView: some View {
        VStack(spacing: 16) {
            Text("Import Sources")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // File Picker Option
            importOptionCard(
                icon: "doc.fill",
                title: "Files & Cloud Storage",
                subtitle: "Browse files from your device, iCloud, OneDrive, Dropbox, and more",
                iconColor: .blue,
                action: {
                    viewModel.importRouteFromFilePicker()
                }
            )
            
            // Future import options can be added here
            // For example: URL import, QR code import, etc.
        }
    }
    
    private func importOptionCard(icon: String, title: String, subtitle: String, iconColor: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(iconColor)
                    .frame(width: 40, height: 40)
                    .background(iconColor.opacity(0.1))
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                if viewModel.isImporting {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .disabled(viewModel.isImporting)
    }
    
    // MARK: - Recent Imports
    
    private var recentImportsView: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Recent Imports")
                    .font(.headline)
                
                Spacer()
                
                Text("\(viewModel.importedRoutes.count) imported")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 8) {
                ForEach(viewModel.importedRoutes.reversed(), id: \.self) { routeName in
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        
                        Text(routeName)
                            .font(.caption)
                        
                        Spacer()
                        
                        Text("Imported")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
    }
    
    // MARK: - Messages
    
    private var messagesView: some View {
        VStack(spacing: 8) {
            // Success message
            if !viewModel.successMessage.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(.green)
                    
                    Text(viewModel.successMessage)
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    Spacer()
                    
                    Button("Dismiss") {
                        viewModel.clearMessages()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Error message
            if !viewModel.errorMessage.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.red)
                    
                    Text(viewModel.errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                    
                    Spacer()
                    
                    Button("Dismiss") {
                        viewModel.clearMessages()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Loading indicator
            if viewModel.isImporting {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    
                    Text("Importing route...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ImportPersonalRoutesView()
}