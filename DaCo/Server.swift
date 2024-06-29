//
//  Server.swift
//  DaCo
//
//  Created by Alice Grace on 6/28/24.
//

import Foundation

public struct Server {
  public var protocolType: String
  public var host: String
  public var port: Int16
  public var endPoint: String

  public var headers: [Header]

  public init(protocolType: String, host: String, port: Int16, endPoint: String, headers: [Header]) {
    self.protocolType = protocolType
    self.host = host
    self.port = port
    self.endPoint = endPoint
    self.headers = headers
  }
}
