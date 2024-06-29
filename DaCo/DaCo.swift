//
//  DaCo.swift
//  DaCo
//
//  Created by Alice Grace on 6/28/24.
//

import CoreMotion
import Foundation
import UIKit

enum DaCoError: Error {
  case invalidServerURL(String)
}

public final class DaCo {
  private var server: Server
  public private(set) var serverURL: URL?
  public private(set) var serverActive: Bool = false
  private var serverStarting: Bool = true
  private var serverStarted: Bool = false
  private var serverUUID: String?

  private let deviceInfo: DeviceInfo

  private var dataUpdateInterval: Double = 1.0 / 50.0 // 50.0hz
  private var timer: Timer?

  private var attitude: Dimensions3Motion<[Double]> = .init(pitch: [], roll: [], yaw: [])
  private var acceleration: Dimensions3<[Double]> = .init(x: [], y: [], z: [])
  private var magneticField: Dimensions3<[Double]> = .init(x: [], y: [], z: [])
  private var rotation: Dimensions3<[Double]> = .init(x: [], y: [], z: [])

  public let motion: CMMotionManager = .init()
  public let ambientPressure: CMAmbientPressureData = .init()

  var serverData: Data?

  public var shouldPostData: Bool = true

  var onServerActiveChangeCallback: ((Bool) -> Void)?

  public init(server: Server) throws {
    self.server = server
    let newServerURL: URL? = DaCo.formulateServerURL(server: server)

    if newServerURL == nil {
      throw DaCoError.invalidServerURL("Couldn't form URL from PROTOCOLTYPE: \(self.server.protocolType) HOST: \(self.server.host), PORT: \(self.server.port), ENDPOINT: \(self.server.endPoint)")
    }

    self.serverURL = newServerURL!

    if self.motion.isAccelerometerAvailable {
      self.motion.accelerometerUpdateInterval = self.dataUpdateInterval
      self.motion.startAccelerometerUpdates()
    }

    if self.motion.isGyroAvailable {
      self.motion.gyroUpdateInterval = self.dataUpdateInterval
      self.motion.startGyroUpdates()
    }

    if self.motion.isMagnetometerAvailable {
      self.motion.magnetometerUpdateInterval = self.dataUpdateInterval
      self.motion.startMagnetometerUpdates()
    }

    if self.motion.isDeviceMotionAvailable {
      self.motion.deviceMotionUpdateInterval = self.dataUpdateInterval
      self.motion.startDeviceMotionUpdates(using: .xArbitraryCorrectedZVertical)
    }

    UIDevice.current.isBatteryMonitoringEnabled = true
    UIDevice.current.isProximityMonitoringEnabled = true

    self.deviceInfo = getDeviceInfo()

    self.startUpdateTimer()
    self.startServer()
  }

//    print(UIDevice.current.orientation)

//    print(UIDevice.current.batteryLevel)
//    print(UIDevice.current.batteryState)
//    print(UIDevice.current.proximityState)

  public func setOnServerActiveChangeCallback(onServerActiveChangeCallback: ((Bool) -> Void)?) {
    self.onServerActiveChangeCallback = onServerActiveChangeCallback
  }

  public static func formulateServerURL(server: Server) -> URL? {
    return URL(string: "\(server.protocolType)://\(server.host):\(server.port)/\(server.endPoint)")
  }

  public func resetServer() {
    self.serverStarted = false
    self.serverUUID = nil

    if self.serverActive {
      self.serverActive = false

      if self.onServerActiveChangeCallback != nil {
        self.onServerActiveChangeCallback!(false)
      }
    }
  }

  public func updateServer(server: Server) throws {
    self.resetServer()

    self.server = server

    let newServerURL: URL? = DaCo.formulateServerURL(server: server)

    if newServerURL == nil {
      self.serverURL = nil

      throw DaCoError.invalidServerURL("Couldn't form URL from PROTOCOLTYPE: \(self.server.protocolType) HOST: \(self.server.host), PORT: \(self.server.port), ENDPOINT: \(self.server.endPoint)")
    }

    self.serverURL = newServerURL!

    self.startServer()
  }

  private func post(body: Data?, completionHandler: @escaping @Sendable (Data?, URLResponse?, (any Error)?) -> Void) {
    var req: URLRequest = .init(url: self.serverURL!)
    req.allowsCellularAccess = false
    req.httpShouldUsePipelining = true
    req.httpMethod = "POST"

    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    for header in self.server.headers {
      req.setValue(header.value, forHTTPHeaderField: header.field)
    }

    req.httpBody = body

    let task: URLSessionDataTask = URLSession.shared.dataTask(with: req, completionHandler: completionHandler)
    task.resume()
  }

