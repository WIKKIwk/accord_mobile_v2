import CoreBluetooth
import Flutter
import Foundation

final class XPrinterBluetoothChannel: NSObject, XBLEManagerDelegate, FlutterStreamHandler {
  private static let channelName = "accord/bluetooth_printer"
  private static let discoveryChannelName = "accord/bluetooth_printer/discovery"
  private static let printTimeout: TimeInterval = 25
  private static let scanTimeout: TimeInterval = 6
  private static let writeCharacteristicTimeout: TimeInterval = 8
  private static let writeCharacteristicPollInterval: TimeInterval = 0.1

  private let channel: FlutterMethodChannel
  private let discoveryChannel: FlutterEventChannel
  private let bleManager: XBLEManager

  private var discoveredPeripherals: [String: CBPeripheral] = [:]
  private var scanResult: FlutterResult?
  private var scanWorkItem: DispatchWorkItem?
  private var discoveryEventSink: FlutterEventSink?
  private var discoveryWorkItem: DispatchWorkItem?

  private var printJob: PrintJob?
  private var printWorkItem: DispatchWorkItem?
  private var writeReadyWorkItem: DispatchWorkItem?
  private var writeReadyDeadline: Date?
  private var nextPeripheral: CBPeripheral?
  private var printBusy = false
  private var sendStarted = false

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
    discoveryChannel = FlutterEventChannel(
      name: Self.discoveryChannelName,
      binaryMessenger: messenger
    )
    bleManager = XBLEManager.sharedInstance()
    super.init()

