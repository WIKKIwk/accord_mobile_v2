import Flutter
import Foundation
import IrohLib

final class IrohTransportChannelBridge: NSObject {
  private let channel: FlutterMethodChannel
  private var liveTasks: [Int: Task<Void, Never>] = [:]

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
      let reuseConnection = arguments["reuseConnection"] as? Bool ?? false
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
            body: body,
            reuseConnection: reuseConnection
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
    case "startLive":
      guard let arguments = call.arguments as? [String: Any] else {
        result(FlutterError(code: "iroh_live_failed", message: "Arguments missing", details: nil))
        return
      }
      let id = arguments["id"] as? Int ?? 0
      let ticket = (arguments["ticket"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
      let path = (arguments["path"] as? String ?? "/").trimmingCharacters(in: .whitespacesAndNewlines)
      let reuseConnection = arguments["reuseConnection"] as? Bool ?? false
      let sendPings = arguments["sendPings"] as? Bool ?? false
      guard id > 0, !ticket.isEmpty else {
        result(FlutterError(code: "iroh_live_failed", message: "Invalid live stream arguments", details: nil))
        return
      }
      liveTasks[id]?.cancel()
      let channel = channel
      liveTasks[id] = Task {
        do {
          try await runLiveRequest(
            id: id,
            ticket: ticket,
            path: path.isEmpty ? "/" : path,
            reuseConnection: reuseConnection,
            sendPings: sendPings,
            channel: channel
          )
          emitLiveClosed(id: id, channel: channel)
        } catch {
          emitLiveError(id: id, message: "\(error)", channel: channel)
        }
      }
      result(nil)
    case "stopLive":
      guard let arguments = call.arguments as? [String: Any] else {
        result(nil)
        return
      }
      let id = arguments["id"] as? Int ?? 0
      liveTasks.removeValue(forKey: id)?.cancel()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

private actor IrohLiveWriter {
  private let send: SendStream

  init(send: SendStream) {
    self.send = send
  }

  func write(_ data: Data) async throws {
    try await send.writeAll(buf: data)
  }

  func finish() async {
    try? await send.finish()
  }
}

private func runLiveRequest(
  id: Int,
  ticket: String,
  path: String,
  reuseConnection: Bool,
  sendPings: Bool,
  channel: FlutterMethodChannel
) async throws {
  let endpointAddr = try decodeEndpointTicket(ticket).toEndpointAddr()
  let connection: Connection
  if reuseConnection {
    connection = try await IrohEndpointStore.shared.connection(ticket: ticket, addr: endpointAddr)
  } else {
    let endpoint = try await IrohEndpointStore.shared.endpoint()
    connection = try await endpoint.connect(addr: endpointAddr, alpn: IrohTransportWire.alpn)
  }
  defer {
    if !reuseConnection {
      try? connection.close(errorCode: 0, reason: Data("done".utf8))
    }
  }

  let bi = try await connection.openBi()
  let send = bi.send()
  let recv = bi.recv()
  let writer = IrohLiveWriter(send: send)
  try await writer.write(buildWebSocketUpgradeRequest(path: path))

  let (responseHead, remainingBytes) = try await readWebSocketResponseHead(recv: recv)
  let parsed = parseHttpResponse(responseHead)
  guard parsed.statusCode == 101 else {
    let body = String(data: parsed.body, encoding: .utf8) ?? ""
    throw IrohRequestError(message: "unexpected WebSocket status \(parsed.statusCode): \(body)")
  }

  let pingTask: Task<Void, Never>? = sendPings ? Task {
    var pingId = 0
    while !Task.isCancelled {
      pingId += 1
      let payload = """
      {"type":"ping","id":\(pingId),"sent_at_ms":\(unixMilliseconds())}
      """
      try? await writer.write(buildWebSocketFrame(opcode: 0x1, payload: Data(payload.utf8)))
      try? await Task.sleep(nanoseconds: 2_000_000_000)
    }
  } : nil
  defer {
    pingTask?.cancel()
    Task {
      await writer.finish()
    }
  }

  var frameBuffer = [UInt8](remainingBytes)
  try await drainWebSocketFrames(
    id: id,
    buffer: &frameBuffer,
    writer: writer,
    channel: channel
  )

  while !Task.isCancelled {
    let chunk = try await recv.read(sizeLimit: 16 * 1024)
    if chunk.isEmpty {
      break
    }
    frameBuffer.append(contentsOf: chunk)
    try await drainWebSocketFrames(
      id: id,
      buffer: &frameBuffer,
      writer: writer,
      channel: channel
    )
  }
}

private func readWebSocketResponseHead(recv: RecvStream) async throws -> (Data, Data) {
  var buffer = Data()
  let marker = Data("\r\n\r\n".utf8)
  while true {
    let chunk = try await recv.read(sizeLimit: 4096)
    if chunk.isEmpty {
      throw IrohRequestError(message: "WebSocket response ended before headers")
    }
    buffer.append(chunk)
    if let range = buffer.range(of: marker) {
      let head = buffer.subdata(in: buffer.startIndex..<range.upperBound)
      let rest = buffer.subdata(in: range.upperBound..<buffer.endIndex)
      return (head, rest)
    }
    if buffer.count > 64 * 1024 {
      throw IrohRequestError(message: "WebSocket response headers exceed size limit")
    }
  }
}

private func drainWebSocketFrames(
  id: Int,
  buffer: inout [UInt8],
  writer: IrohLiveWriter,
  channel: FlutterMethodChannel
) async throws {
  while let frame = popWebSocketFrame(from: &buffer) {
    switch frame.opcode {
    case 0x1:
      if let text = String(data: frame.payload, encoding: .utf8) {
        emitLiveMessage(id: id, text: text, channel: channel)
      }
    case 0x8:
      try? await writer.write(buildWebSocketFrame(opcode: 0x8, payload: frame.payload))
      return
    case 0x9:
      try await writer.write(buildWebSocketFrame(opcode: 0xA, payload: frame.payload))
    default:
      continue
    }
  }
}

private func popWebSocketFrame(from buffer: inout [UInt8]) -> (opcode: UInt8, payload: Data)? {
  guard buffer.count >= 2 else {
    return nil
  }
  let first = buffer[0]
  let second = buffer[1]
  let opcode = first & 0x0F
  let masked = (second & 0x80) != 0
  var length = Int(second & 0x7F)
  var offset = 2

  if length == 126 {
    guard buffer.count >= offset + 2 else {
      return nil
    }
    length = (Int(buffer[offset]) << 8) | Int(buffer[offset + 1])
    offset += 2
  } else if length == 127 {
    guard buffer.count >= offset + 8 else {
      return nil
    }
    length = 0
    for byte in buffer[offset..<(offset + 8)] {
      length = (length << 8) | Int(byte)
    }
    offset += 8
  }

  var mask: [UInt8] = []
  if masked {
    guard buffer.count >= offset + 4 else {
      return nil
    }
    mask = Array(buffer[offset..<(offset + 4)])
    offset += 4
  }

  guard buffer.count >= offset + length else {
    return nil
  }
  var payload = Array(buffer[offset..<(offset + length)])
  if masked {
    for index in payload.indices {
      payload[index] ^= mask[index % 4]
    }
  }
  buffer.removeFirst(offset + length)
  return (opcode, Data(payload))
}

private func buildWebSocketUpgradeRequest(path: String) -> Data {
  var keyBytes = [UInt8](repeating: 0, count: 16)
  for index in keyBytes.indices {
    keyBytes[index] = UInt8.random(in: 0...255)
  }
  let key = Data(keyBytes).base64EncodedString()
  var request = Data()
  request.append(Data("GET \(path) HTTP/1.1\r\n".utf8))
  request.append(Data("Host: mini-rs-erp\r\n".utf8))
  request.append(Data("Connection: Upgrade\r\n".utf8))
  request.append(Data("Upgrade: websocket\r\n".utf8))
  request.append(Data("Sec-WebSocket-Version: 13\r\n".utf8))
  request.append(Data("Sec-WebSocket-Key: \(key)\r\n".utf8))
  request.append(Data("\r\n".utf8))
  return request
}

private func buildWebSocketFrame(opcode: UInt8, payload: Data) -> Data {
  var frame = Data()
  frame.append(0x80 | opcode)
  let length = payload.count
  if length <= 125 {
    frame.append(0x80 | UInt8(length))
  } else if length <= UInt16.max {
    frame.append(0x80 | 126)
    frame.append(UInt8((length >> 8) & 0xFF))
    frame.append(UInt8(length & 0xFF))
  } else {
    frame.append(0x80 | 127)
    let value = UInt64(length)
    for shift in stride(from: 56, through: 0, by: -8) {
      frame.append(UInt8((value >> UInt64(shift)) & 0xFF))
    }
  }
  var mask = [UInt8](repeating: 0, count: 4)
  for index in mask.indices {
    mask[index] = UInt8.random(in: 0...255)
  }
  frame.append(contentsOf: mask)
  let payloadBytes = [UInt8](payload)
  for index in payloadBytes.indices {
    frame.append(payloadBytes[index] ^ mask[index % 4])
  }
  return frame
}

private func emitLiveMessage(id: Int, text: String, channel: FlutterMethodChannel) {
  DispatchQueue.main.async {
    channel.invokeMethod("liveMessage", arguments: ["id": id, "text": text])
  }
}

private func emitLiveError(id: Int, message: String, channel: FlutterMethodChannel) {
  DispatchQueue.main.async {
    channel.invokeMethod("liveError", arguments: ["id": id, "message": message])
  }
}

private func emitLiveClosed(id: Int, channel: FlutterMethodChannel) {
  DispatchQueue.main.async {
    channel.invokeMethod("liveClosed", arguments: ["id": id])
  }
}

private func unixMilliseconds() -> Int64 {
  Int64(Date().timeIntervalSince1970 * 1000)
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
  body: Data,
  reuseConnection: Bool
) async throws -> [String: Any] {
  let endpointAddr = try decodeEndpointTicket(ticket).toEndpointAddr()
  let started = DispatchTime.now().uptimeNanoseconds

  do {
    let connection: Connection
    if reuseConnection {
      connection = try await IrohEndpointStore.shared.connection(
        ticket: ticket,
        addr: endpointAddr
      )
    } else {
      let endpoint = try await IrohEndpointStore.shared.endpoint()
      connection = try await endpoint.connect(addr: endpointAddr, alpn: IrohTransportWire.alpn)
    }
    defer {
      if !reuseConnection {
        try? connection.close(errorCode: 0, reason: Data("done".utf8))
      }
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
    if reuseConnection {
      await IrohEndpointStore.shared.resetConnection(ticket: ticket)
    }
    throw error
  }
}

private actor IrohEndpointStore {
  static let shared = IrohEndpointStore()

  private var cachedEndpoint: Endpoint?
  private var cachedConnection: Connection?
  private var cachedConnectionTicket: String?

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

  func connection(ticket: String, addr: EndpointAddr) async throws -> Connection {
    if let cachedConnection, cachedConnectionTicket == ticket {
      return cachedConnection
    }
    let endpoint = try await endpoint()
    let connection = try await endpoint.connect(addr: addr, alpn: IrohTransportWire.alpn)
    cachedConnection = connection
    cachedConnectionTicket = ticket
    return connection
  }

  func resetConnection(ticket: String) async {
    guard cachedConnectionTicket == ticket else {
      return
    }
    let connection = cachedConnection
    cachedConnection = nil
    cachedConnectionTicket = nil
    if let connection {
      try? connection.close(errorCode: 0, reason: Data("reset".utf8))
    }
  }

  func reset(_ endpoint: Endpoint) async {
    guard cachedEndpoint === endpoint else {
      return
    }
    if let cachedConnection {
      try? cachedConnection.close(errorCode: 0, reason: Data("reset".utf8))
    }
    cachedConnection = nil
    cachedConnectionTicket = nil
    cachedEndpoint = nil
    try? await endpoint.close()
  }

  func reset() async {
    guard let cachedEndpoint else {
      return
    }
    if let cachedConnection {
      try? cachedConnection.close(errorCode: 0, reason: Data("reset".utf8))
    }
    cachedConnection = nil
    cachedConnectionTicket = nil
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
    return EndpointAddr(id: id, relayUrl: relayUrl, addresses: addresses)
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
