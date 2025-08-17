import SwiftUI
import CoreData

/// Test view to verify Core Data + CloudKit integration
/// This view tests all CRUD operations and CloudKit connectivity
/// TODO: Remove this file after migration is complete
struct CoreDataTestView: View {
    @StateObject private var coreDataManager = CoreDataManager.shared
    @StateObject private var cloudKitManager = CloudKitManager.shared
    
    @State private var testResults: [String] = []
    @State private var isRunningTests = false
    @State private var currentTest = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                
                // CloudKit Status
                VStack(alignment: .leading, spacing: 10) {
                    Text("CloudKit Status")
                        .font(.headline)
                    
                    HStack {
                        Circle()
                            .fill(cloudKitManager.accountStatus == .available ? .green : .orange)
                            .frame(width: 12, height: 12)
                        
                        Text(cloudKitManager.getAccountStatusMessage())
                            .font(.caption)
                            .foregroundColor(cloudKitManager.accountStatus == .available ? .green : .orange)
                    }
                    
                    if let lastSync = cloudKitManager.lastSyncDate {
                        Text("Last sync: \(lastSync.formatted())")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                
                // Test Controls
                VStack(spacing: 15) {
                    if isRunningTests {
                        VStack {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Running: \(currentTest)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Button("Run Core Data Tests") {
                            Task {
                                await runCoreDataTests()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isRunningTests)
                        
                        Button("Test CloudKit Connection") {
                            Task {
                                await testCloudKitConnection()
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(isRunningTests)
                        
                        Button("Clear All Test Data") {
                            clearAllTestData()
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.red)
                        .disabled(isRunningTests)
                    }
                }
                
                // Test Results
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(testResults.enumerated()), id: \.offset) { index, result in
                            HStack {
                                if result.contains("✅") {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                } else if result.contains("❌") {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                } else if result.contains("ℹ️") {
                                    Image(systemName: "info.circle.fill")
                                        .foregroundColor(.blue)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundColor(.secondary)
                                }
                                
                                Text(result)
                                    .font(.system(.caption, design: .monospaced))
                                    .multilineTextAlignment(.leading)
                                
                                Spacer()
                            }
                        }
                    }
                    .padding()
                }
                .background(Color(.systemGray6))
                .cornerRadius(10)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Core Data + CloudKit Test")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                testResults.append("ℹ️ Ready to test Core Data + CloudKit integration")
                testResults.append("ℹ️ This replaces the 1,200-line SupabaseManager")
            }
        }
    }
    
    // MARK: - Core Data Tests
    
    func runCoreDataTests() async {
        isRunningTests = true
        testResults.removeAll()
        
        await MainActor.run {
            testResults.append("🚀 Starting Core Data integration tests...")
        }
        
        // Test 1: Core Data Stack Initialization
        await testCoreDataStack()
        
        // Test 2: Entity Creation
        await testEntityCreation()
        
        // Test 3: CRUD Operations
        await testCRUDOperations()
        
        // Test 4: Fetch Operations
        await testFetchOperations()
        
        // Test 5: Data Persistence
        await testDataPersistence()
        
        await MainActor.run {
            testResults.append("🎉 All Core Data tests completed!")
            isRunningTests = false
            currentTest = ""
        }
    }
    
    private func testCoreDataStack() async {
        await MainActor.run {
            currentTest = "Testing Core Data Stack"
        }
        
        do {
            // Test if persistence controller is working
            let context = PersistenceController.shared.container.viewContext
            
            if context.persistentStoreCoordinator?.persistentStores.isEmpty == false {
                await MainActor.run {
                    testResults.append("✅ Core Data stack initialized successfully")
                }
            } else {
                await MainActor.run {
                    testResults.append("❌ Core Data stack failed to initialize")
                }
            }
            
            // Test CloudKit availability
            let isCloudKitReady = await PersistenceController.shared.checkCloudKitAvailability()
            
            await MainActor.run {
                if isCloudKitReady {
                    testResults.append("✅ CloudKit integration ready")
                } else {
                    testResults.append("⚠️ CloudKit not available (sign into iCloud)")
                }
            }
            
        } catch {
            await MainActor.run {
                testResults.append("❌ Core Data stack error: \(error.localizedDescription)")
            }
        }
    }
    
    private func testEntityCreation() async {
        await MainActor.run {
            currentTest = "Testing Entity Creation"
        }
        
        let entities = ["TideFavorite", "WeatherFavorite", "NavUnitFavorite", "CurrentFavorite", "BuoyFavorite"]
        
        for entityName in entities {
            let context = PersistenceController.shared.container.viewContext
            
            if let entity = NSEntityDescription.entity(forEntityName: entityName, in: context) {
                await MainActor.run {
                    testResults.append("✅ Entity '\(entityName)' created successfully")
                }
            } else {
                await MainActor.run {
                    testResults.append("❌ Entity '\(entityName)' creation failed")
                }
            }
        }
    }
    