    bleManager.delegate = self
    discoveryChannel.setStreamHandler(self)
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call: call, result: result)
        ?? result(FlutterError(
          code: "bluetooth_channel_unavailable",
          message: "Xprinter Bluetooth channel is unavailable",
          details: nil
        ))
    }
  }

  deinit {
    scanWorkItem?.cancel()
    printWorkItem?.cancel()
    writeReadyWorkItem?.cancel()
    discoveryWorkItem?.cancel()
    bleManager.stopScan()
    bleManager.removeDelegate(self)
    discoveryChannel.setStreamHandler(nil)
    channel.setMethodCallHandler(nil)
  }

  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    discoveryEventSink = events
    discoveredPeripherals.removeAll(keepingCapacity: true)
    discoveryWorkItem?.cancel()
    bleManager.stopScan()
    bleManager.startScan()

    let workItem = DispatchWorkItem { [weak self] in
      self?.finishDiscoveryStream()
    }
    discoveryWorkItem = workItem
    DispatchQueue.main.asyncAfter(
      deadline: .now() + Self.scanTimeout,
      execute: workItem
    )
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    discoveryEventSink = nil
    discoveryWorkItem?.cancel()
    discoveryWorkItem = nil
    bleManager.stopScan()
    return nil
  }

  private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "pairedPrinters":
      pairedPrinters(result: result)
    case "printLabel":
      guard let arguments = call.arguments as? [String: Any] else {
        result(FlutterError(
          code: "bluetooth_print_invalid_payload",
          message: "XP-P323B label payload is invalid",
          details: nil
        ))
        return
      }
      printLabel(arguments: arguments, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func pairedPrinters(result: @escaping FlutterResult) {
    guard scanResult == nil else {
      result(FlutterError(
        code: "bluetooth_scan_busy",
        message: "Bluetooth printer scan is already in progress",
        details: nil
      ))
      return
    }

    discoveredPeripherals.removeAll(keepingCapacity: true)
    scanResult = result
    scanWorkItem?.cancel()

    let workItem = DispatchWorkItem { [weak self] in
      self?.finishScan()
    }
    scanWorkItem = workItem
    bleManager.startScan()
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.scanTimeout, execute: workItem)
  }

  private func finishScan() {
    guard let result = scanResult else {
      return
    }
    scanResult = nil
    scanWorkItem?.cancel()
    scanWorkItem = nil
    bleManager.stopScan()

    let printers = discoveredPeripherals.values
      .sorted { printerName($0) < printerName($1) }
      .map { peripheral in
        [
          "name": printerName(peripheral),
          "address": peripheral.identifier.uuidString,
        ]
      }
    result(printers)
  }

  private func finishDiscoveryStream() {
    guard let eventSink = discoveryEventSink else {
      return
    }
    discoveryWorkItem = nil
    bleManager.stopScan()
    eventSink(["type": "complete"])
  }

  private func printLabel(arguments: [String: Any], result: @escaping FlutterResult) {
    guard !printBusy else {
      result(FlutterError(
        code: "bluetooth_printer_busy",
        message: "XP-P323B print is already in progress",
        details: nil
      ))
      return
    }

    let address = string(arguments["mac_address"])
    guard !address.isEmpty else {
      result(FlutterError(
        code: "bluetooth_printer_not_selected",
        message: "XP-P323B printer is not selected",
        details: nil
      ))
      return
    }
    guard let label = BluetoothLabelRequest(arguments: arguments) else {
      result(FlutterError(
        code: "bluetooth_print_invalid_payload",
        message: "XP-P323B label payload is invalid",
        details: nil
      ))
      return
    }

    printBusy = true
    printJob = PrintJob(address: normalize(address), label: label, result: result)
    sendStarted = false
    writeReadyDeadline = Date().addingTimeInterval(Self.writeCharacteristicTimeout)
    printWorkItem?.cancel()
    let workItem = DispatchWorkItem { [weak self] in
      self?.finishPrintError(
        code: "bluetooth_print_timeout",
        message: "XP-P323B Bluetooth connection or write timed out"
      )
    }
    printWorkItem = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.printTimeout, execute: workItem)

    if let peripheral = discoveredPeripherals[normalize(address)] {
      connect(to: peripheral)
      return
    }

    if let peripheral = bleManager.writePeripheral,
       normalize(peripheral.identifier.uuidString) == normalize(address),
       bleManager.isConnected {
      waitForWriteCharacteristic()
      return
    }

    // iOS does not expose Android-style bonded-device MAC addresses. The
    // Flutter profile carries the CoreBluetooth UUID returned by this scan.
    bleManager.startScan()
  }

  private func connect(to peripheral: CBPeripheral) {
    guard let job = printJob else {
      return
    }

    if bleManager.isConnected,
       let connected = bleManager.writePeripheral,
       connected.identifier == peripheral.identifier {
      waitForWriteCharacteristic()
      return
    }

    if bleManager.isConnected {
      nextPeripheral = peripheral
      bleManager.disconnectRootPeripheral()
      return
    }

    if normalize(peripheral.identifier.uuidString) == job.address {
      bleManager.connectDevice(peripheral)
    } else {
      finishPrintError(
        code: "bluetooth_printer_not_found",
        message: "Selected XP-P323B printer was not found"
      )
    }
  }

  private func sendPendingPrint() {
    guard let job = printJob, !sendStarted else {
      return
    }
    guard hasWriteCharacteristic else {
      waitForWriteCharacteristic()
      return
    }
    guard let peripheral = bleManager.writePeripheral else {
      finishPrintError(
        code: "bluetooth_connect_failed",
        message: "XP-P323B Bluetooth peripheral is not connected"
      )
      return
    }

    sendStarted = true

    do {
      let data = try buildLabelCommand(job.label)
      let packageSize = max(
        peripheral.maximumWriteValueLength(for: .withoutResponse),
        20
      )

      bleManager.send(data, withPackageSize: UInt(packageSize)) { [weak self] success, _, _, progress, error in
        DispatchQueue.main.async {
          guard let self, self.printJob != nil else {
            return
          }
          if success && progress >= 1 {
            self.finishPrintSuccess(bytes: data.count, peripheral: peripheral)
          } else if !success {
            self.finishPrintError(
              code: "bluetooth_send_failed",
              message: error?.localizedDescription ?? "XP-P323B Bluetooth write failed"
            )
          }
        }
      }
    } catch {
      finishPrintError(code: "bluetooth_print_failed", message: error.localizedDescription)
    }
  }

  private var hasWriteCharacteristic: Bool {
    guard bleManager.isConnected,
          bleManager.writePeripheral != nil,
          let characteristic = bleManager.write_characteristic else {
      return false
    }
    return characteristic.properties.contains(.write) ||
      characteristic.properties.contains(.writeWithoutResponse)
  }

  private func waitForWriteCharacteristic() {
    guard printJob != nil, !sendStarted else {
      return
    }

    writeReadyWorkItem?.cancel()
    writeReadyWorkItem = nil

    if hasWriteCharacteristic {
      sendPendingPrint()
      return
    }

    guard let deadline = writeReadyDeadline, Date() < deadline else {
      finishPrintError(
        code: "bluetooth_connect_failed",
        message: "XP-P323B Bluetooth write characteristic was not ready"
      )
      return
    }

    let workItem = DispatchWorkItem { [weak self] in
      self?.waitForWriteCharacteristic()
    }
    writeReadyWorkItem = workItem
    DispatchQueue.main.asyncAfter(
      deadline: .now() + Self.writeCharacteristicPollInterval,
      execute: workItem
    )
  }

  private func finishPrintSuccess(bytes: Int, peripheral: CBPeripheral) {
    guard let job = printJob else {
      return
    }
    printWorkItem?.cancel()
    printWorkItem = nil
    writeReadyWorkItem?.cancel()
    writeReadyWorkItem = nil
    writeReadyDeadline = nil
    printJob = nil
    printBusy = false
    sendStarted = false
    job.result([
      "ok": true,
      "status": "done",
      "bytes": bytes,
      "deviceName": printerName(peripheral),
      "address": peripheral.identifier.uuidString,
      "label_count": job.label.printCount,
      "printer_status": "Bluetooth OK",
    ])
  }

  private func finishPrintError(code: String, message: String) {
    guard let job = printJob else {
      return
    }
    printWorkItem?.cancel()
    printWorkItem = nil
    writeReadyWorkItem?.cancel()
    writeReadyWorkItem = nil
    writeReadyDeadline = nil
    printJob = nil
    nextPeripheral = nil
    printBusy = false
    sendStarted = false
    if bleManager.isConnected {
      bleManager.disconnectRootPeripheral()
    }
    job.result(FlutterError(code: code, message: message, details: nil))
  }

  private func buildLabelCommand(_ label: BluetoothLabelRequest) throws -> Data {
    var command: XTSPLCommand? = XTSPLCommand()
    command = command?.sizeMm(58, height: 60)
    command = command?.speed(4)
    command = command?.density(10)
    command = command?.referenceAt(x: 80, y: 0)
    command = command?.cls()

    switch label.labelKind {
    case "qolip_cell", "qr_center":
      command = appendQolipCell(command, label: label)
    case "qolip_code", "material_product":
      command = appendLargeQr(command, label: label)
    default:
      command = appendPackLabel(command, label: label)
    }

    command = command?.print(Int32(label.printCount), n: 1, taskId: UUID().uuidString)
    guard let data = command?.getCommand(), !data.isEmpty else {
      throw PrintError.commandGenerationFailed
    }
    return data
  }

  private func appendQolipCell(
    _ command: XTSPLCommand?,
    label: BluetoothLabelRequest
  ) -> XTSPLCommand? {
    let title = fitLabelText(
      cleanLabelText(label.itemName.isEmpty ? label.itemCode : label.itemName),
      maxLength: 18
    )
    let titleX = max(8, min(392, (400 - title.count * 24) / 2))
    var result = command
    result = text(result, x: titleX, y: 12, font: kFNT_16_24, value: title)
    result = qr(result, x: 68, y: 82, value: requiredPayload(label.epc), cellWidth: 8)
    return result
  }

  private func appendLargeQr(
    _ command: XTSPLCommand?,
    label: BluetoothLabelRequest
  ) -> XTSPLCommand? {
    let payload = requiredPayload(label.epc)
    let rawTitle = label.labelKind == "material_product"
      ? materialProductTitle(label)
      : (label.itemName.isEmpty ? label.itemCode : label.itemName)
    let titleLines = wrapLabelText(cleanLabelText(rawTitle), width: 25).prefix(2)

    var result = command
    for (index, line) in titleLines.enumerated() {
      result = text(result, x: 8, y: 6 + index * 26, font: kFNT_12_20, value: line)
    }
    result = qr(result, x: 68, y: 66, value: payload, cellWidth: 8)
    result = text(
      result,
      x: 8,
      y: 362,
      font: kFNT_8_12,
      value: fitLabelText(largeQrFooter(label, payload: payload), maxLength: 38)
    )
    return result
  }

  private func appendPackLabel(
    _ command: XTSPLCommand?,
    label: BluetoothLabelRequest
  ) -> XTSPLCommand? {
    let payload = requiredPayload(label.epc)
    let product = cleanLabelText(label.itemName.isEmpty ? label.itemCode : label.itemName)
    let productLines = wrapLabelText(product, width: 24).prefix(3)
    let quantityUnit = cleanLabelText(
      label.isProgress && !label.progressUnit.isEmpty
        ? label.progressUnit
        : (label.unit.isEmpty ? "kg" : label.unit)
    )
    let grossUnit = cleanLabelText(label.unit.isEmpty ? "kg" : label.unit)
    let quantityLabel = label.isProgress ? "METRAJ" : "NETTO"
    let quantity = label.isProgress ? (label.progressQty ?? label.netQty) : label.netQty

    var result = text(command, x: 8, y: 4, font: kFNT_16_24, value: "ACCORD")
    for (index, line) in productLines.enumerated() {
      result = text(result, x: 8, y: 34 + index * 24, font: kFNT_12_20, value: line)
    }
    result = text(
      result,
      x: 8,
      y: 112,
      font: kFNT_12_20,
      value: "\(quantityLabel): \(formatLabelQty(quantity)) \(quantityUnit)"
    )
    result = text(
      result,
      x: 8,
      y: 138,
      font: kFNT_12_20,
      value: "BRUTTO: \(formatLabelQty(label.grossQty)) \(grossUnit)"
    )
    result = qr(result, x: 218, y: 166, value: payload, cellWidth: 5)
    result = result?.barcodeAt(
      x: Int32(8),
      y: Int32(252),
      codeType: kBarcodeTypeCode128,
      height: Int32(50),
      readable: .left,
      andRotation: .rotation0,
      narrow: Int32(2),
      wide: Int32(2),
      content: payload
    )
    result = text(
      result,
      x: 8,
      y: 314,
      font: kFNT_8_12,
      value: fitLabelText("EPC: \(payload)", maxLength: 46)
    )
    return result
  }

  private func text(
    _ command: XTSPLCommand?,
    x: Int,
    y: Int,
    font: String,
    value: String
  ) -> XTSPLCommand? {
    command?.textAt(
      x: Int32(x),
      y: Int32(y),
      font: font,
      rotation: .rotation0,
      xRatio: 1,
      yRatio: 1,
      content: cleanLabelText(value)
    )
  }

  private func qr(
    _ command: XTSPLCommand?,
    x: Int,
    y: Int,
    value: String,
    cellWidth: Int
  ) -> XTSPLCommand? {
    command?.qrCodeAt(
      x: Int32(x),
      andY: Int32(y),
      ecLevel: kECLevelH,
      cellWidth: Int32(cellWidth),
      mode: kQRCodeModeAuto,
      rotation: .rotation0,
      content: value
    )
  }

  private func requiredPayload(_ value: String) -> String {
    let payload = cleanLabelText(value)
    return payload.isEmpty ? "?" : payload
  }

  private func materialProductTitle(_ label: BluetoothLabelRequest) -> String {
    let name = label.itemName.isEmpty ? label.itemCode : label.itemName
    let unit = label.unit.isEmpty ? "kg" : label.unit
    let net = compactLabelQty(label.netQty)
    if label.tareEnabled && label.tareKg > 0 {
      return "\(name)  B:\(compactLabelQty(label.grossQty)) \(unit) N:\(net) \(unit)"
    }
    return "\(name)  \(net) \(unit)"
  }

  private func largeQrFooter(_ label: BluetoothLabelRequest, payload: String) -> String {
    if label.labelKind == "material_product" {
      return "EPC: \(payload)"
    }
    if label.labelKind == "qolip_code", payload.hasPrefix("RPS-BATCH:") {
      return "BATCH ID: \(payload.dropFirst("RPS-BATCH:".count))"
    }
    return label.itemCode.isEmpty ? payload : label.itemCode
  }

  private func cleanLabelText(_ value: String) -> String {
    let replacements = value
      .replacingOccurrences(of: "‘", with: "'")
      .replacingOccurrences(of: "’", with: "'")
      .replacingOccurrences(of: "`", with: "'")
      .replacingOccurrences(of: "\"", with: "'")
      .replacingOccurrences(of: "\n", with: " ")
      .replacingOccurrences(of: "\r", with: " ")
      .replacingOccurrences(of: "\t", with: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .uppercased(with: Locale(identifier: "en_US_POSIX"))

    let ascii = replacements.unicodeScalars.map { scalar -> String in
      scalar.value >= 32 && scalar.value <= 126 ? String(scalar) : "?"
    }.joined()
    return ascii.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
  }

  private func fitLabelText(_ value: String, maxLength: Int) -> String {
    String(value.prefix(maxLength))
  }

  private func wrapLabelText(_ value: String, width: Int) -> [String] {
    var lines: [String] = []
    var current = ""

    for wordSubstring in value.split(whereSeparator: { $0.isWhitespace }) {
      var rest = String(wordSubstring)
      while rest.count > width {
        if !current.isEmpty {
          lines.append(current)
          current = ""
        }
        lines.append(String(rest.prefix(width)))
        rest = String(rest.dropFirst(width))
      }

      let candidate = current.isEmpty ? rest : "\(current) \(rest)"
      if candidate.count <= width {
        current = candidate
      } else {
        if !current.isEmpty {
          lines.append(current)
        }
        current = rest
      }
    }
    if !current.isEmpty {
      lines.append(current)
    }
    return lines
  }

  private func formatLabelQty(_ value: Double) -> String {
    let rounded = (value * 10).rounded() / 10
    if rounded == rounded.rounded() {
      return String(Int(rounded))
    }
    return String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), rounded)
  }

  private func compactLabelQty(_ value: Double) -> String {
    var text = String(format: "%.3f", locale: Locale(identifier: "en_US_POSIX"), value)
    while text.last == "0" {
      text.removeLast()
    }
    if text.last == "." {
      text.removeLast()
    }
    return text
  }

  private func printerName(_ peripheral: CBPeripheral) -> String {
    let name = peripheral.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return name.isEmpty ? "XP-P323B" : name
  }

  private func isXpP323b(_ name: String) -> Bool {
    let normalized = name.uppercased().replacingOccurrences(of: "-", with: "")
      .replacingOccurrences(of: "_", with: "").replacingOccurrences(of: " ", with: "")
    return normalized.contains("XPP323B") || normalized.contains("P323B")
  }

  private func normalize(_ value: String) -> String {
    value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
  }

  private func string(_ value: Any?) -> String {
    (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
  }

  // MARK: - XBLEManagerDelegate

  func xbleDiscover(
    _ peripheral: CBPeripheral!,
    advertisementData: [AnyHashable: Any]!,
    rssi RSSI: NSNumber!
  ) {
    guard let peripheral else {
      return
    }
    let advertisedName = advertisementData?[CBAdvertisementDataLocalNameKey] as? String
    let name = advertisedName?.isEmpty == false ? advertisedName! : printerName(peripheral)
    guard isXpP323b(name) else {
      return
    }

    let key = normalize(peripheral.identifier.uuidString)
    let isNew = discoveredPeripherals.updateValue(peripheral, forKey: key) == nil
    if isNew {
      discoveryEventSink?([
        "type": "printer",
        "name": printerName(peripheral),
        "address": peripheral.identifier.uuidString,
      ])
    }
    if let job = printJob,
       job.address == key {
      bleManager.stopScan()
      connect(to: peripheral)
    }
  }

  func xbleConnect(_ peripheral: CBPeripheral!) {
    guard peripheral != nil else {
      finishPrintError(code: "bluetooth_connect_failed", message: "XP-P323B connection returned no peripheral")
      return
    }
    waitForWriteCharacteristic()
  }

  func xbleFail(toConnect peripheral: CBPeripheral!, error: Error!) {
    finishPrintError(
      code: "bluetooth_connect_failed",
      message: error?.localizedDescription ?? "XP-P323B Bluetooth connection failed"
    )
  }

  func xbleDisconnectPeripheral(_ peripheral: CBPeripheral!, error: Error!) {
    if let nextPeripheral {
      self.nextPeripheral = nil
      bleManager.connectDevice(nextPeripheral)
      return
    }
    if printJob != nil {
      finishPrintError(
        code: "bluetooth_print_interrupted",
        message: error?.localizedDescription ?? "XP-P323B Bluetooth connection interrupted"
      )
    }
  }

  func xbleWriteValue(for characteristic: CBCharacteristic!, error: Error!) {
    if let error, printJob != nil {
      finishPrintError(code: "bluetooth_send_failed", message: error.localizedDescription)
    }
  }

  func xbleReceiveValue(for characteristic: CBCharacteristic!, error: Error!) {}

  func xbleCentralManagerDidUpdateState(_ state: Int) {
    switch state {
    case 2:
      failBluetoothOperation(code: "bluetooth_unavailable", message: "iOS Bluetooth is unsupported")
    case 3:
      failBluetoothOperation(code: "bluetooth_permission_denied", message: "Bluetooth permission denied")
    case 4:
      failBluetoothOperation(code: "bluetooth_disabled", message: "iOS Bluetooth is turned off")
    default:
      break
    }
  }

  func xbleTaskState(_ taskID: String!, state: Int32, message: String!, error: Error!) {}

  func xblePrinterState(_ state: Int32, message: String!, error: Error!) {
    if let error, printJob != nil {
      finishPrintError(code: "bluetooth_print_failed", message: error.localizedDescription)
    }
  }

  private func failBluetoothOperation(code: String, message: String) {
    if scanResult != nil {
      let result = scanResult
      scanResult = nil
      scanWorkItem?.cancel()
      scanWorkItem = nil
      result?(FlutterError(code: code, message: message, details: nil))
    }
    if printJob != nil {
      finishPrintError(code: code, message: message)
    }
  }
}

