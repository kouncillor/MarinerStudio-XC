

import SwiftUI

struct TugsView: View {
    // MARK: - Properties
    @StateObject private var viewModel: TugsViewModel
    @State private var isRefreshing = false
    
    // MARK: - Initialization
    init(vesselService: VesselDatabaseService) {
        _viewModel = StateObject(wrappedValue: TugsViewModel(
            vesselService: vesselService
        ))
    }
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            searchBar
            
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
                    tugsList
                }
            }
        }
        .navigationTitle("Tugs")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color(red: 0.53, green: 0.81, blue: 0.98), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .withHomeButton()
        
        .task {
            await viewModel.loadTugs()
        }
    }
    
    // MARK: - View Components
    private var searchBar: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search tugs...", text: $viewModel.searchText)
                    .onChange(of: viewModel.searchText) {
                        viewModel.filterTugs()
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
    
    private var tugsList: some View {
        List {
            ForEach(viewModel.tugs) { tug in
                NavigationLink(destination: TugDetailsView(
                    tug: tug,
                    vesselService: viewModel.vesselService
                )) {
                    TugRow(tug: tug)
                }
            }
        }
        .listStyle(PlainListStyle())
        .refreshable {
            await viewModel.refreshTugs()
        }
    }
}

struct TugRow: View {
    let tug: Tug
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(tug.vesselName)
                .font(.headline)
            
            Text("Tug ID: \(tug.tugId)")
                .font(.caption)
                .foregroundColor(.gray)
            
            // Add more details here as needed
        }
        .padding(.vertical, 5)
    }
}
