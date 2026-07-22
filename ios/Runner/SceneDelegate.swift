import Flutter
import Foundation
import Darwin
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  private var deviceInfoBridge: DeviceInfoChannelBridge?
  private var irohTransportBridge: IrohTransportChannelBridge?
  private var gscaleBonjourBridge: GScaleBonjourDiscoveryBridge?
  private var gscaleUdpDiscoveryBridge: GScaleUdpDiscoveryBridge?
  private var xprinterBluetoothChannel: XPrinterBluetoothChannel?

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)

    if let window, let flutterViewController = window.rootViewController as? FlutterViewController {
      deviceInfoBridge = DeviceInfoChannelBridge(messenger: flutterViewController.binaryMessenger)
      irohTransportBridge = IrohTransportChannelBridge(messenger: flutterViewController.binaryMessenger)
      gscaleBonjourBridge = GScaleBonjourDiscoveryBridge(
        messenger: flutterViewController.binaryMessenger
      )
      gscaleUdpDiscoveryBridge = GScaleUdpDiscoveryBridge(
        messenger: flutterViewController.binaryMessenger
      )
      xprinterBluetoothChannel = XPrinterBluetoothChannel(
        messenger: flutterViewController.binaryMessenger
      )
    }
  }
}

final class NativeBackNavigationController: UINavigationController {
  private let rootFlutterViewController: FlutterViewController
  private var backButtonVisible = false
  private var navigationBarVisible = false
  private var backGestureActive = false
  private lazy var deviceInfoBridge = DeviceInfoChannelBridge(
    messenger: flutterBinaryMessenger
  )
  private lazy var gscaleBonjourBridge = GScaleBonjourDiscoveryBridge(
    messenger: flutterBinaryMessenger
  )
  private lazy var gscaleUdpDiscoveryBridge = GScaleUdpDiscoveryBridge(
    messenger: flutterBinaryMessenger
  )
  private lazy var dockController = NativeTabBarController(
    messenger: flutterBinaryMessenger
  )
  private lazy var backBridge = NativeBackButtonChannelBridge(
    messenger: flutterBinaryMessenger,
    onVisibilityChanged: { [weak self] visible in
      self?.setBackButtonVisible(visible)
    },
    onNavigationBarVisibilityChanged: { [weak self] visible in
      self?.setNavigationBarVisible(visible)
    },
    onTitleChanged: { [weak self] title in
      self?.setNavigationTitle(title)
    },
    onThemeChanged: { [weak self] isDark in
      self?.applyNavigationAppearance(isDark: isDark)
    },
    onGestureChanged: { [weak self] active in
      self?.setBackGestureActive(active)
    }
  )

  private var flutterBinaryMessenger: FlutterBinaryMessenger {
    rootFlutterViewController.binaryMessenger
  }

  init(flutterViewController: FlutterViewController) {
    self.rootFlutterViewController = flutterViewController
    super.init(rootViewController: flutterViewController)
  }

