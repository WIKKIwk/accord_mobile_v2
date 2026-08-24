import '../../api/mobile_api.dart';
import '../../notifications/service/push_messaging_service.dart';
import '../../security/state/security_controller.dart';
import 'account_switch_controller.dart';
import 'saved_account_runtime.dart';

AccountSwitchController createRuntimeAccountSwitchController() {
  return AccountSwitchController(
    store: SavedAccountRuntime.instance.store,
    unregisterCurrentPush: PushMessagingService.instance.unregisterCurrentToken,
    syncCurrentPush: PushMessagingService.instance.syncCurrentToken,
    unlockAfterSwitch: SecurityController.instance.unlockAfterLogin,
    logoutSavedSession: (session) => MobileApi.instance.logoutSavedSession(
      token: session.token,
      baseUrl: session.account.baseUrl,
    ),
    clearAfterLogout: SecurityController.instance.clearForLogout,
  );
}
