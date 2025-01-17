/**
       This file is part of Adguard for iOS (https://github.com/AdguardTeam/AdguardForiOS).
       Copyright © Adguard Software Limited. All rights reserved.
 
       Adguard for iOS is free software: you can redistribute it and/or modify
       it under the terms of the GNU General Public License as published by
       the Free Software Foundation, either version 3 of the License, or
       (at your option) any later version.
 
       Adguard for iOS is distributed in the hope that it will be useful,
       but WITHOUT ANY WARRANTY; without even the implied warranty of
       MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
       GNU General Public License for more details.
 
       You should have received a copy of the GNU General Public License
       along with Adguard for iOS.  If not, see <http://www.gnu.org/licenses/>.
 */

import Foundation

extension UIApplication {
    
    static let adguardUrl = "https://adguard.com/forward.html"
    static let rateAppUrl = "https://itunes.apple.com/app/id1047223162?action=write-review"
    
    func openAdguardUrl(action: String, from: String) {
        
        let urlString = adguardUrl(action: action, from: from)
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
    
    func adguardUrl(action: String, from: String)->String {
        var params: Dictionary<String, String> = [:]
        
        params["app"] = "ios"
        params["v"] = ADProductInfo.buildVersion()
        params["action"] = action
        params["from"] = from
        
        let paramsString = ABECRequest.createString(fromParameters: params)
        
        return UIApplication.adguardUrl + "?" + paramsString
    }
    
    func openAppStoreToRateApp() {
        if let writeReviewURL = URL(string: UIApplication.rateAppUrl) {
            UIApplication.shared.open(writeReviewURL, options: [:], completionHandler: nil)
        }
    }
}
