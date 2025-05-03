import Foundation
import SQLite

struct NavUnit: Identifiable {
    // Primary key
    var id: String { navUnitId }
    
    // Properties
    let navUnitId: String
    var unloCode: String?
    var navUnitName: String
    var locationDescription: String?
    var facilityType: String?
    var streetAddress: String?
    var cityOrTown: String?
    var statePostalCode: String?
    var zipCode: String?
    var countyName: String?
    var countyFipsCode: String?
    var congress: String?
    var congressFips: String?
    var waterwayName: String?
    var portName: String?
    var mile: Double?
    var bank: String?
    // No change needed here as the properties are already non-optional in the struct
    var latitude: Double?
    var longitude: Double?
    var operators: String?
    var owners: String?
    var purpose: String?
    var highwayNote: String?
    var railwayNote: String?
    var location: String?
    var dock: String?
    var commodities: String?
    var construction: String?
    var mechanicalHandling: String?
    var remarks: String?
    var verticalDatum: String?
    var depthMin: Double?
    var depthMax: Double?
    var berthingLargest: Double?
    var berthingTotal: Double?
    var deckHeightMin: Double?
    var deckHeightMax: Double?
    var serviceInitiationDate: String?
    var serviceTerminationDate: String?
    var isFavorite: Bool
    
    // Computed property for phone numbers
    var phoneNumbers: [String] {
        var numbers: [String] = []
        
        func extractFromText(_ text: String?) {
            guard let text = text, !text.isEmpty else { return }
            
            // Regular expression to match phone numbers
            let regex = try? NSRegularExpression(
                pattern: "(?:Phone:?\\s*)((?:\\d{3}/?\\d{3}-\\d{4}(?:\\s*-\\d{4})?)|(?:\\d{3}-\\d{3}-\\d{4}))",
                options: []
            )
            
            if let regex = regex {
                let nsString = text as NSString
                let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
                
                for match in matches {
                    if match.numberOfRanges > 1 {
                        let phoneNumsStr = nsString.substring(with: match.range(at: 1))
                        let phoneNums = phoneNumsStr.components(separatedBy: "/")
                        
                        for num in phoneNums {
                            let cleanNum = num.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "-", with: "")
                            if cleanNum.count >= 10 {
                                numbers.append(cleanNum)
                            }
                        }
                    }
                }
            }
        }
        
        extractFromText(operators)
        extractFromText(owners)
        extractFromText(remarks)
        
