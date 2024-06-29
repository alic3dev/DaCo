//
//  DeviceInfo.swift
//  DaCo
//
//  Created by Alice Grace on 6/28/24.
//

import Foundation
import UIKit

public struct DeviceInfo {
  let systemVersion: String
  let systemName: String
  let name: String
  let identifierForVendor: UUID?
  let model: String
  let localizedModel: String
}

public func getDeviceInfo() -> DeviceInfo {
  return .init(
    systemVersion: UIDevice.current.systemVersion,
    systemName: UIDevice.current.systemName,
    name: UIDevice.current.name,
    identifierForVendor: UIDevice.current.identifierForVendor,
    model: UIDevice.current.model,
    localizedModel: UIDevice.current.localizedModel
  )
}