  @available(*, unavailable)
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    _ = backBridge
    _ = deviceInfoBridge
    _ = gscaleBonjourBridge
    _ = gscaleUdpDiscoveryBridge
    navigationBar.prefersLargeTitles = false
    applyNavigationAppearance(isDark: true)
    topViewController?.navigationItem.leftBarButtonItem = makeBackBarButtonItem()
    setNavigationBarHidden(true, animated: false)
    configureDockController()
  }

  private func applyNavigationAppearance(isDark: Bool) {
    let titleColor: UIColor = isDark ? .white : .black
    let appearance = UINavigationBarAppearance()
    appearance.configureWithTransparentBackground()
    appearance.backgroundColor = .clear
    appearance.shadowColor = .clear
    appearance.titleTextAttributes = [
      .foregroundColor: titleColor,
    ]
    appearance.largeTitleTextAttributes = [
      .foregroundColor: titleColor,
    ]
    navigationBar.standardAppearance = appearance
    navigationBar.scrollEdgeAppearance = appearance
    navigationBar.compactAppearance = appearance
    navigationBar.tintColor = titleColor
    overrideUserInterfaceStyle = isDark ? .dark : .light
  }

  private func setBackButtonVisible(_ visible: Bool) {
    if visible == backButtonVisible {
      if visible {
        restoreBackButtonAppearance(animated: true)
      }
      return
    }

    backButtonVisible = visible
    backGestureActive = false

    if visible {
      topViewController?.navigationItem.leftBarButtonItem = makeBackBarButtonItem()
      setNavigationBarHidden(false, animated: false)
      navigationBar.layoutIfNeeded()
      guard let buttonView = currentBackButtonView() else {
        return
      }
      buttonView.alpha = 0
      buttonView.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
      UIView.animate(
        withDuration: 0.18,
        delay: 0,
        options: [.beginFromCurrentState, .curveEaseOut]
      ) {
        buttonView.alpha = 1
        buttonView.transform = .identity
      }
      return
    }

    guard let buttonView = currentBackButtonView() else {
      topViewController?.navigationItem.leftBarButtonItem = nil
      setNavigationBarHidden(!(navigationBarVisible || backButtonVisible), animated: false)
      return
    }
    UIView.animate(
      withDuration: 0.16,
      delay: 0,
      options: [.beginFromCurrentState, .curveEaseInOut]
    ) {
      buttonView.alpha = 0
      buttonView.transform = CGAffineTransform(scaleX: 0.90, y: 0.90)
    } completion: { _ in
      self.topViewController?.navigationItem.leftBarButtonItem = nil
      self.setNavigationBarHidden(!(self.navigationBarVisible || self.backButtonVisible), animated: false)
      buttonView.alpha = 1
      buttonView.transform = .identity
    }
  }

  private func setNavigationBarVisible(_ visible: Bool) {
    navigationBarVisible = visible
    if !visible {
      topViewController?.navigationItem.title = nil
      navigationBar.topItem?.title = nil
    }
    setNavigationBarHidden(!(navigationBarVisible || backButtonVisible), animated: false)
  }

  private func setBackGestureActive(_ active: Bool) {
    backGestureActive = active
    guard backButtonVisible, let buttonView = currentBackButtonView() else {
      return
    }
    UIView.animate(
      withDuration: active ? 0.12 : 0.16,
      delay: 0,
      options: [.beginFromCurrentState, .curveEaseOut]
    ) {
      buttonView.alpha = active ? 0.72 : 1
      buttonView.transform = active
        ? CGAffineTransform(scaleX: 0.94, y: 0.94)
        : .identity
    }
  }

  private func restoreBackButtonAppearance(animated: Bool) {
    guard let buttonView = currentBackButtonView() else {
      return
    }
    let animations = {
      buttonView.alpha = 1
      buttonView.transform = .identity
    }
    if animated {
      UIView.animate(
        withDuration: 0.16,
        delay: 0,
        options: [.beginFromCurrentState, .curveEaseOut],
        animations: animations
      )
    } else {
      animations()
    }
  }

  private func currentBackButtonView() -> UIView? {
    topViewController?.navigationItem.leftBarButtonItem?.value(forKey: "view") as? UIView
  }

  private func setNavigationTitle(_ title: String?) {
    topViewController?.navigationItem.title = title
    navigationBar.topItem?.title = title
  }

  private func makeBackBarButtonItem() -> UIBarButtonItem {
    let configuration = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
    let image = UIImage(systemName: "chevron.backward", withConfiguration: configuration)
    return UIBarButtonItem(
      image: image,
      style: .plain,
      target: self,
      action: #selector(handleBackButtonTap)
    )
  }

  @objc
  private func handleBackButtonTap() {
    backBridge.sendBackPressed()
  }

  private func configureDockController() {
    addChild(dockController)
    dockController.view.translatesAutoresizingMaskIntoConstraints = false
    dockController.view.backgroundColor = .clear
    view.addSubview(dockController.view)
    NSLayoutConstraint.activate([
      dockController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      dockController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      dockController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      dockController.view.heightAnchor.constraint(equalToConstant: 112),
    ])
    dockController.didMove(toParent: self)
  }
}