        // Return unique values
        return Array(Set(numbers))
    }
    
    // Additional computed property
    var hasPhoneNumbers: Bool {
        return !phoneNumbers.isEmpty
    }
    
    // Coding keys for database mapping
    enum CodingKeys: String, CodingKey {
        case navUnitId = "NAV_UNIT_ID"
        case unloCode = "UNLOCODE"
        case navUnitName = "NAV_UNIT_NAME"
        case locationDescription = "LOCATION_DESCRIPTION"
        case facilityType = "FACILITY_TYPE"
        case streetAddress = "STREET_ADDRESS"
        case cityOrTown = "CITY_OR_TOWN"
        case statePostalCode = "STATE_POSTAL_CODE"
        case zipCode = "ZIPCODE"
        case countyName = "COUNTY_NAME"
        case countyFipsCode = "COUNTY_FIPS_CODE"
        case congress = "CONGRESS"
        case congressFips = "CONGRESS_FIPS"
        case waterwayName = "WTWY_NAME"
        case portName = "PORT_NAME"
        case mile = "MILE"
        case bank = "BANK"
        case latitude = "LATITUDE"
        case longitude = "LONGITUDE"
        case operators = "OPERATORS"
        case owners = "OWNERS"
        case purpose = "PURPOSE"
        case highwayNote = "HIGHWAY_NOTE"
        case railwayNote = "RAILWAY_NOTE"
        case location = "LOCATION"
        case dock = "DOCK"
        case commodities = "COMMODITIES"
        case construction = "CONSTRUCTION"
        case mechanicalHandling = "MECHANICAL_HANDLING"
        case remarks = "REMARKS"
        case verticalDatum = "VERTICAL_DATUM"
        case depthMin = "DEPTH_MIN"
        case depthMax = "DEPTH_MAX"
        case berthingLargest = "BERTHING_LARGEST"
        case berthingTotal = "BERTHING_TOTAL"
        case deckHeightMin = "DECK_HEIGHT_MIN"
        case deckHeightMax = "DECK_HEIGHT_MAX"
        case serviceInitiationDate = "SERVICE_INITIATION_DATE"
        case serviceTerminationDate = "SERVICE_TERMINATION_DATE"
        case isFavorite = "is_favorite"
    }
    
    // Initializer with default values
    init(
        navUnitId: String = "",
        unloCode: String? = nil,
        navUnitName: String = "",
        locationDescription: String? = nil,
        facilityType: String? = nil,
        streetAddress: String? = nil,
        cityOrTown: String? = nil,
        statePostalCode: String? = nil,
        zipCode: String? = nil,
        countyName: String? = nil,
        countyFipsCode: String? = nil,
        congress: String? = nil,
        congressFips: String? = nil,
        waterwayName: String? = nil,
        portName: String? = nil,
        mile: Double? = nil,
        bank: String? = nil,
        latitude: Double = 0,
        longitude: Double = 0,
        operators: String? = nil,
        owners: String? = nil,
        purpose: String? = nil,
        highwayNote: String? = nil,
        railwayNote: String? = nil,
        location: String? = nil,
        dock: String? = nil,
        commodities: String? = nil,
        construction: String? = nil,
        mechanicalHandling: String? = nil,
        remarks: String? = nil,
        verticalDatum: String? = nil,
        depthMin: Double? = nil,
        depthMax: Double? = nil,
        berthingLargest: Double? = nil,
        berthingTotal: Double? = nil,
        deckHeightMin: Double? = nil,
        deckHeightMax: Double? = nil,
        serviceInitiationDate: String? = nil,
        serviceTerminationDate: String? = nil,
        isFavorite: Bool = false
    ) {
        self.navUnitId = navUnitId
        self.unloCode = unloCode
        self.navUnitName = navUnitName
        self.locationDescription = locationDescription
        self.facilityType = facilityType
        self.streetAddress = streetAddress
        self.cityOrTown = cityOrTown
        self.statePostalCode = statePostalCode
        self.zipCode = zipCode
        self.countyName = countyName
        self.countyFipsCode = countyFipsCode
        self.congress = congress
        self.congressFips = congressFips
        self.waterwayName = waterwayName
        self.portName = portName
        self.mile = mile
        self.bank = bank
        self.latitude = latitude
        self.longitude = longitude
        self.operators = operators
        self.owners = owners
        self.purpose = purpose
        self.highwayNote = highwayNote
        self.railwayNote = railwayNote
        self.location = location
        self.dock = dock
        self.commodities = commodities
        self.construction = construction
        self.mechanicalHandling = mechanicalHandling
        self.remarks = remarks
        self.verticalDatum = verticalDatum
        self.depthMin = depthMin
        self.depthMax = depthMax
        self.berthingLargest = berthingLargest
        self.berthingTotal = berthingTotal
        self.deckHeightMin = deckHeightMin
        self.deckHeightMax = deckHeightMax
        self.serviceInitiationDate = serviceInitiationDate
        self.serviceTerminationDate = serviceTerminationDate
        self.isFavorite = isFavorite
    }
}

// Make it conform to Codable for database operations
extension NavUnit: Codable {
    // We can use the CodingKeys above for both Codable and SQLite operations
}

// Make NavUnit conform to StationCoordinates
extension NavUnit: StationCoordinates {
    // NavUnit already has latitude and longitude properties,
    // so we only need the empty extension to conform to the protocol
}
