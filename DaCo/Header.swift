//
//  Header.swift
//  DaCo
//
//  Created by Alice Grace on 6/28/24.
//

import Foundation

public struct Header {
  public var value: String
  public var field: String

  public init(value: String, field: String) {
    self.value = value
    self.field = field
  }
}
