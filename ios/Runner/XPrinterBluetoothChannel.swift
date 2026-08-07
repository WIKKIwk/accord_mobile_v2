import CoreBluetooth
import Flutter
import Foundation

final class XPrinterBluetoothChannel: NSObject, XBLEManagerDelegate, FlutterStreamHandler {
  private static let channelName = "accord/bluetooth_printer"
  private static let discoveryChannelName = "accord/bluetooth_printer/discovery"
  private static let printTimeout: TimeInterval = 25
  // BLE completion confirms that TSPL bytes were transferred, not that the
  // XP-P323B finished feeding the label. Hold the channel busy for one
  // label's mechanical print time before the next batch item starts.
  private static let printSettlePerLabel: TimeInterval = 1.2
  private static let scanTimeout: TimeInterval = 6
  private static let writeCharacteristicTimeout: TimeInterval = 8
  private static let writeCharacteristicPollInterval: TimeInterval = 0.1
  private static let labelWidthMm: Double = 56.0
  private static let labelHeightMm: Double = 60.0
  // XP-P323B is 203 dpi, so a 56 x 60 mm label is approximately
  // 448 x 480 dots. The printer's physical label origin is a few
  // dots left of the adhesive label, so compensate it at the TSPL
  // origin rather than moving individual objects independently.
  private static let labelWidthDots = 448
  private static let labelHeightDots = 480
  private static let labelReferenceXDots: Int32 = 72
  private static let labelLeftMarginDots = 24
  private static let labelRightMarginDots = 24
  private static let defaultPrintDensity: Int32 = 10
  private static let materialPrintDensity: Int32 = 12
  private static let materialTextBoldOffsetDots = 1
  private static let packQrX = 278
  private static let packQrY = 166
  private static let packEpcY = 328
  private static let progressPackQrY = 250
  private static let progressPackEpcGapDots = 16
  private static let largeQrFooterGapDots = 28
  private static let largeQrFooterLeftShiftDots = 16
  private static let largeQrFooterHeightDots = 24
  private static let qrAlphanumeric = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:"
  private static let labelCodePage = "0"

  private let channel: FlutterMethodChannel
  private let discoveryChannel: FlutterEventChannel
  private let bleManager: XBLEManager

