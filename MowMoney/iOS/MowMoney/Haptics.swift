import UIKit

final class Haptics {
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notify = UINotificationFeedbackGenerator()

    func bump() { heavy.impactOccurred() }
    func flower() { notify.notificationOccurred(.warning) }
    func combo() { medium.impactOccurred() }
    func coin() { light.impactOccurred() }
    func power() { medium.impactOccurred(intensity: 0.8) }
    func win() { notify.notificationOccurred(.success) }
    func buy() { medium.impactOccurred() }
}
