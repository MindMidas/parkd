import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {

  /// stripe_ios presents PaymentSheet using `UIApplication.shared.delegate?.window`.
  /// With UIScene, that window is often nil unless we mirror the scene window here.
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)

    guard let windowScene = scene as? UIWindowScene else { return }
    guard let appDelegate = UIApplication.shared.delegate as? FlutterAppDelegate else { return }

    let window = windowScene.windows.first { $0.isKeyWindow } ?? windowScene.windows.first
    appDelegate.window = window
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    guard let windowScene = scene as? UIWindowScene else { return }
    guard let appDelegate = UIApplication.shared.delegate as? FlutterAppDelegate else { return }
    let window = windowScene.windows.first { $0.isKeyWindow } ?? windowScene.windows.first
    appDelegate.window = window
  }
}
