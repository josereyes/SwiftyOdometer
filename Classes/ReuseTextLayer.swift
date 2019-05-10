//
//  ReuseTextLayer.swift
//  Odometer
//
//  Created by Jose Reyes on 5/9/19.
//  Copyright © 2019 Jose Reyes. All rights reserved.
//

import Foundation

class ReuseTextLayers {
    var set = Set<ReuseTextLayer>()

    init(_ set: Set<ReuseTextLayer>) {
        self.set = set
    }
}

class ReuseTextLayer: CATextLayer {
    var reuseIdentifier: String

    override init(layer: Any) {
        self.reuseIdentifier = "reuseKey"
        super.init(layer: layer)
    }

    required init(reuseIdentifier: String) {
        self.reuseIdentifier = reuseIdentifier
        super.init()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
