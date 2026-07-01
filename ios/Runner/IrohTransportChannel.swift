import Flutter
import Foundation
import IrohLib

final class IrohTransportChannelBridge: NSObject {
  private let channel: FlutterMethodChannel

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "accord/iroh_transport",
      binaryMessenger: messenger
    )
    super.init()
    channel.setMethodCallHandler(handleMethodCall)
  }

  private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isSupported":
      result(true)
    case "reset":
      Task {
        await IrohEndpointStore.shared.reset()
        DispatchQueue.main.async {
          result(nil)
        }
      }
    case "healthCheck":
      guard let arguments = call.arguments as? [String: Any] else {
        result(FlutterError(code: "iroh_invalid_ticket", message: "Arguments missing", details: nil))
        return
      }
      let ticket = (arguments["ticket"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
      let runs = max(arguments["runs"] as? Int ?? 1, 1)
      guard !ticket.isEmpty else {
        result(FlutterError(code: "iroh_invalid_ticket", message: "Iroh endpoint ticket is empty", details: nil))
        return
      }
      Task {
        do {
          let value = try await runHealthCheck(ticket: ticket, runs: runs)
          DispatchQueue.main.async {
            result(value)
          }
        } catch let error as IrohTicketError {
          DispatchQueue.main.async {
            result(FlutterError(code: "iroh_invalid_ticket", message: error.message, details: nil))
          }
        } catch {
          DispatchQueue.main.async {
            result(FlutterError(code: "iroh_connect_failed", message: "\(error)", details: nil))
          }
        }
      }
    case "request":
      guard let arguments = call.arguments as? [String: Any] else {
        result(FlutterError(code: "iroh_request_failed", message: "Arguments missing", details: nil))
        return
      }
      let ticket = (arguments["ticket"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
      let method = (arguments["method"] as? String ?? "GET").trimmingCharacters(in: .whitespacesAndNewlines)
      let path = (arguments["path"] as? String ?? "/").trimmingCharacters(in: .whitespacesAndNewlines)
      let headers = arguments["headers"] as? [String: String] ?? [:]
      let body = (arguments["body"] as? FlutterStandardTypedData)?.data ?? Data()
      guard !ticket.isEmpty else {
        result(FlutterError(code: "iroh_invalid_ticket", message: "Iroh endpoint ticket is empty", details: nil))
        return
      }
      Task {
        do {
          let value = try await runHttpRequest(
            ticket: ticket,
            method: method,
            path: path.isEmpty ? "/" : path,
            headers: headers,
            body: body
          )
          DispatchQueue.main.async {
            result(value)
          }
        } catch let error as IrohTicketError {
          DispatchQueue.main.async {
            result(FlutterError(code: "iroh_invalid_ticket", message: error.message, details: nil))
          }
        } catch let error as IrohRequestError {
          DispatchQueue.main.async {
            result(FlutterError(code: "iroh_request_failed", message: error.message, details: nil))
          }
        } catch {
          DispatchQueue.main.async {
            result(FlutterError(code: "iroh_connect_failed", message: "\(error)", details: nil))
          }
        }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

private func runHealthCheck(ticket: String, runs: Int) async throws -> [String: Any] {
  let endpointAddr = try decodeEndpointTicket(ticket).toEndpointAddr()
  let endpoint = try await IrohEndpointStore.shared.endpoint()
  var statusCode = 0
  var bytes = 0
  var pathInfo = ""
  let started = DispatchTime.now().uptimeNanoseconds

  do {
    for _ in 0..<runs {
      let connection = try await endpoint.connect(addr: endpointAddr, alpn: IrohTransportWire.alpn)
      defer {
        try? connection.close(errorCode: 0, reason: Data("done".utf8))
      }
      let bi = try await connection.openBi()
      let send = bi.send()
      let recv = bi.recv()

      try await send.writeAll(buf: IrohTransportWire.healthRequest)
      try await send.finish()

      let response = try await recv.readToEnd(sizeLimit: IrohTransportWire.maxHttpBytes)
      statusCode = parseStatusCode(response)
      bytes = response.count
      pathInfo = connection.paths().map { path in
        let kind = path.isRelay ? "relay" : (path.isIp ? "direct" : "?")
        let selected = path.isSelected ? "* " : ""
        return "\(selected)\(kind) \(path.remoteAddr) \(path.rttMs)ms"
      }.joined(separator: " | ")
      if statusCode != 200 {
        let body = String(data: response, encoding: .utf8) ?? ""
        throw IrohRequestError(message: "unexpected HTTP status \(statusCode): \(body)")
      }
    }
  } catch {
    await IrohEndpointStore.shared.reset(endpoint)
    throw error
  }

  let totalMs = Double(DispatchTime.now().uptimeNanoseconds - started) / 1_000_000.0
  return [
    "ok": true,
    "statusCode": statusCode,
    "runs": runs,
    "bytes": bytes,
    "totalMs": totalMs,
    "pathInfo": pathInfo,
  ]
}

private func runHttpRequest(
  ticket: String,
  method: String,
  path: String,
  headers: [String: String],
  body: Data
) async throws -> [String: Any] {
  let endpointAddr = try decodeEndpointTicket(ticket).toEndpointAddr()
  let endpoint = try await IrohEndpointStore.shared.endpoint()
  let started = DispatchTime.now().uptimeNanoseconds

  do {
    let connection = try await endpoint.connect(addr: endpointAddr, alpn: IrohTransportWire.alpn)
    defer {
      try? connection.close(errorCode: 0, reason: Data("done".utf8))
    }
    let bi = try await connection.openBi()
    let send = bi.send()
    let recv = bi.recv()

    try await send.writeAll(buf: buildHttpRequest(method: method, path: path, headers: headers, body: body))
    try await send.finish()

    let response = try await recv.readToEnd(sizeLimit: IrohTransportWire.maxHttpBytes)
    let parsed = parseHttpResponse(response)
    let totalMs = Double(DispatchTime.now().uptimeNanoseconds - started) / 1_000_000.0
    return [
      "statusCode": parsed.statusCode,
      "headers": parsed.headers,
      "body": FlutterStandardTypedData(bytes: parsed.body),
      "totalMs": totalMs,
      "pathInfo": connection.paths().map { path in
        let kind = path.isRelay ? "relay" : (path.isIp ? "direct" : "?")
        let selected = path.isSelected ? "* " : ""
        return "\(selected)\(kind) \(path.remoteAddr) \(path.rttMs)ms"
      }.joined(separator: " | "),
    ]
  } catch {
    await IrohEndpointStore.shared.reset(endpoint)
    throw error
  }
}

private actor IrohEndpointStore {
  static let shared = IrohEndpointStore()

  private var cachedEndpoint: Endpoint?

  func endpoint() async throws -> Endpoint {
    if let cachedEndpoint {
      return cachedEndpoint
    }
    let endpoint = try await Endpoint.bind(
      options: EndpointOptions(
        preset: presetN0(),
        alpns: [IrohTransportWire.alpn]
      )
    )
    cachedEndpoint = endpoint
    return endpoint
  }

  func reset(_ endpoint: Endpoint) async {
    guard cachedEndpoint === endpoint else {
      return
    }
    cachedEndpoint = nil
    try? await endpoint.close()
  }

  func reset() async {
    guard let cachedEndpoint else {
      return
    }
    self.cachedEndpoint = nil
    try? await cachedEndpoint.close()
  }
}

private func buildHttpRequest(
  method: String,
  path: String,
  headers: [String: String],
  body: Data
) -> Data {
  var request = Data()
  request.append(Data("\(method.uppercased()) \(path) HTTP/1.1\r\n".utf8))
  request.append(Data("Host: mini-rs-erp\r\n".utf8))
  request.append(Data("Connection: close\r\n".utf8))
  for (name, value) in headers {
    let lowercased = name.lowercased()
    if lowercased == "host" || lowercased == "connection" || lowercased == "content-length" {
      continue
    }
    request.append(Data("\(name): \(value)\r\n".utf8))
  }
  if !body.isEmpty {
    request.append(Data("Content-Length: \(body.count)\r\n".utf8))
  }
  request.append(Data("\r\n".utf8))
  request.append(body)
  return request
}

private enum IrohTransportWire {
  static let alpn = Data("/mini-rs-erp/http/1".utf8)
  static let healthRequest = Data("GET /healthz HTTP/1.1\r\nHost: mini-rs-erp\r\nConnection: close\r\n\r\n".utf8)
  static let maxHttpBytes: UInt32 = 2 * 1024 * 1024
}

private struct DecodedEndpointTicket {
  let endpointId: String
  let relayUrl: String?
  let addresses: [String]

  func toEndpointAddr() throws -> EndpointAddr {
    let id = try EndpointId.fromString(s: endpointId)
    let usableAddresses = relayUrl == nil ? addresses : []
    return EndpointAddr(id: id, relayUrl: relayUrl, addresses: usableAddresses)
  }
}

private struct IrohTicketError: Error {
  let message: String
}

private struct IrohRequestError: Error {
  let message: String
}

private func decodeEndpointTicket(_ ticket: String) throws -> DecodedEndpointTicket {
  let data = try decodeBase64Url(ticket)
  let object = try JSONSerialization.jsonObject(with: data)
  guard let json = object as? [String: Any] else {
    throw IrohTicketError(message: "Iroh endpoint ticket JSON invalid")
  }
  let endpointId = (json["id"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
  if endpointId.isEmpty {
    throw IrohTicketError(message: "Iroh endpoint id is missing")
  }

  var addresses: [String] = []
  var relayUrl: String?
  let addrs = json["addrs"] as? [Any] ?? []
  for entry in addrs {
    if let dict = entry as? [String: Any] {
      if let ip = (dict["Ip"] as? String ?? dict["ip"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
         !ip.isEmpty {
        addresses.append(ip)
      }
      if let relay = (dict["Relay"] as? String ?? dict["relay"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
         !relay.isEmpty {
        relayUrl = relay
      }
    } else if let address = entry as? String {
      let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
      if !trimmed.isEmpty {
        addresses.append(trimmed)
      }
    }
  }

  return DecodedEndpointTicket(
    endpointId: endpointId,
    relayUrl: relayUrl,
    addresses: Array(Set(addresses)).sorted()
  )
}

private func decodeBase64Url(_ value: String) throws -> Data {
  var normalized = value
    .replacingOccurrences(of: "-", with: "+")
    .replacingOccurrences(of: "_", with: "/")
  let remainder = normalized.count % 4
  if remainder > 0 {
    normalized.append(String(repeating: "=", count: 4 - remainder))
  }
  guard let data = Data(base64Encoded: normalized) else {
    throw IrohTicketError(message: "Iroh endpoint ticket decode failed")
  }
  return data
}

private func parseStatusCode(_ response: Data) -> Int {
  guard let text = String(data: response, encoding: .utf8),
        let line = text.split(separator: "\n", maxSplits: 1).first else {
    return 0
  }
  let parts = line.split(separator: " ")
  guard parts.count > 1 else {
    return 0
  }
  return Int(parts[1]) ?? 0
}

private func parseHttpResponse(_ response: Data) -> (statusCode: Int, headers: [String: String], body: Data) {
  let marker = Data("\r\n\r\n".utf8)
  let headerEnd = response.range(of: marker)
  let headerData: Data
  let bodyData: Data
  if let headerEnd {
    headerData = response.subdata(in: response.startIndex..<headerEnd.lowerBound)
    bodyData = response.subdata(in: headerEnd.upperBound..<response.endIndex)
  } else {
    headerData = response
    bodyData = Data()
  }
  let headerText = String(data: headerData, encoding: .utf8) ?? ""
  let lines = headerText
    .components(separatedBy: "\r\n")
    .filter { !$0.isEmpty }
  let statusCode = lines.first?
    .split(separator: " ")
    .dropFirst()
    .first
    .flatMap { Int($0) } ?? 0
  var headers: [String: String] = [:]
  for line in lines.dropFirst() {
    guard let separator = line.firstIndex(of: ":") else {
      continue
    }
    let name = line[..<separator].trimmingCharacters(in: .whitespacesAndNewlines)
    let value = line[line.index(after: separator)...].trimmingCharacters(in: .whitespacesAndNewlines)
    if !name.isEmpty {
      headers[name.lowercased()] = value
    }
  }
  return (statusCode, headers, bodyData)
}