private final class NativeBackButtonChannelBridge: NSObject {
  private let channel: FlutterMethodChannel
  private let onVisibilityChanged: (Bool) -> Void
  private let onNavigationBarVisibilityChanged: (Bool) -> Void
  private let onTitleChanged: (String?) -> Void
  private let onThemeChanged: (Bool) -> Void
  private let onGestureChanged: (Bool) -> Void

  init(
    messenger: FlutterBinaryMessenger,
    onVisibilityChanged: @escaping (Bool) -> Void,
    onNavigationBarVisibilityChanged: @escaping (Bool) -> Void,
    onTitleChanged: @escaping (String?) -> Void,
    onThemeChanged: @escaping (Bool) -> Void,
    onGestureChanged: @escaping (Bool) -> Void
  ) {
    self.channel = FlutterMethodChannel(
      name: "accord/native_back_button",
      binaryMessenger: messenger
    )
    self.onVisibilityChanged = onVisibilityChanged
    self.onNavigationBarVisibilityChanged = onNavigationBarVisibilityChanged
    self.onTitleChanged = onTitleChanged
    self.onThemeChanged = onThemeChanged
    self.onGestureChanged = onGestureChanged
    super.init()
    channel.setMethodCallHandler(handleMethodCall)
    channel.invokeMethod("nativeBackButtonReady", arguments: nil)
  }

  func sendBackPressed() {
    channel.invokeMethod("nativeBackPressed", arguments: nil)
  }

  private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "setBackButtonVisible":
      let visible = (call.arguments as? Bool) ?? false
      DispatchQueue.main.async {
        self.onVisibilityChanged(visible)
      }
      result(nil)
    case "setNavigationBarVisible":
      let visible = (call.arguments as? Bool) ?? false
      DispatchQueue.main.async {
        self.onNavigationBarVisibilityChanged(visible)
      }
      result(nil)
    case "setBackButtonTitle":
      let title = call.arguments as? String
      DispatchQueue.main.async {
        self.onTitleChanged(title)
      }
      result(nil)
    case "setBackButtonIsDark":
      let isDark = (call.arguments as? Bool) ?? true
      DispatchQueue.main.async {
        self.onThemeChanged(isDark)
      }
      result(nil)
    case "setBackButtonGestureActive":
      let active = (call.arguments as? Bool) ?? false
      DispatchQueue.main.async {
        self.onGestureChanged(active)
      }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

final class NativeTabBarController: UITabBarController, UITabBarControllerDelegate {
  private lazy var dockBridge = NativeDockChannelBridge(
    messenger: messenger,
    onStateChanged: { [weak self] state in
      self?.applyDockState(state)
    }
  )
  private let messenger: FlutterBinaryMessenger
  private var currentState = NativeDockState(arguments: [:])
  private var placeholderControllers: [NativeTabPlaceholderViewController] = []
  private var isApplyingState = false
  private var supportsLiquidDock: Bool {
    if #available(iOS 26.0, *) {
      return true
    }
    return false
  }

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    delegate = self
    view.backgroundColor = .clear
    view.isHidden = true
    setSystemTabBarHidden(true)
    _ = dockBridge
    if #available(iOS 18.0, *) {
      mode = .tabBar
    }
  }

  private func applyDockState(_ state: NativeDockState) {
    isApplyingState = true
    defer { isApplyingState = false }

    guard supportsLiquidDock else {
      view.isHidden = true
      setSystemTabBarHidden(true)
      return
    }

    if currentState == state {
      return
    }

    currentState = state
    let tabItems = state.items

    guard state.visible, !tabItems.isEmpty else {
      view.isHidden = true
      setSystemTabBarHidden(true)
      return
    }

    syncPlaceholders(with: tabItems)
    view.isHidden = false

    if let selectedIndex = tabItems.firstIndex(where: \.active) {
      if self.selectedIndex != selectedIndex {
        self.selectedIndex = selectedIndex
      }
    } else if selectedIndex >= tabItems.count {
      self.selectedIndex = 0
    }

    setSystemTabBarHidden(false)
  }

  private func syncPlaceholders(with items: [NativeDockItem]) {
    let existingIds = placeholderControllers.map(\.itemId)
    let newIds = items.map(\.id)
    if existingIds != newIds {
      placeholderControllers = items.map(NativeTabPlaceholderViewController.init)
      viewControllers = placeholderControllers
    }

    for (index, item) in items.enumerated() {
      let controller = placeholderControllers[index]
      controller.update(with: item)
    }
  }

  private func setSystemTabBarHidden(_ hidden: Bool) {
    if #available(iOS 18.0, *) {
      setTabBarHidden(hidden, animated: false)
    } else {
      tabBar.isHidden = hidden
    }
  }

  func tabBarController(
    _ tabBarController: UITabBarController,
    didSelect viewController: UIViewController
  ) {
    guard let placeholder = viewController as? NativeTabPlaceholderViewController else {
      return
    }
    guard !isApplyingState else {
      return
    }
    dockBridge.sendTap(id: placeholder.itemId)
  }
}