private struct PrintJob {
  let address: String
  let label: BluetoothLabelRequest
  let result: FlutterResult
}

private enum PrintError: LocalizedError {
  case commandGenerationFailed

  var errorDescription: String? {
    switch self {
    case .commandGenerationFailed:
      return "XP-P323B TSPL command generation failed"
    }
  }
}

private struct BluetoothLabelRequest {
  let epc: String
  let itemCode: String
  let itemName: String
  let grossQty: Double
  let unit: String
  let tareEnabled: Bool
  let tareKg: Double
  let printCount: Int
  let labelKind: String
  let progressQty: Double?
  let progressUnit: String

  init?(arguments: [String: Any]) {
    let epc = (arguments["epc"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let grossQty = (arguments["gross_qty"] as? NSNumber)?.doubleValue ?? 0
    let tareKg = (arguments["tare_kg"] as? NSNumber)?.doubleValue ?? 0
    let printCount = (arguments["print_count"] as? NSNumber)?.intValue ?? 1
    guard !epc.isEmpty, grossQty.isFinite, tareKg.isFinite, (1...100).contains(printCount) else {
      return nil
    }

    self.epc = epc
    itemCode = (arguments["item_code"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    itemName = (arguments["item_name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    self.grossQty = max(0, grossQty)
    unit = (arguments["unit"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
      ? (arguments["unit"] as? String)!.trimmingCharacters(in: .whitespacesAndNewlines)
      : "kg"
    self.tareKg = max(0, tareKg)
    tareEnabled = (arguments["tare_enabled"] as? NSNumber)?.boolValue == true || tareKg > 0
    self.printCount = printCount
    labelKind = ((arguments["label_kind"] as? String) ?? "")
      .trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let progressQty = (arguments["progress_qty"] as? NSNumber)?.doubleValue
    self.progressQty = progressQty?.isFinite == true ? progressQty : nil
    progressUnit = (arguments["progress_unit"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
  }

  var netQty: Double {
    max(0, grossQty - tareKg)
  }

  var isProgress: Bool {
    labelKind == "progress"
  }
}
