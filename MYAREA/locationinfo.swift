//
//  locationinfo.swift
//  MYAREA
//
//  Created by 山下幸助 on 2023/09/18.
//

import Foundation
import RealmSwift

class locationinfo: Object {
    @Persisted var datetime: String = ""
    @Persisted var longitude: Double = 0.0
    @Persisted var latitude: Double = 0.0
}
