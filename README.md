# DaCo

A data collection library for iOS.

# Server

Server information is passed during initialization and can be later updated via `updateServer(server: Server)`.

All requests are sent as `POST` with `Content-Type: application/json`.

## Starting connection

On initial server connection a request will be sent in the following format

```json
{
  "type": "start",
  "timestamp": "1719634844.78179",
  "device": {
    "systemVersion": "17.0.1",
    "systemName": "iOS",
    "name": "iPhone",
    "identifierForVendor": "00000000-0000-0000-0000-000000000000",
    "model": "iPhone",
    "localizedModel": "iPhone"
  }
}
```

Library expects a UUID to be returned as the response, this will be included in subsequent requests to maintain identity from initial connect.

```typescript
/* Express - Node.js example */

const clientUUID: UUID = crypto.randomUUID();

// ... (Store `clientUUID` for later reference)

res.statusCode = 200;
res.write(clientUUID);
res.end();
```

If the connection was unable to be established or the server returned a status code that isn't `200` then the request will be retried until a successful connection is established.

## Data updates

Data updates are sent in batches of 5 items.

```json
{
  "type": "data",
  "uuid": "00000000-0000-0000-0000-000000000000",
  "timestamp": "1719634844.78179",
  "attitude": {
    "pitch": [0.6947476993167052,0.6933108996086002,0.6924343106478362,0.6920638123997297,0.6921965151560717],
    "roll": [0.009362405351835959,0.012819167814936163,0.012819918570224005,0.009664922517741675,0.007612864271934006],
    "yaw": [0.10601932894410107,0.10580173214983868,0.1055159674145352,0.10536569501951201,0.10462004358924311]
  },
  "acceleration": {
    "x": [-0.0200653076171875,-0.065155029296875,-0.0270538330078125,-0.0596923828125,-0.0323486328125],
    "y": [-0.5857696533203125,-0.663543701171875,-0.6793060302734375,-0.6715087890625,-0.6666259765625],
    "z": [-0.8318328857421875,-0.72760009765625,-0.7347412109375,-0.7714385986328125,-0.763885498046875]
  },
  "magneticField": {
    "x": [192.85919189453125,193.08518981933594,193.23939514160156,193.22933959960938,192.9512481689453],
    "y": [-501.0023193359375,-500.87652587890625,-500.84417724609375,-500.936767578125,-500.9144592285156],
    "z": [-299.186279296875,-298.8155822753906,-298.81634521484375,-298.6399230957031,-299.20330810546875]
  },
  "rotation": {
    "x": [-0.1515679508447647,-0.06737131625413895,-0.04632142558693886,-0.016885505989193916,0.010555705055594444],
    "y": [-0.12437707930803299,0.19235719740390778,-0.05986812710762024,-0.1606900840997696,-0.11434654891490936],
    "z": [-0.018146779388189316,-0.02490801364183426,-0.00037736992817372084,-0.014083328656852245,-0.028778918087482452]
  }
}
```

Any data may be returned from the server for this request and is accessible via the `serverData` property.

If a status code of `401` is returned then the server intialization will start again (See [Starting connection](#starting-connection)).

### Pausing Data Updates

If you wish to pause data updates, you can set `shouldPostData` to `false` (Data will still be collected on the device, but not sent).

## Server Status

The property `serverActive` will reflect whether requests are succesful or failing, you can use this as a status indicator.

### Subscribing to Server Status Changes

You can set a callback using `setOnServerActiveChangeCallback` to be notified of changes to `serverActive`.

## Custom Headers

Custom headers can be added to every request using the `headers` property 
```swift
let server: Server = .init(
  // ...
  headers: [new Header(value: "SOME-KEY-VALUE", field: "secret-key")]
)
```

# Data

## Device Info

Device info is collected on startup and sent during the initial server connection process

```swift
struct DeviceInfo {
  let systemVersion: String
  let systemName: String
  let name: String
  let identifierForVendor: UUID?
  let model: String
  let localizedModel: String
}
```

## Motion

Motion data is continously collected at the rate set by `dataUpdateInterval` (Defaults to `50.0hz`).

```swift
var attitude: Dimensions3Motion<[Double]> = .init(pitch: [], roll: [], yaw: [])
var acceleration: Dimensions3<[Double]> = .init(x: [], y: [], z: [])
var magneticField: Dimensions3<[Double]> = .init(x: [], y: [], z: [])
var rotation: Dimensions3<[Double]> = .init(x: [], y: [], z: [])
```
