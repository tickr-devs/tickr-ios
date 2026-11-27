import Foundation
import TickrKit

/// Signing this device out on purpose (Settings): the bot revokes its tokens (DELETE /session),
/// then this device forgets them and shows the sign-in. They are forgotten even when the bot
/// cannot be reached, so the device never keeps a sign-in the owner let go of; the bot then
/// lists the device until its sign-in runs out or it is revoked there.
public enum DeviceSignOut {
  @MainActor
  public static func run() async {
    let endpoint = APIClient.Endpoint(baseURL: BotAddress.url, signedIn: true)
    try? await Container.shared.apiClient(endpoint).signOut()
    await Container.shared.botSession().forget()
    Container.shared.signInState().signedOut()
  }
}