  private func startServer() {
    self.serverStarting = true

    if self.serverURL == nil {
      return
    }

    let body: Data? = """
      {
        "type": "start",
        "timestamp": "\(Date.now.timeIntervalSince1970)",
        "device": {
          "systemVersion": "\(self.deviceInfo.systemVersion)",
          "systemName": "\(self.deviceInfo.systemName)",
          "name": "\(self.deviceInfo.name)",
          "identifierForVendor": "\(self.deviceInfo.identifierForVendor?.uuidString ?? "")",
          "model": "\(self.deviceInfo.model)",
          "localizedModel": "\(self.deviceInfo.localizedModel)"
        }
      }
    """.data(using: .utf8)

    self.post(body: body) { data, res, err in
      let httpRes: HTTPURLResponse? = (res as? HTTPURLResponse)

      if data != nil, err == nil, httpRes?.statusCode == 200 {
        self.serverUUID = String(decoding: data!, as: UTF8.self)

        self.serverStarted = true
        self.serverStarting = false

        if !self.serverActive {
          self.serverActive = true

          if self.onServerActiveChangeCallback != nil {
            self.onServerActiveChangeCallback!(true)
          }
        }
      } else {
        if self.serverActive {
          self.serverActive = false

          if self.onServerActiveChangeCallback != nil {
            self.onServerActiveChangeCallback!(false)
          }
        }

        self.startServer()
      }
    }
  }

  private func startUpdateTimer() {
    if self.timer != nil {
      self.timer!.invalidate()
    }

    self.timer = Timer(
      fire: Date(),
      interval: self.dataUpdateInterval,
      repeats: true,
      block: { _ in
        self.attitude.pitch.append(self.motion.deviceMotion?.attitude.pitch ?? 0)
        self.attitude.roll.append(self.motion.deviceMotion?.attitude.roll ?? 0)
        self.attitude.yaw.append(self.motion.deviceMotion?.attitude.yaw ?? 0)

        self.acceleration.x.append(self.motion.accelerometerData?.acceleration.x ?? 0)
        self.acceleration.y.append(self.motion.accelerometerData?.acceleration.y ?? 0)
        self.acceleration.z.append(self.motion.accelerometerData?.acceleration.z ?? 0)

        self.magneticField.x.append(self.motion.magnetometerData?.magneticField.x ?? 0)
        self.magneticField.y.append(self.motion.magnetometerData?.magneticField.y ?? 0)
        self.magneticField.z.append(self.motion.magnetometerData?.magneticField.z ?? 0)

        self.rotation.x.append(self.motion.gyroData?.rotationRate.x ?? 0)
        self.rotation.y.append(self.motion.gyroData?.rotationRate.y ?? 0)
        self.rotation.z.append(self.motion.gyroData?.rotationRate.z ?? 0)

        if self.attitude.pitch.count < 5 {
          return
        }

        if self.shouldPostData {
          self.postData { data in
            self.serverData = data
          }
        }

        self.resetData()
      }
    )
    RunLoop.main.add(self.timer!, forMode: RunLoop.Mode.default)
  }

  private func resetData() {
    self.attitude = .init(pitch: [], roll: [], yaw: [])
    self.acceleration = .init(x: [], y: [], z: [])
    self.magneticField = .init(x: [], y: [], z: [])
    self.rotation = .init(x: [], y: [], z: [])
  }

  private func postData(
    callback: @escaping (Data?) -> Void
  ) {
    if self.serverURL == nil || !self.serverStarted || self.serverUUID == nil {
      return
    }

    let body: Data? = """
    {
      "type": "data",
      "uuid": "\(self.serverUUID!)",
      "timestamp": "\(Date.now.timeIntervalSince1970)",
      "attitude": {
        "pitch": \(self.attitude.pitch),
        "roll": \(self.attitude.roll),
        "yaw": \(self.attitude.yaw)
      },
      "acceleration": {
        "x": \(self.acceleration.x),
        "y": \(self.acceleration.y),
        "z": \(self.acceleration.z)
      },
      "magneticField": {
        "x": \(self.magneticField.x),
        "y": \(self.magneticField.y),
        "z": \(self.magneticField.z)
      },
      "rotation": {
        "x": \(self.rotation.x),
        "y": \(self.rotation.y),
        "z": \(self.rotation.z)
      }
    }
    """.data(using: .utf8)

    self.post(body: body) { data, res, err in
      let httpRes: HTTPURLResponse? = (res as? HTTPURLResponse)

      if err == nil, httpRes?.statusCode == 200 {
        if !self.serverActive {
          self.serverActive = true

          if self.onServerActiveChangeCallback != nil {
            self.onServerActiveChangeCallback!(true)
          }
        }

        if data != nil {
          callback(data)
        } else {
          callback(Data())
        }
      } else if httpRes?.statusCode == 401 {
        if !self.serverStarting {
          self.resetServer()
          self.startServer()
        }
      } else {
        if self.serverActive {
          self.serverActive = false

          if self.onServerActiveChangeCallback != nil {
            self.onServerActiveChangeCallback!(false)
          }
        }

        callback(Data())
      }
    }
  }
}
