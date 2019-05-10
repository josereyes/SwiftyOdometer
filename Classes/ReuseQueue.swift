//
//  ReuseQueue.swift
//  Odometer
//
//  Created by Jose Reyes on 5/8/19.
//  Copyright © 2019 Jose Reyes. All rights reserved.
//

import Foundation

class TextLayerCache {
    var workstation = NSCache<NSString, ReuseTextLayers>()
    var recycleBin = NSCache<NSString, ReuseTextLayers>()

    init() {
        workstation.setObject(ReuseTextLayers(Set<ReuseTextLayer>()), forKey: "ReuseTextLabelKey")
        recycleBin.setObject(ReuseTextLayers(Set<ReuseTextLayer>()), forKey: "ReuseTextLabelKey")
    }

    func enqueueReusableObject(_ reusableObject: ReuseTextLayer) {
        var newWorkstationSet = workstationSet(for: reusableObject.reuseIdentifier)
        newWorkstationSet?.forEach { element in
            if element == reusableObject {
                newWorkstationSet?.remove(element)
            }
        }

        if let newWorkStationSet = newWorkstationSet {
            workstation.setObject(ReuseTextLayers(newWorkStationSet), forKey: NSString(string: reusableObject.reuseIdentifier))
        }

        var newRecycleBinSet = recycleBinSet(for: reusableObject.reuseIdentifier)
        newRecycleBinSet?.insert(reusableObject)

        if let newRecycleBinSet = newRecycleBinSet {
            recycleBin.setObject(ReuseTextLayers(newRecycleBinSet), forKey: NSString(string: reusableObject.reuseIdentifier))
        }
    }

    func dequeueReusableObject(with identifier: String) -> ReuseTextLayer {
        guard let reusableObject = recycleBinSet(for: identifier)?.first else {
            return ReuseTextLayer(reuseIdentifier: identifier)
        }

        var newRecycleBinSet = recycleBinSet(for: identifier)
        newRecycleBinSet?.forEach { element in
            if element == reusableObject {
                newRecycleBinSet?.remove(element)
            }
        }

        if let newRecycleBinSet = newRecycleBinSet {
            recycleBin.setObject(ReuseTextLayers(newRecycleBinSet), forKey: NSString(string: identifier))
        }

        var newWorkstationSet = workstationSet(for: identifier)
        newWorkstationSet?.insert(reusableObject)

        if let newWorkstationSet = newWorkstationSet {
            workstation.setObject(ReuseTextLayers(newWorkstationSet), forKey: NSString(string: identifier))
        }

        return reusableObject
    }

    func workstationSet(for identifier: String) -> Set<ReuseTextLayer>? {
        return workstation.object(forKey: NSString(string: identifier))?.set ?? nil
    }

    func recycleBinSet(for identifier: String) -> Set<ReuseTextLayer>? {
        return recycleBin.object(forKey: NSString(string: identifier))?.set ?? nil
    }
}