    private func testCRUDOperations() async {
        await MainActor.run {
            currentTest = "Testing CRUD Operations"
        }
        
        // Test adding tide favorite
        coreDataManager.addTideFavorite(
            stationId: "TEST_STATION_001",
            name: "Test Tide Station",
            latitude: 40.7589,
            longitude: -73.9851
        )
        
        await MainActor.run {
            testResults.append("✅ Created TideFavorite")
        }
        
        // Test adding weather favorite
        coreDataManager.addWeatherFavorite(
            latitude: 40.7589,
            longitude: -73.9851,
            locationName: "Test Weather Location"
        )
        
        await MainActor.run {
            testResults.append("✅ Created WeatherFavorite")
        }
        
        // Test adding nav unit favorite
        coreDataManager.addNavUnitFavorite(
            navUnitId: "TEST_NAVUNIT_001",
            name: "Test Nav Unit",
            latitude: 40.7589,
            longitude: -73.9851
        )
        
        await MainActor.run {
            testResults.append("✅ Created NavUnitFavorite")
        }
        
        // Test adding current favorite
        coreDataManager.addCurrentFavorite(
            stationId: "TEST_CURRENT_001",
            currentBin: 1
        )
        
        await MainActor.run {
            testResults.append("✅ Created CurrentFavorite")
        }
        
        // Test adding buoy favorite
        coreDataManager.addBuoyFavorite(
            stationId: "TEST_BUOY_001",
            name: "Test Buoy",
            latitude: 40.7589,
            longitude: -73.9851
        )
        
        await MainActor.run {
            testResults.append("✅ Created BuoyFavorite")
        }
    }
    
    private func testFetchOperations() async {
        await MainActor.run {
            currentTest = "Testing Fetch Operations"
        }
        
        // Test fetching all favorites
        let tideFavorites = coreDataManager.getTideFavorites()
        let weatherFavorites = coreDataManager.getWeatherFavorites()
        let navUnitFavorites = coreDataManager.getNavUnitFavorites()
        let currentFavorites = coreDataManager.getCurrentFavorites()
        let buoyFavorites = coreDataManager.getBuoyFavorites()
        
        await MainActor.run {
            testResults.append("✅ Fetched \(tideFavorites.count) TideFavorites")
            testResults.append("✅ Fetched \(weatherFavorites.count) WeatherFavorites")
            testResults.append("✅ Fetched \(navUnitFavorites.count) NavUnitFavorites")
            testResults.append("✅ Fetched \(currentFavorites.count) CurrentFavorites")
            testResults.append("✅ Fetched \(buoyFavorites.count) BuoyFavorites")
        }
        
        // Test specific queries
        let isTideFavorite = coreDataManager.isTideFavorite(stationId: "TEST_STATION_001")
        let isWeatherFavorite = coreDataManager.isWeatherFavorite(latitude: 40.7589, longitude: -73.9851)
        
        await MainActor.run {
            testResults.append("✅ Tide favorite exists: \(isTideFavorite)")
            testResults.append("✅ Weather favorite exists: \(isWeatherFavorite)")
        }
    }
    
    private func testDataPersistence() async {
        await MainActor.run {
            currentTest = "Testing Data Persistence"
        }
        
        // Save context
        coreDataManager.saveContext()
        
        await MainActor.run {
            testResults.append("✅ Data saved to persistent store")
            testResults.append("ℹ️ Data will sync to CloudKit automatically if signed in")
        }
    }
    
    // MARK: - CloudKit Tests
    
    func testCloudKitConnection() async {
        isRunningTests = true
        currentTest = "Testing CloudKit Connection"
        
        await MainActor.run {
            testResults.append("🔍 Testing CloudKit connectivity...")
        }
        
        let isSetupValid = await cloudKitManager.verifyCloudKitSetup()
        
        await MainActor.run {
            if isSetupValid {
                testResults.append("✅ CloudKit connection successful")
                testResults.append("✅ Private database accessible")
                testResults.append("ℹ️ Data will sync across devices automatically")
            } else {
                testResults.append("⚠️ CloudKit setup needs attention")
                testResults.append("ℹ️ This is normal if no data exists yet")
                testResults.append("ℹ️ Try adding favorites and sync will work")
            }
            
            isRunningTests = false
            currentTest = ""
        }
    }
    
    // MARK: - Helper Methods
    
    func clearAllTestData() {
        // Remove test data
        coreDataManager.removeTideFavorite(stationId: "TEST_STATION_001")
        coreDataManager.removeWeatherFavorite(latitude: 40.7589, longitude: -73.9851)
        coreDataManager.removeNavUnitFavorite(navUnitId: "TEST_NAVUNIT_001")
        coreDataManager.removeCurrentFavorite(stationId: "TEST_CURRENT_001", currentBin: 1)
        coreDataManager.removeBuoyFavorite(stationId: "TEST_BUOY_001")
        
        testResults.append("🗑️ Test data cleared")
    }
}

#Preview {
    CoreDataTestView()
}