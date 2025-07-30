import Foundation

// Types of navigation nodes
enum NodeType: String, Codable {
    case mainCategory  // Main categories from MainView
    case menu          // Menu views that lead to other views
    case list          // List views
    case detail        // Detail views
    case functional    // Functional views like map, search
}

// Data structure for a navigation node (screen/view)
struct NavigationNode: Identifiable, Codable {
    let id: String           // Unique identifier
    let name: String         // Display name
    let description: String  // Optional description
    let type: NodeType       // Type of view
    let filePath: String     // File path to the view
    let level: Int           // Horizontal level in the flow (0 is leftmost)
    let position: Int        // Vertical position within the level
}

// Connection between two navigation nodes
struct NodeConnection: Identifiable, Codable {
    var id: String { "\(from)-\(to)" }
    let from: String  // Source node ID
    let to: String    // Target node ID
}

// Navigation flow section (e.g., Weather, Tides)
struct NavigationFlowSection: Identifiable {
    var id: String { category }
    let category: String                 // Category name (e.g., WEATHER, TIDES)
    var nodes: [NavigationNode]          // Nodes in this section
    let connections: [NodeConnection]    // Connections between nodes
}

// Full navigation flow data
let navigationFlowData: [NavigationFlowSection] = [
    // MAP section
    NavigationFlowSection(
        category: "MAP",
        nodes: [
            NavigationNode(
                id: "main_map",
                name: "MAP",
                description: "Main Map button",
                type: .mainCategory,
                filePath: "MainView.swift",
                level: 0,
                position: 0
            ),
            NavigationNode(
                id: "map_clustering",
                name: "MapClusteringView",
                description: "Map with clustering",
                type: .functional,
                filePath: "MapClusteringView.swift",
                level: 1,
                position: 0
            )
        ],
        connections: [
            NodeConnection(from: "main_map", to: "map_clustering")
        ]
    ),

    // WEATHER section
    NavigationFlowSection(
        category: "WEATHER",
        nodes: [
            NavigationNode(
                id: "main_weather",
                name: "WEATHER",
                description: "Weather button",
                type: .mainCategory,
                filePath: "MainView.swift",
                level: 0,
                position: 0
            ),
            NavigationNode(
                id: "weather_menu",
                name: "WeatherMenuView",
                description: "Weather menu",
                type: .menu,
                filePath: "WeatherMenuView.swift",
                level: 1,
                position: 0
            ),
            NavigationNode(
                id: "weather_favorites",
                name: "WeatherFavoritesView",
                description: "Weather favorites",
                type: .list,
                filePath: "WeatherFavoritesView.swift",
                level: 2,
                position: 0
            ),
            NavigationNode(
                id: "current_local_weather",
                name: "CurrentLocalWeatherView",
                description: "Local weather",
                type: .detail,
                filePath: "CurrentLocalWeatherView.swift",
                level: 2,
                position: 1
            ),
            NavigationNode(
                id: "weather_map",
                name: "WeatherMapView",
                description: "Weather map",
                type: .functional,
                filePath: "WeatherMapView.swift",
                level: 2,
                position: 2
            ),
            NavigationNode(
                id: "weather_detail_for_favorites",
                name: "CurrentLocalWeatherViewForFavorites",
                description: "Weather from favorites",
                type: .detail,
                filePath: "CurrentLocalWeatherViewForFavorites.swift",
                level: 3,
                position: 0
            ),
            NavigationNode(
                id: "weather_detail_for_map",
                name: "CurrentLocalWeatherViewForMap",
                description: "Weather at map location",
                type: .detail,
                filePath: "CurrentLocalWeatherViewForMap.swift",
                level: 3,
                position: 2
            ),
            NavigationNode(
                id: "hourly_forecast",
                name: "HourlyForecastView",
                description: "Hourly forecast",
                type: .detail,
                filePath: "HourlyForecastView.swift",
                level: 4,
                position: 1
            )
        ],
        connections: [
            NodeConnection(from: "main_weather", to: "weather_menu"),
            NodeConnection(from: "weather_menu", to: "weather_favorites"),
            NodeConnection(from: "weather_menu", to: "current_local_weather"),
            NodeConnection(from: "weather_menu", to: "weather_map"),
            NodeConnection(from: "weather_favorites", to: "weather_detail_for_favorites"),
            NodeConnection(from: "weather_map", to: "weather_detail_for_map"),
            NodeConnection(from: "current_local_weather", to: "hourly_forecast"),
            NodeConnection(from: "weather_detail_for_favorites", to: "hourly_forecast"),
            NodeConnection(from: "weather_detail_for_map", to: "hourly_forecast")
        ]
    ),

    // TIDES section
    NavigationFlowSection(
        category: "TIDES",
        nodes: [
            NavigationNode(
                id: "main_tides",
                name: "TIDES",
                description: "Tides button",
                type: .mainCategory,
                filePath: "MainView.swift",
                level: 0,
                position: 0
            ),
            NavigationNode(
                id: "tide_menu",
                name: "TideMenuView",
                description: "Tide menu",
                type: .menu,
                filePath: "TideMenuView.swift",
                level: 1,
                position: 0
            ),
            NavigationNode(
                id: "tide_favorites",
                name: "TideFavoritesView",
                description: "Tide favorites",
                type: .list,
                filePath: "TideFavoritesView.swift",
                level: 2,
                position: 0
            ),
            NavigationNode(
                id: "tide_stations",
                name: "TidalHeightStationsView",
                description: "Tide stations",
                type: .list,
                filePath: "TidalHeightStationsView.swift",
                level: 2,
                position: 1
            ),
            NavigationNode(
                id: "tide_predictions",
                name: "TidalHeightPredictionView",
                description: "Tide predictions",
                type: .detail,
                filePath: "TidalHeightPredictionView.swift",
                level: 3,
                position: 0
            )
        ],
        connections: [
            NodeConnection(from: "main_tides", to: "tide_menu"),
            NodeConnection(from: "tide_menu", to: "tide_favorites"),
            NodeConnection(from: "tide_menu", to: "tide_stations"),
            NodeConnection(from: "tide_stations", to: "tide_predictions"),
            NodeConnection(from: "tide_favorites", to: "tide_predictions")
        ]
    ),

    // CURRENTS section
    NavigationFlowSection(
        category: "CURRENTS",
        nodes: [
            NavigationNode(
                id: "main_currents",
                name: "CURRENTS",
                description: "Currents button",
                type: .mainCategory,
                filePath: "MainView.swift",
                level: 0,
                position: 0
            ),
            NavigationNode(
                id: "current_menu",
                name: "CurrentMenuView",
                description: "Current menu",
                type: .menu,
                filePath: "CurrentMenuView.swift",
                level: 1,
                position: 0
            ),
            NavigationNode(
                id: "current_favorites",
                name: "CurrentFavoritesView",
                description: "Current favorites",
                type: .list,
                filePath: "CurrentFavoritesView.swift",
                level: 2,
                position: 0
            ),
            NavigationNode(
                id: "current_stations",
                name: "TidalCurrentStationsView",
                description: "Current stations",
                type: .list,
                filePath: "TidalCurrentStationsView.swift",
                level: 2,
                position: 1
            ),
            NavigationNode(
                id: "current_predictions",
                name: "TidalCurrentPredictionView",
                description: "Current predictions",
                type: .detail,
                filePath: "TidalCurrentPredictionView.swift",
                level: 3,
                position: 0
            ),
            NavigationNode(
                id: "current_web",
                name: "TidalCurrentStationWebView",
                description: "Current station web view",
                type: .detail,
                filePath: "TidalCurrentStationWebView.swift",
                level: 3,
                position: 1
            ),
            NavigationNode(
                id: "current_graph",
                name: "TidalCurrentGraphView",
                description: "Current graph",
                type: .detail,
                filePath: "TidalCurrentGraphView.swift",
                level: 4,
                position: 0
            )
        ],
        connections: [
            NodeConnection(from: "main_currents", to: "current_menu"),
            NodeConnection(from: "current_menu", to: "current_favorites"),
            NodeConnection(from: "current_menu", to: "current_stations"),
            NodeConnection(from: "current_stations", to: "current_predictions"),
            NodeConnection(from: "current_favorites", to: "current_predictions"),
            NodeConnection(from: "current_stations", to: "current_web"),
            NodeConnection(from: "current_predictions", to: "current_graph")
        ]
    ),

    // NAV UNITS section
    NavigationFlowSection(
        category: "NAV UNITS",
        nodes: [
            NavigationNode(
                id: "main_navunits",
                name: "NAV UNITS",
                description: "Nav Units button",
                type: .mainCategory,
                filePath: "MainView.swift",
                level: 0,
                position: 0
            ),
            NavigationNode(
                id: "navunit_menu",
                name: "NavUnitMenuView",
                description: "Nav Unit menu",
                type: .menu,
                filePath: "NavUnitMenuView.swift",
                level: 1,
                position: 0
            ),
            NavigationNode(
                id: "navunit_favorites",
                name: "NavUnitFavoritesView",
                description: "Nav Unit favorites",
                type: .list,
                filePath: "NavUnitFavoritesView.swift",
                level: 2,
                position: 0
            ),
            NavigationNode(
                id: "navunit_list",
                name: "NavUnitsView",
                description: "Nav Units list",
                type: .list,
                filePath: "NavUnitsView.swift",
                level: 2,
                position: 1
            ),
            NavigationNode(
                id: "navunit_details",
                name: "NavUnitDetailsView",
                description: "Nav Unit details",
                type: .detail,
                filePath: "NavUnitDetailsView.swift",
                level: 3,
                position: 0
            )
        ],
        connections: [
            NodeConnection(from: "main_navunits", to: "navunit_menu"),
            NodeConnection(from: "navunit_menu", to: "navunit_favorites"),
            NodeConnection(from: "navunit_menu", to: "navunit_list"),
            NodeConnection(from: "navunit_list", to: "navunit_details"),
            NodeConnection(from: "navunit_favorites", to: "navunit_details")
        ]
    ),

    // BUOYS section
    NavigationFlowSection(
        category: "BUOYS",
        nodes: [
            NavigationNode(
                id: "main_buoys",
                name: "BUOYS",
                description: "Buoys button",
                type: .mainCategory,
                filePath: "MainView.swift",
                level: 0,
                position: 0
            ),
            NavigationNode(
                id: "buoy_menu",
                name: "BuoyMenuView",
                description: "Buoy menu",
                type: .menu,
                filePath: "BuoyMenuView.swift",
                level: 1,
                position: 0
            ),
            NavigationNode(
                id: "buoy_favorites",
                name: "BuoyFavoritesView",
                description: "Buoy favorites",
                type: .list,
                filePath: "BuoyFavoritesView.swift",
                level: 2,
                position: 0
            ),
            NavigationNode(
                id: "buoy_stations",
                name: "BuoyStationsView",
                description: "Buoy stations",
                type: .list,
                filePath: "BuoyStationsView.swift",
                level: 2,
                position: 1
            ),
            NavigationNode(
                id: "buoy_web",
                name: "BuoyStationWebView",
                description: "Buoy station web view",
                type: .detail,
                filePath: "BuoyStationWebView.swift",
                level: 3,
                position: 0
            )
        ],
        connections: [
            NodeConnection(from: "main_buoys", to: "buoy_menu"),
            NodeConnection(from: "buoy_menu", to: "buoy_favorites"),
            NodeConnection(from: "buoy_menu", to: "buoy_stations"),
            NodeConnection(from: "buoy_stations", to: "buoy_web"),
            NodeConnection(from: "buoy_favorites", to: "buoy_web")
        ]
    ),

    // TUGS section
    NavigationFlowSection(
        category: "TUGS",
        nodes: [
            NavigationNode(
                id: "main_tugs",
                name: "TUGS",
                description: "Tugs button",
                type: .mainCategory,
                filePath: "MainView.swift",
                level: 0,
                position: 0
            ),
            NavigationNode(
                id: "tugs_list",
                name: "TugsView",
                description: "Tugs list",
                type: .list,
                filePath: "TugsView.swift",
                level: 1,
                position: 0
            ),
            NavigationNode(
                id: "tug_details",
                name: "TugDetailsView",
                description: "Tug details",
                type: .detail,
                filePath: "TugDetailsView.swift",
                level: 2,
                position: 0
            )
        ],
        connections: [
            NodeConnection(from: "main_tugs", to: "tugs_list"),
            NodeConnection(from: "tugs_list", to: "tug_details")
        ]
    ),

    // BARGES section
    NavigationFlowSection(
        category: "BARGES",
        nodes: [
            NavigationNode(
                id: "main_barges",
                name: "BARGES",
                description: "Barges button",
                type: .mainCategory,
                filePath: "MainView.swift",
                level: 0,
                position: 0
            ),
            NavigationNode(
                id: "barges_list",
                name: "BargesView",
                description: "Barges list",
                type: .list,
                filePath: "BargesView.swift",
                level: 1,
                position: 0
            ),
            NavigationNode(
                id: "barge_details",
                name: "BargeDetailsView",
                description: "Barge details",
                type: .detail,
                filePath: "BargeDetailsView.swift",
                level: 2,
                position: 0
            )
        ],
        connections: [
            NodeConnection(from: "main_barges", to: "barges_list"),
            NodeConnection(from: "barges_list", to: "barge_details")
        ]
    ),

    // ROUTE section
    NavigationFlowSection(
        category: "ROUTE",
        nodes: [
            NavigationNode(
                id: "main_route",
                name: "ROUTE",
                description: "Route button",
                type: .mainCategory,
                filePath: "MainView.swift",
                level: 0,
                position: 0
            ),
            NavigationNode(
                id: "gpx_view",
                name: "GpxView",
                description: "GPX view",
                type: .functional,
                filePath: "GpxView.swift",
                level: 1,
                position: 0
            ),
            NavigationNode(
                id: "route_details",
                name: "RouteDetailsView",
                description: "Route details",
                type: .detail,
                filePath: "RouteDetailsView.swift",
                level: 2,
                position: 0
            )
        ],
        connections: [
            NodeConnection(from: "main_route", to: "gpx_view"),
            NodeConnection(from: "gpx_view", to: "route_details")
        ]
    )
]
