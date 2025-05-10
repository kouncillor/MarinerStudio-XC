import Foundation

struct Tug: Identifiable {
    let id = UUID()
    let tugId: String
    let vesselName: String
    
    // Additional properties - optional
    var vesselNumber: String? = nil
    var cgNumber: String? = nil
    var vtcc: String? = nil
    var icst: String? = nil
    var nrt: String? = nil
    var horsepower: String? = nil
    var registeredLength: String? = nil
    var overallLength: String? = nil
    var registeredBreadth: String? = nil
    var overallBreadth: String? = nil
    var hfp: String? = nil
    var capacityRef: String? = nil
    var passengerCapacity: String? = nil
    var tonnageCapacity: String? = nil
    var year: String? = nil
    var rebuilt: String? = nil
    var yearRebuilt: String? = nil
    var vesselYear: String? = nil
    var loadDraft: String? = nil
    var lightDraft: String? = nil
    var equipment1: String? = nil
    var equipment2: String? = nil
    var state: String? = nil
    var basePort1: String? = nil
    var basePort2: String? = nil
    var region: String? = nil
    var operator_: String? = nil
    var fleetYear: String? = nil
}
