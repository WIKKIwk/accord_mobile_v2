enum PinSetupPurpose { appLock, profileSwitch }

class PinSetupConfirmArgs {
  const PinSetupConfirmArgs({
    required this.firstPin,
    required this.purpose,
  });

  final String firstPin;
  final PinSetupPurpose purpose;
}
