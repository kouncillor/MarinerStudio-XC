//
//  BargesView.swift
//  Mariner Studio
//
//  Created by Timothy Russell on 5/10/25.
//


import SwiftUI

struct BargesView: View {
    // MARK: - Properties
    @StateObject private var viewModel: BargesViewModel
    @State private var isRefreshing = false
    
    // MARK: - Initialization
    init(vesselService: VesselDatabaseService) {
        _viewModel = StateObject(wrappedValue: BargesViewModel(
            vesselService: vesselService
        ))
    }
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            searchBar
            
            // Status Information
            statusBar
            
            // Main Content
            ZStack {
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                } else if !viewModel.errorMessage.isEmpty {
                    Text(viewModel.errorMessage)
                        .foregroundColor(.red)
                        .padding()
                } else {
                    bargesList
                }
            }
        }
        .navigationTitle("Barges")
        .task {
            await viewModel.loadBarges()
        }
    }
    
    // MARK: - View Components
    private var searchBar: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search barges...", text: $viewModel.searchText)
                    .onChange(of: viewModel.searchText) {
                        viewModel.filterBarges()
                    }
                
                if !viewModel.searchText.isEmpty {
                    Button(action: {
                        viewModel.clearSearch()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(8)
            .background(Color(.systemBackground))
            .cornerRadius(10)
            .padding(.trailing, 8)
        }
        .padding([.horizontal, .top])
    }
    
    private var statusBar: some View {
        HStack {
            Text("Total Barges: \(viewModel.totalBarges)")
                .font(.footnote)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.bottom, 5)
    }
    
    private var bargesList: some View {
        List {
            ForEach(viewModel.barges) { barge in
                NavigationLink(destination: BargeDetailsView(
                    barge: barge,
                    vesselService: viewModel.vesselService
                )) {
                    BargeRow(barge: barge)
                }
            }
        }
        .listStyle(PlainListStyle())
        .refreshable {
            await viewModel.refreshBarges()
        }
    }
}

struct BargeRow: View {
    let barge: Barge
    
    // Computed property to format the vessel name with number
    var formattedVesselName: String {
        if let vesselNumber = barge.vesselNumber, !vesselNumber.isEmpty {
            return "\(barge.vesselName)-\(vesselNumber)"
        } else {
            return barge.vesselName
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(formattedVesselName)
                .font(.headline)
            
            Text("Barge ID: \(barge.bargeId)")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 5)
    }
}
