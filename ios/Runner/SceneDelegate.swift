import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
    override func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        super.scene(scene, willConnectTo: session, options: connectionOptions)
        // Flutter 引擎就绪后注册原生调度通道
        if let controller = window?.rootViewController as? FlutterViewController {
            IosAlarmScheduler.shared.registerChannels(with: controller.binaryMessenger)
        }
    }
}