  private var discoveredPeripherals: [String: CBPeripheral] = [:]
  private var scanResult: FlutterResult?
  private var scanWorkItem: DispatchWorkItem?
  private var discoveryEventSink: FlutterEventSink?
  private var discoveryWorkItem: DispatchWorkItem?
  private var activeDiscoverySession: Int64?

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
    let session = discoverySession(from: arguments)
    DispatchQueue.main.async { [weak self] in
      guard let self else {
        return
      }
      self.activeDiscoverySession = session
      self.discoveryEventSink = events
      self.discoveredPeripherals.removeAll(keepingCapacity: true)
      self.discoveryWorkItem?.cancel()

      if self.bleManager.isConnected,
         let connectedPeripheral = self.bleManager.writePeripheral,
         self.isXpP323b(self.printerName(connectedPeripheral)) {
        self.handleDiscoveredPrinter(connectedPeripheral)
      }

      if self.printJob == nil {
        self.bleManager.stopScan()
        self.bleManager.startScan()
      }

      let workItem = DispatchWorkItem { [weak self] in
        self?.finishDiscoveryStream(session: session)
      }
      self.discoveryWorkItem = workItem
      DispatchQueue.main.asyncAfter(
        deadline: .now() + Self.scanTimeout,
        execute: workItem
      )
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    let session = discoverySession(from: arguments)
    DispatchQueue.main.async { [weak self] in
      guard let self, self.activeDiscoverySession == session else {
        return
      }
      self.activeDiscoverySession = nil
      self.discoveryEventSink = nil
      self.discoveryWorkItem?.cancel()
      self.discoveryWorkItem = nil
      if self.printJob == nil {
        self.bleManager.stopScan()
      }
    }
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

  private func finishDiscoveryStream(session: Int64) {
    guard activeDiscoverySession == session,
          let eventSink = discoveryEventSink else {
      return
    }
    discoveryWorkItem = nil
    if printJob == nil {
      bleManager.stopScan()
    }
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
    sendStarted = false
    let response: [String: Any] = [
      "ok": true,
      "status": "done",
      "bytes": bytes,
      "deviceName": printerName(peripheral),
      "address": peripheral.identifier.uuidString,
      "label_count": job.label.printCount,
      "printer_status": "Bluetooth OK",
    ]
    let settleDelay = Self.printSettlePerLabel * Double(max(1, job.label.printCount))
    DispatchQueue.main.asyncAfter(deadline: .now() + settleDelay) { [weak self] in
      self?.printBusy = false
      job.result(response)
    }
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
    command = command?.setCharEncoding(String.Encoding.ascii.rawValue)
    command = command?.sizeMm(Self.labelWidthMm, height: Self.labelHeightMm)
    command = command?.speed(4.0)
    let printDensity = label.labelKind == "material_product"
      ? Self.materialPrintDensity
      : Self.defaultPrintDensity
    command = command?.density(printDensity)
    command = command?.referenceAt(x: Self.labelReferenceXDots, y: Int32(0))
    command = command?.cls()
    command = command?.codePage(Self.labelCodePage)

    switch label.labelKind {
    case "qolip_cell", "qr_center":
      command = appendQolipCell(command, label: label)
    case "qolip_code", "paddon_code", "material_product":
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
    let payload = requiredPayload(label.epc)
    let title = fitLabelText(
      cleanLabelText(label.itemName.isEmpty ? label.itemCode : label.itemName),
      maxLength: 16
    )
    let titleX = centeredLabelX(title, charWidth: 24)
    let cellWidth = largeQrCellWidth(payload)
    var result = command
    result = text(result, x: titleX, y: 12, font: kFNT_16_24, value: title)
    result = qr(
      result,
      x: centeredQrX(payload, cellWidth: cellWidth),
      y: centeredQrY(payload, cellWidth: cellWidth),
      value: payload,
      cellWidth: cellWidth
    )
    return result
  }

  private func appendLargeQr(
    _ command: XTSPLCommand?,
    label: BluetoothLabelRequest
  ) -> XTSPLCommand? {
    let payload = requiredPayload(label.epc)
    let rawTitle = label.itemName.isEmpty ? label.itemCode : label.itemName
    let titleLines = largeQrTitleLines(label, rawTitle: rawTitle)
    let titleFont = label.labelKind == "material_product" ? kFNT_14_19 : kFNT_12_20
    let cellWidth = label.labelKind == "material_product"
      ? materialQrCellWidth(payload)
      : largeQrCellWidth(payload)
    let qrX = centeredQrX(payload, cellWidth: cellWidth)
    let qrY = centeredQrY(payload, cellWidth: cellWidth)
    let qrSize = qrSymbolSizeDots(payload, cellWidth: cellWidth)

    var result = command
    for (index, line) in titleLines.enumerated() {
      let titleX = Self.labelLeftMarginDots
      let titleY = 6 + index * 26
      result = text(
        result,
        x: titleX,
        y: titleY,
        font: titleFont,
        value: line
      )
      if label.labelKind == "material_product" {
        result = text(
          result,
          x: titleX + Self.materialTextBoldOffsetDots,
          y: titleY,
          font: titleFont,
          value: line
        )
      }
    }
    result = qr(
      result,
      x: qrX,
      y: qrY,
      value: payload,
      cellWidth: cellWidth
    )
    let footerLimit = label.labelKind == "material_product" ? 32 : 46
    let footer = fitLabelText(
      largeQrFooter(label, payload: payload),
      maxLength: footerLimit
    )
    let footerIsLarge =
      (label.labelKind == "material_product" ||
        label.labelKind == "qolip_code" ||
        label.labelKind == "paddon_code") &&
      footer.count <= 32
    let footerFont = footerIsLarge ? kFNT_12_20 : kFNT_8_12
    let footerX = label.labelKind == "material_product" ||
      label.labelKind == "qolip_code" ||
      label.labelKind == "paddon_code"
      ? max(
          Self.labelLeftMarginDots,
          centeredLabelX(footer, charWidth: footerIsLarge ? 12 : 8) -
            Self.largeQrFooterLeftShiftDots
        )
      : Self.labelLeftMarginDots
    result = text(
      result,
      x: footerX,
      y: centeredQrFooterY(qrY: qrY, qrSize: qrSize),
      font: footerFont,
      value: footer
    )
    return result
  }

  private func appendPackLabel(
    _ command: XTSPLCommand?,
    label: BluetoothLabelRequest
  ) -> XTSPLCommand? {
    if label.isProgress {
      return appendProgressPackLabel(command, label: label)
    }
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

    var result = text(
      command,
      x: Self.labelLeftMarginDots,
      y: 4,
      font: kFNT_16_24,
      value: "ACCORD"
    )
    for (index, line) in productLines.enumerated() {
      result = text(
        result,
        x: Self.labelLeftMarginDots,
        y: 34 + index * 24,
        font: kFNT_12_20,
        value: line
      )
    }
    result = text(
      result,
      x: Self.labelLeftMarginDots,
      y: 112,
      font: kFNT_12_20,
      value: "\(quantityLabel): \(formatLabelQty(quantity)) \(quantityUnit)"
    )
    result = text(
      result,
      x: Self.labelLeftMarginDots,
      y: 138,
      font: kFNT_12_20,
      value: "BRUTTO: \(formatLabelQty(label.grossQty)) \(grossUnit)"
    )
    result = qr(
      result,
      x: Self.packQrX,
      y: Self.packQrY,
      value: payload,
      cellWidth: packQrCellWidth(payload)
    )
    let epcIsLarge = payload.count <= 32
    let epcFont = epcIsLarge ? kFNT_12_20 : kFNT_8_12
    let epcText = fitLabelText(payload, maxLength: epcIsLarge ? 32 : 46)
    result = text(
      result,
      x: centeredLabelX(
        epcText,
        charWidth: epcIsLarge ? 12 : 8
      ),
      y: Self.packEpcY,
      font: epcFont,
      value: epcText
    )
    return result
  }

  private func appendProgressPackLabel(
    _ command: XTSPLCommand?,
    label: BluetoothLabelRequest
  ) -> XTSPLCommand? {
    let payload = requiredPayload(label.epc)
    let customer = cleanLabelText(label.customerName.isEmpty ? "-" : label.customerName)
    let product = cleanLabelText(
      label.itemName.isEmpty
        ? (label.itemCode.isEmpty ? "-" : label.itemCode)
        : label.itemName
    )
    let customerLines = wrapLabelText("MIJOZ: \(customer)", width: 21).prefix(2)
    let productLines = wrapLabelText("MAHSULOT NOMI: \(product)", width: 21).prefix(4)
    let metadataLines = Array(customerLines) + Array(productLines)

    var result = command
    var y = 24
    for line in metadataLines {
      result = text(result, x: Self.labelLeftMarginDots, y: y, font: kFNT_12_20, value: line)
      y += 24
    }
    y += 4

    let meterUnit = cleanLabelText(label.progressUnit.isEmpty ? "m" : label.progressUnit)
    let weightUnit = cleanLabelText(label.unit.isEmpty ? "kg" : label.unit)
    result = text(
      result,
      x: Self.labelLeftMarginDots,
      y: y,
      font: kFNT_12_20,
      value: "METRAJ: \(formatLabelQty(label.progressQty ?? label.netQty)) \(meterUnit)"
    )
    y += 24
    result = text(
      result,
      x: Self.labelLeftMarginDots,
      y: y,
      font: kFNT_12_20,
      value: "NETTO: \(formatLabelQty(label.netQty)) \(weightUnit)"
    )
    y += 24
    result = text(
      result,
      x: Self.labelLeftMarginDots,
      y: y,
      font: kFNT_12_20,
      value: "BRUTTO: \(formatLabelQty(label.grossQty)) \(weightUnit)"
    )

    let qrCellWidth = packQrCellWidth(payload)
    let qrSize = qrSymbolSizeDots(payload, cellWidth: qrCellWidth)
    let epcY = min(
      Self.labelHeightDots - 24,
      Self.progressPackQrY + qrSize + Self.progressPackEpcGapDots
    )
    result = qr(
      result,
      x: Self.packQrX,
      y: Self.progressPackQrY,
      value: payload,
      cellWidth: qrCellWidth
    )
    let epcIsLarge = payload.count <= 32
    let epcFont = epcIsLarge ? kFNT_12_20 : kFNT_8_12
    let epcText = fitLabelText(payload, maxLength: epcIsLarge ? 32 : 46)
    result = text(
      result,
      x: centeredLabelX(epcText, charWidth: epcIsLarge ? 12 : 8),
      y: epcY,
      font: epcFont,
      value: epcText
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

  private func largeQrCellWidth(_ value: String) -> Int {
    if value.count <= 32 {
      return 8
    }
    if value.count <= 46 {
      return 7
    }
    return 6
  }

  private func materialQrCellWidth(_ value: String) -> Int {
    min(largeQrCellWidth(value) + 1, 9)
  }

  private func centeredQrX(_ value: String, cellWidth: Int) -> Int {
    let qrSize = qrSymbolSizeDots(value, cellWidth: cellWidth)
    return max(0, (Self.labelWidthDots - qrSize) / 2)
  }

  private func centeredQrY(_ value: String, cellWidth: Int) -> Int {
    let qrSize = qrSymbolSizeDots(value, cellWidth: cellWidth)
    return max(0, (Self.labelHeightDots - qrSize) / 2)
  }

  private func qrSymbolSizeDots(_ value: String, cellWidth: Int) -> Int {
    qrModuleCount(value) * cellWidth
  }

  private func qrModuleCount(_ value: String) -> Int {
    let normalized = value.uppercased()
    let dataLength = normalized.utf8.count
    let isNumeric = normalized.unicodeScalars.allSatisfy { scalar in
      scalar.value >= 48 && scalar.value <= 57
    }
    let isAlphanumeric = normalized.allSatisfy {
      Self.qrAlphanumeric.contains($0)
    }
    let capacities: [Int]
    if isNumeric {
      capacities = [17, 34, 58, 82, 106, 139, 154, 202, 235, 288]
    } else if isAlphanumeric {
      capacities = [10, 20, 35, 50, 64, 84, 93, 122, 143, 174]
    } else {
      capacities = [7, 14, 24, 34, 44, 58, 64, 84, 98, 119]
    }
    let versionIndex = capacities.firstIndex(where: { dataLength <= $0 }) ??
      (capacities.count - 1)
    return 21 + versionIndex * 4
  }

  private func centeredQrFooterY(qrY: Int, qrSize: Int) -> Int {
    min(
      qrY + qrSize + Self.largeQrFooterGapDots,
      Self.labelHeightDots - Self.largeQrFooterHeightDots
    )
  }

  private func packQrCellWidth(_ value: String) -> Int {
    value.count <= 32 ? 5 : 4
  }

  private func largeQrTitleLines(
    _ label: BluetoothLabelRequest,
    rawTitle: String
  ) -> [String] {
    if label.labelKind == "material_product" {
      let productName = cleanLabelText(label.itemName.isEmpty ? label.itemCode : label.itemName)
      let unit = cleanLabelText(label.unit.isEmpty ? "kg" : label.unit)
      let netWeight = compactLabelQty(label.netQty)
      return [
        fitLabelText("MAHSULOT: \(productName)", maxLength: 20),
        fitLabelText("NET VAZNI: \(netWeight) \(unit)", maxLength: 20)
      ]
    }
    if label.labelKind == "qolip_code" && !label.customerName.isEmpty {
      return [
        fitLabelText(cleanLabelText(label.customerName), maxLength: 25),
        fitLabelText(cleanLabelText(rawTitle), maxLength: 25)
      ].filter { !$0.isEmpty }
    }
    return Array(wrapLabelText(cleanLabelText(rawTitle), width: 25).prefix(2))
  }

  private func largeQrFooter(_ label: BluetoothLabelRequest, payload: String) -> String {
    if label.labelKind == "material_product" {
      return payload
    }
    if label.labelKind == "qolip_code", payload.hasPrefix("RPS-BATCH:") {
      return "BATCH ID: \(payload.dropFirst("RPS-BATCH:".count))"
    }
    return label.itemCode.isEmpty ? payload : label.itemCode
  }

  private func centeredLabelX(_ value: String, charWidth: Int) -> Int {
    let availableWidth = Self.labelWidthDots -
      Self.labelLeftMarginDots - Self.labelRightMarginDots
    let textWidth = min(value.count * charWidth, availableWidth)
    let maxX = Self.labelWidthDots - Self.labelRightMarginDots - textWidth
    return max(
      Self.labelLeftMarginDots,
      min((Self.labelWidthDots - textWidth) / 2, maxX)
    )
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

    return replacements.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
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

  private func discoverySession(from arguments: Any?) -> Int64 {
    (arguments as? NSNumber)?.int64Value ?? 0
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
    let peripheralName = printerName(peripheral)
    let isKnownPrinter = isXpP323b(peripheralName) ||
      (advertisedName.map(isXpP323b) ?? false)
    guard isKnownPrinter else {
      return
    }

    DispatchQueue.main.async { [weak self] in
      self?.handleDiscoveredPrinter(peripheral)
    }
  }

  private func handleDiscoveredPrinter(_ peripheral: CBPeripheral) {
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
  let customerName: String
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
    customerName = (arguments["customer_name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
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
