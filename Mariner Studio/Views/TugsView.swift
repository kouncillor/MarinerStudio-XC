//
//
//import SwiftUI
//
//struct TugsView: View {
//    // MARK: - Properties
//    @StateObject private var viewModel: TugsViewModel
//    @State private var isRefreshing = false
//    
//    // MARK: - Initialization
//    init(vesselService: VesselDatabaseService) {
//        _viewModel = StateObject(wrappedValue: TugsViewModel(
//            vesselService: vesselService
//        ))
//    }
//    
//    // MARK: - Body
//    var body: some View {
//        VStack(spacing: 0) {
//            // Search Bar
//            searchBar
//            
//            // Status Information
//            statusBar
//            
//            // Main Content
//            ZStack {
//                if viewModel.isLoading {
//                    ProgressView()
//                        .scaleEffect(1.5)
//                } else if !viewModel.errorMessage.isEmpty {
//                    Text(viewModel.errorMessage)
//                        .foregroundColor(.red)
//                        .padding()
//                } else {
//                    tugsList
//                }
//            }
//        }
//        .navigationTitle("Tugs")
//        .task {
//            await viewModel.loadTugs()
//        }
//    }
//    
//    // MARK: - View Components
//    private var searchBar: some View {
//        HStack {
//            HStack {
//                Image(systemName: "magnifyingglass")
//                    .foregroundColor(.gray)
//                
//                TextField("Search tugs...", text: $viewModel.searchText)
//                    .onChange(of: viewModel.searchText) {
//                        viewModel.filterTugs()
//                    }
//                
//                if !viewModel.searchText.isEmpty {
//                    Button(action: {
//                        viewModel.clearSearch()
//                    }) {
//                        Image(systemName: "xmark.circle.fill")
//                            .foregroundColor(.gray)
//                    }
//                }
//            }
//            .padding(8)
//            .background(Color(.systemBackground))
//            .cornerRadius(10)
//            .padding(.trailing, 8)
//        }
//        .padding([.horizontal, .top])
//    }
//    
//    private var statusBar: some View {
//        HStack {
//            Text("Total Tugs: \(viewModel.totalTugs)")
//                .font(.footnote)
//            Spacer()
//        }
//        .padding(.horizontal)
//        .padding(.bottom, 5)
//    }
//    
//    private var tugsList: some View {
//        List {
//            ForEach(viewModel.tugs) { tug in
//                NavigationLink(destination: EmptyView()) {  // Replace with TugDetailsView later
//                    TugRow(tug: tug)
//                }
//            }
//        }
//        .listStyle(PlainListStyle())
//        .refreshable {
//            await viewModel.refreshTugs()
//        }
//    }
//}
//
//struct TugRow: View {
//    let tug: Tug
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 5) {
//            Text(tug.vesselName)
//                .font(.headline)
//            
//            Text("Tug ID: \(tug.tugId)")
//                .font(.caption)
//                .foregroundColor(.gray)
//            
//            // Add more details here as needed
//        }
//        .padding(.vertical, 5)
//    }
//}








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
                    tugsList
                }
            }
        }
        .navigationTitle("Tugs")
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
    
    private var statusBar: some View {
        HStack {
            Text("Total Tugs: \(viewModel.totalTugs)")
                .font(.footnote)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.bottom, 5)
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