private final class NativeTabPlaceholderViewController: UIViewController {
  private(set) var itemId: String
  private let stableTabBarItem = UITabBarItem()

  init(item: NativeDockItem) {
    itemId = item.id
    super.init(nibName: nil, bundle: nil)
    tabBarItem = stableTabBarItem
    update(with: item)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .clear
  }

  func update(with item: NativeDockItem) {
    itemId = item.id
    let imageConfig = UIImage.SymbolConfiguration(
      pointSize: item.primary ? 19 : 17,
      weight: item.primary ? .bold : .semibold
    )
    stableTabBarItem.title = nil
    stableTabBarItem.image = UIImage(systemName: item.symbol, withConfiguration: imageConfig)
    stableTabBarItem.selectedImage = UIImage(
      systemName: item.selectedSymbol ?? item.symbol,
      withConfiguration: imageConfig
    )
    stableTabBarItem.badgeValue = item.showBadge ? " " : nil
    if item.primary {
      stableTabBarItem.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: 100)
      stableTabBarItem.imageInsets = UIEdgeInsets(top: -1, left: 0, bottom: 1, right: 0)
    } else {
      stableTabBarItem.titlePositionAdjustment = .zero
      stableTabBarItem.imageInsets = .zero
    }
  }
}

private final class NativeDockChannelBridge: NSObject {
  private let channel: FlutterMethodChannel
  private let onStateChanged: (NativeDockState) -> Void

