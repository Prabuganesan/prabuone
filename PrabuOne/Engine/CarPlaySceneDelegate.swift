import Foundation
import UIKit
#if canImport(CarPlay)
import CarPlay

public class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    public var interfaceController: CPInterfaceController?
    
    public func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        
        let store = LifeStore.shared
        let vehicle = store.vehicleProfile
        
        var items: [CPListItem] = []
        
        // 1. Vehicle Service Item
        let serviceRemaining = max(0, Int(vehicle.nextServiceDueKm - vehicle.currentOdometerKm))
        let serviceItem = CPListItem(
            text: "Service Due: \(serviceRemaining) km",
            detailText: "Target: \(Int(vehicle.nextServiceDueKm)) km • \(vehicle.makeModel)",
            image: UIImage(systemName: "wrench.and.screwdriver.fill")
        )
        items.append(serviceItem)
        
        // 2. FASTag Item
        let fastagItem = CPListItem(
            text: "FASTag Balance: ₹\(Int(vehicle.fastagBalance))",
            detailText: "Low balance alerts enabled",
            image: UIImage(systemName: "tag.fill")
        )
        items.append(fastagItem)
        
        // 3. Odometer Item
        let odoItem = CPListItem(
            text: "Live Odometer: \(Int(vehicle.currentOdometerKm)) km",
            detailText: "\(vehicle.registrationNumber) • \(vehicle.fuelType)",
            image: UIImage(systemName: "speedometer")
        )
        items.append(odoItem)
        
        // 4. Quick Notes Item
        let notesCount = store.quickNotes.count
        let notesItem = CPListItem(
            text: "Quick Notes (\(notesCount))",
            detailText: notesCount > 0 ? "Latest: \(store.quickNotes.first?.title ?? "")" : "No active notes",
            image: UIImage(systemName: "note.text")
        )
        items.append(notesItem)
        
        let section = CPListSection(items: items, header: "Prabu One • Vehicle Health", sectionIndexTitle: nil)
        let listTemplate = CPListTemplate(title: "Prabu One", sections: [section])
        
        interfaceController.setRootTemplate(listTemplate, animated: false, completion: nil)
    }
    
    public func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        self.interfaceController = nil
    }
}
#endif
