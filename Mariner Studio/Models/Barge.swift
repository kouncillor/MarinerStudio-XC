//
//  Barge.swift
//  Mariner Studio
//
//  Created by Timothy Russell on 5/10/25.
//

import Foundation

struct Barge: Identifiable {
    let id = UUID()
    let bargeId: String
    let vesselName: String

    // Additional properties - optional
    var vesselNumber: String?
    var cgNumber: String?
    var vtcc: String?
    var icst: String?
    var nrt: String?
    var horsepower: String?
    var registeredLength: String?
    var overallLength: String?
    var registeredBreadth: String?
    var overallBreadth: String?
    var hfp: String?
    var capacityRef: String?
    var passengerCapacity: String?
    var tonnageCapacity: String?
    var year: String?
    var rebuilt: String?
    var yearRebuilt: String?
    var vesselYear: String?
    var loadDraft: String?
    var lightDraft: String?
    var equipment1: String?
    var equipment2: String?
    var state: String?
    var basePort1: String?
    var basePort2: String?
    var region: String?
    var operator_: String?
    var fleetYear: String?
}