  init(
    messenger: FlutterBinaryMessenger,
    onStateChanged: @escaping (NativeDockState) -> Void
  ) {
    self.channel = FlutterMethodChannel(
      name: "accord/native_dock",
      binaryMessenger: messenger
    )
    self.onStateChanged = onStateChanged
    super.init()
    channel.setMethodCallHandler(handleMethodCall)
    let isSupported: Bool
    if #available(iOS 26.0, *) {
      isSupported = true
    } else {
      isSupported = false
    }
    channel.invokeMethod("nativeDockReady", arguments: isSupported)
  }

  func sendTap(id: String) {
    channel.invokeMethod("nativeDockTap", arguments: id)
  }

  func sendLongPress(id: String) {
    channel.invokeMethod("nativeDockLongPress", arguments: id)
  }

  private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "setDockState":
      let state = NativeDockState(arguments: call.arguments as? [String: Any] ?? [:])
      DispatchQueue.main.async {
        self.onStateChanged(state)
      }
      result(nil)
    case "isSystemDockSupported":
      if #available(iOS 26.0, *) {
        result(true)
      } else {
        result(false)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

private struct NativeDockState: Equatable {
  let visible: Bool
  let compact: Bool
  let tightToEdges: Bool
  let items: [NativeDockItem]

  init(arguments: [String: Any]) {
    visible = arguments["visible"] as? Bool ?? false
    compact = arguments["compact"] as? Bool ?? true
    tightToEdges = arguments["tightToEdges"] as? Bool ?? true
    let rawItems = arguments["items"] as? [[String: Any]] ?? []
    items = rawItems.map(NativeDockItem.init)
  }
}

private struct NativeDockItem: Equatable {
  let id: String
  let symbol: String
  let selectedSymbol: String?
  let active: Bool
  let primary: Bool
  let showBadge: Bool
  let supportsLongPress: Bool

  init(arguments: [String: Any]) {
    id = arguments["id"] as? String ?? UUID().uuidString
    symbol = arguments["symbol"] as? String ?? "circle"
    selectedSymbol = arguments["selectedSymbol"] as? String
    active = arguments["active"] as? Bool ?? false
    primary = arguments["primary"] as? Bool ?? false
    showBadge = arguments["showBadge"] as? Bool ?? false
    supportsLongPress = arguments["supportsLongPress"] as? Bool ?? false
  }
}

private final class DeviceInfoChannelBridge: NSObject {
  private let channel: FlutterMethodChannel

  init(messenger: FlutterBinaryMessenger) {
    self.channel = FlutterMethodChannel(
      name: "accord/device_info",
      binaryMessenger: messenger
    )
    super.init()
    channel.setMethodCallHandler(handleMethodCall)
  }

  private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isIOSSimulator":
      #if targetEnvironment(simulator)
      result(true)
      #else
      result(false)
      #endif
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

private final class GScaleUdpDiscoveryBridge: NSObject {
  private let channel: FlutterMethodChannel
  private let queue = DispatchQueue(label: "gscale.udp.discovery", qos: .userInitiated)

  init(messenger: FlutterBinaryMessenger) {
    self.channel = FlutterMethodChannel(
      name: "gscale/udp_discovery",
      binaryMessenger: messenger
    )
    super.init()
    channel.setMethodCallHandler(handleMethodCall)
  }

  private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "discoverAnnouncements":
      let args = call.arguments as? [String: Any]
      let port = args?["port"] as? Int ?? 18081
      let timeoutMs = max(300, args?["timeout_ms"] as? Int ?? 900)
      queue.async { [weak self] in
        let items = self?.discover(port: port, timeoutMs: timeoutMs) ?? []
        DispatchQueue.main.async {
          result(items)
        }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func discover(port: Int, timeoutMs: Int) -> [[String: Any]] {
    let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
    guard fd >= 0 else {
      return []
    }
    defer {
      close(fd)
    }

    var yes: Int32 = 1
    setsockopt(fd, SOL_SOCKET, SO_BROADCAST, &yes, socklen_t(MemoryLayout<Int32>.size))
    setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))

    var bindAddress = sockaddr_in()
    bindAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    bindAddress.sin_family = sa_family_t(AF_INET)
    bindAddress.sin_port = in_port_t(0).bigEndian
    bindAddress.sin_addr = in_addr(s_addr: INADDR_ANY.bigEndian)
    let bindStatus = withUnsafePointer(to: &bindAddress) { pointer in
      pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
        Darwin.bind(fd, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_in>.size))
      }
    }
    guard bindStatus == 0 else {
      return []
    }

    let packet = Array("GSCALE_DISCOVER_V1".utf8)
    let targets = broadcastTargets()
    let startedAt = Date()
    for attempt in 0..<3 {
      for target in targets {
        send(packet, to: target, port: port, socket: fd)
      }
      if attempt != 2 {
        usleep(120_000)
      }
    }

    let deadline = Date().addingTimeInterval(Double(timeoutMs) / 1000.0)
    var out: [String: [String: Any]] = [:]
    while Date() < deadline {
      var readSet = fd_set()
      fdZero(&readSet)
      fdSet(fd, &readSet)

      let remaining = max(0.0, deadline.timeIntervalSinceNow)
      var timeout = timeval(
        tv_sec: Int(remaining),
        tv_usec: Int32((remaining.truncatingRemainder(dividingBy: 1.0)) * 1_000_000)
      )
      let selected = select(fd + 1, &readSet, nil, nil, &timeout)
      if selected <= 0 {
        continue
      }

      var buffer = [UInt8](repeating: 0, count: 4096)
      var from = sockaddr_in()
      var fromLen = socklen_t(MemoryLayout<sockaddr_in>.size)
      let count = withUnsafeMutablePointer(to: &from) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
          recvfrom(fd, &buffer, buffer.count, 0, sockaddrPointer, &fromLen)
        }
      }
      if count <= 0 {
        continue
      }
      guard let item = discoveryItem(
        from: Array(buffer.prefix(count)),
        address: from,
        latencyMs: max(1, Int(Date().timeIntervalSince(startedAt) * 1000))
      ) else {
        continue
      }
      let key = "\(item["server_ref"] ?? "")|\(item["server_name"] ?? "")|\(item["host"] ?? "")"
      out[key] = item
    }

    return Array(out.values)
  }

  private func send(_ packet: [UInt8], to target: String, port: Int, socket fd: Int32) {
    var address = sockaddr_in()
    address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    address.sin_family = sa_family_t(AF_INET)
    address.sin_port = in_port_t(port).bigEndian
    inet_pton(AF_INET, target, &address.sin_addr)
    packet.withUnsafeBytes { bytes in
      _ = withUnsafePointer(to: &address) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
          sendto(fd, bytes.baseAddress, bytes.count, 0, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_in>.size))
        }
      }
    }
  }

  private func discoveryItem(from data: [UInt8], address: sockaddr_in, latencyMs: Int) -> [String: Any]? {
    guard
      let json = try? JSONSerialization.jsonObject(with: Data(data)) as? [String: Any],
      (json["service"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) == "mobileapi"
    else {
      return nil
    }

    var addr = address.sin_addr
    var hostBuffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
    guard inet_ntop(AF_INET, &addr, &hostBuffer, socklen_t(hostBuffer.count)) != nil else {
      return nil
    }
    let host = String(cString: hostBuffer)
    let httpPort = intValue(json["http_port"]) ?? 39117
    return [
      "host": host,
      "http_port": httpPort,
      "server_name": textValue(json["server_name"], fallback: host),
      "server_ref": textValue(json["server_ref"], fallback: ""),
      "display_name": textValue(json["display_name"], fallback: "Operator"),
      "role": textValue(json["role"], fallback: "operator"),
      "latency_ms": latencyMs,
    ]
  }

  private func broadcastTargets() -> [String] {
    var targets = Set(["255.255.255.255"])
    var ifaddr: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&ifaddr) == 0 else {
      return Array(targets)
    }
    defer {
      freeifaddrs(ifaddr)
    }

    var pointer = ifaddr
    while pointer != nil {
      guard let interface = pointer?.pointee else {
        break
      }
      pointer = interface.ifa_next
      let flags = Int32(interface.ifa_flags)
      guard
        flags & IFF_UP != 0,
        flags & IFF_BROADCAST != 0,
        let address = interface.ifa_addr,
        let netmask = interface.ifa_netmask,
        address.pointee.sa_family == sa_family_t(AF_INET)
      else {
        continue
      }
      let ip = address.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
        UInt32(bigEndian: $0.pointee.sin_addr.s_addr)
      }
      if !isPrivateIPv4(ip) {
        continue
      }
      let mask = netmask.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
        UInt32(bigEndian: $0.pointee.sin_addr.s_addr)
      }
      let broadcast = (ip & mask) | ~mask
      targets.insert(ipv4String(broadcast))
    }
    return Array(targets)
  }

  private func isPrivateIPv4(_ ip: UInt32) -> Bool {
    let first = (ip >> 24) & 0xff
    let second = (ip >> 16) & 0xff
    return first == 10 || (first == 172 && second >= 16 && second <= 31) || (first == 192 && second == 168)
  }

  private func ipv4String(_ ip: UInt32) -> String {
    return "\(ip >> 24 & 0xff).\(ip >> 16 & 0xff).\(ip >> 8 & 0xff).\(ip & 0xff)"
  }

  private func textValue(_ value: Any?, fallback: String) -> String {
    let text = (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return text.isEmpty ? fallback : text
  }

  private func intValue(_ value: Any?) -> Int? {
    if let value = value as? Int {
      return value
    }
    if let value = value as? String {
      return Int(value.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    return nil
  }

  private func fdZero(_ set: inout fd_set) {
    set.fds_bits = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
  }

  private func fdSet(_ fd: Int32, _ set: inout fd_set) {
    let bitsPerElement = MemoryLayout<Int32>.size * 8
    let intOffset = Int(fd) / bitsPerElement
    let bitOffset = Int(fd) % bitsPerElement
    let mask = Int32(1 << bitOffset)
    switch intOffset {
    case 0: set.fds_bits.0 |= mask
    case 1: set.fds_bits.1 |= mask
    case 2: set.fds_bits.2 |= mask
    case 3: set.fds_bits.3 |= mask
    case 4: set.fds_bits.4 |= mask
    case 5: set.fds_bits.5 |= mask
    case 6: set.fds_bits.6 |= mask
    case 7: set.fds_bits.7 |= mask
    case 8: set.fds_bits.8 |= mask
    case 9: set.fds_bits.9 |= mask
    case 10: set.fds_bits.10 |= mask
    case 11: set.fds_bits.11 |= mask
    case 12: set.fds_bits.12 |= mask
    case 13: set.fds_bits.13 |= mask
    case 14: set.fds_bits.14 |= mask
    case 15: set.fds_bits.15 |= mask
    case 16: set.fds_bits.16 |= mask
    case 17: set.fds_bits.17 |= mask
    case 18: set.fds_bits.18 |= mask
    case 19: set.fds_bits.19 |= mask
    case 20: set.fds_bits.20 |= mask
    case 21: set.fds_bits.21 |= mask
    case 22: set.fds_bits.22 |= mask
    case 23: set.fds_bits.23 |= mask
    case 24: set.fds_bits.24 |= mask
    case 25: set.fds_bits.25 |= mask
    case 26: set.fds_bits.26 |= mask
    case 27: set.fds_bits.27 |= mask
    case 28: set.fds_bits.28 |= mask
    case 29: set.fds_bits.29 |= mask
    case 30: set.fds_bits.30 |= mask
    case 31: set.fds_bits.31 |= mask
    default: break
    }
  }
}

private final class GScaleBonjourDiscoveryBridge: NSObject, NetServiceBrowserDelegate, NetServiceDelegate {
  private let channel: FlutterMethodChannel
  private var browsers: [NetServiceBrowser] = []
  private var pendingResult: FlutterResult?
  private var timeoutTimer: Timer?
  private var startedAt = Date()
  private var services: [NetService] = []
  private var resolvedServices: [[String: Any]] = []

  init(messenger: FlutterBinaryMessenger) {
    self.channel = FlutterMethodChannel(
      name: "gscale/bonjour",
      binaryMessenger: messenger
    )
    super.init()
    channel.setMethodCallHandler(handleMethodCall)
  }

  private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "discoverBonjourServices":
      discover(call: call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func discover(call: FlutterMethodCall, result: @escaping FlutterResult) {
    finishDiscovery()
    pendingResult = result
    startedAt = Date()
    services = []
    resolvedServices = []

    let args = call.arguments as? [String: Any]
    let timeoutMs = max(300, args?["timeout_ms"] as? Int ?? 900)
    for serviceType in discoveryServiceTypes(from: args) {
      let browser = NetServiceBrowser()
      browser.delegate = self
      browsers.append(browser)
      browser.searchForServices(ofType: serviceType, inDomain: "local.")
    }

    timeoutTimer = Timer.scheduledTimer(withTimeInterval: Double(timeoutMs) / 1000.0, repeats: false) { [weak self] _ in
      self?.finishDiscovery()
    }
  }

  private func finishDiscovery(error: FlutterError? = nil) {
    timeoutTimer?.invalidate()
    timeoutTimer = nil
    browsers.forEach {
      $0.stop()
      $0.delegate = nil
    }
    browsers = []
    services.forEach { $0.delegate = nil }
    services = []

    guard let result = pendingResult else {
      return
    }
    pendingResult = nil
    if let error {
      result(error)
      return
    }
    result(resolvedServices)
  }

  func netServiceBrowser(
    _ browser: NetServiceBrowser,
    didFind service: NetService,
    moreComing: Bool
  ) {
    service.delegate = self
    services.append(service)
    service.resolve(withTimeout: 1.2)
  }

  func netServiceBrowser(
    _ browser: NetServiceBrowser,
    didNotSearch errorDict: [String: NSNumber]
  ) {
    finishDiscovery(
      error: FlutterError(
        code: "bonjour_search_failed",
        message: "Bonjour search failed",
        details: errorDict
      )
    )
  }

  func netServiceDidResolveAddress(_ sender: NetService) {
    guard let item = discoveryItem(from: sender) else {
      return
    }
    resolvedServices.append(item)
  }

  private func discoveryItem(from service: NetService) -> [String: Any]? {
    guard service.port > 0 else {
      return nil
    }
    guard let host = firstIPAddress(from: service.addresses) else {
      return nil
    }

    let txt = decodeTXTRecord(service.txtRecordData())
    let httpPort = Int(txt["http_port"] ?? "") ?? service.port
    return [
      "host": host,
      "http_port": httpPort,
      "server_name": nonEmpty(txt["server_name"], fallback: service.name),
      "server_ref": nonEmpty(txt["server_ref"], fallback: ""),
      "display_name": nonEmpty(txt["display_name"], fallback: "Operator"),
      "role": nonEmpty(txt["role"], fallback: "operator"),
      "latency_ms": max(1, Int(Date().timeIntervalSince(startedAt) * 1000)),
    ]
  }

  private func firstIPAddress(from addresses: [Data]?) -> String? {
    guard let addresses else {
      return nil
    }

    for family in [AF_INET, AF_INET6] {
      for address in addresses {
        let host = address.withUnsafeBytes { buffer -> String? in
          guard let sockaddr = buffer.baseAddress?.assumingMemoryBound(to: sockaddr.self) else {
            return nil
          }
          guard Int32(sockaddr.pointee.sa_family) == family else {
            return nil
          }

          var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
          let status = getnameinfo(
            sockaddr,
            socklen_t(sockaddr.pointee.sa_len),
            &hostBuffer,
            socklen_t(hostBuffer.count),
            nil,
            0,
            NI_NUMERICHOST
          )
          guard status == 0 else {
            return nil
          }
          return String(cString: hostBuffer)
        }
        if let host, !host.isEmpty {
          return host
        }
      }
    }

    return nil
  }

  private func decodeTXTRecord(_ data: Data?) -> [String: String] {
    guard let data else {
      return [:]
    }
    let raw = NetService.dictionary(fromTXTRecord: data)
    var out: [String: String] = [:]
    for (key, value) in raw {
      out[key] = String(data: value, encoding: .utf8) ?? ""
    }
    return out
  }

  private func discoveryServiceTypes(from args: [String: Any]?) -> [String] {
    let raw = args?["service_types"] as? [Any] ?? []
    let serviceTypes = raw.compactMap { item -> String? in
      guard var value = item as? String else {
        return nil
      }
      value = value.trimmingCharacters(in: .whitespacesAndNewlines)
      if value.isEmpty {
        return nil
      }
      return value.hasSuffix(".") ? value : "\(value)."
    }
    if serviceTypes.isEmpty {
      return ["_gscale-mobileapi._tcp."]
    }
    var seen = Set<String>()
    return serviceTypes.filter { seen.insert($0).inserted }
  }

  private func nonEmpty(_ value: String?, fallback: String) -> String {
    guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return fallback
    }
    return value
  }
}
