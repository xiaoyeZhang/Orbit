import SwiftUI
import UIKit

// MARK: - UIKit window-level toast (always visible, bypasses SwiftUI hierarchy)

public enum Toast {

    public static func show(
        _ message: String,
        icon: String = "checkmark.circle.fill",
        duration: Double = 2.2
    ) {
        DispatchQueue.main.async {
            guard
                let scene  = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first
            else { return }

            // ── Build views ──────────────────────────────────────────
            let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
            blur.clipsToBounds = true
            blur.layer.cornerRadius = 22
            blur.layer.borderWidth  = 0.5
            blur.layer.borderColor  = UIColor.white.withAlphaComponent(0.15).cgColor

            let iconCfg   = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
            let iconImage = UIImage(systemName: icon, withConfiguration: iconCfg)
            let iconView  = UIImageView(image: iconImage)
            iconView.tintColor      = icon.contains("xmark") ? .systemRed : UIColor(red: 0.18, green: 0.80, blue: 0.44, alpha: 1)
            iconView.contentMode    = .scaleAspectFit
            iconView.setContentHuggingPriority(.required, for: .horizontal)

            let label           = UILabel()
            label.text          = message
            label.textColor     = .white
            label.font          = .systemFont(ofSize: 14, weight: .semibold)
            label.numberOfLines = 1

            let stack         = UIStackView(arrangedSubviews: [iconView, label])
            stack.axis        = .horizontal
            stack.spacing     = 8
            stack.alignment   = .center

            blur.contentView.addSubview(stack)
            stack.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                stack.leadingAnchor .constraint(equalTo: blur.contentView.leadingAnchor,  constant:  16),
                stack.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor, constant: -16),
                stack.topAnchor     .constraint(equalTo: blur.contentView.topAnchor,      constant:  12),
                stack.bottomAnchor  .constraint(equalTo: blur.contentView.bottomAnchor,   constant: -12),
                iconView.widthAnchor .constraint(equalToConstant: 18),
                iconView.heightAnchor.constraint(equalToConstant: 18),
            ])

            // ── Layout in window ──────────────────────────────────────
            window.addSubview(blur)
            blur.translatesAutoresizingMaskIntoConstraints = false
            let safeTop = window.safeAreaInsets.top
            NSLayoutConstraint.activate([
                blur.centerXAnchor.constraint(equalTo: window.centerXAnchor),
                blur.topAnchor    .constraint(equalTo: window.topAnchor, constant: safeTop + 8),
            ])
            window.layoutIfNeeded()

            // ── Shadow ───────────────────────────────────────────────
            blur.layer.shadowColor   = UIColor.black.cgColor
            blur.layer.shadowOpacity = 0.35
            blur.layer.shadowRadius  = 16
            blur.layer.shadowOffset  = CGSize(width: 0, height: 6)
            blur.layer.masksToBounds = false  // allow shadow

            // ── Animate in ────────────────────────────────────────────
            blur.alpha     = 0
            blur.transform = CGAffineTransform(translationX: 0, y: -24)
            UIView.animate(
                withDuration: 0.42, delay: 0,
                usingSpringWithDamping: 0.68, initialSpringVelocity: 0.5,
                options: .curveEaseOut
            ) {
                blur.alpha     = 1
                blur.transform = .identity
            }

            // ── Animate out ───────────────────────────────────────────
            UIView.animate(
                withDuration: 0.28, delay: duration,
                options: .curveEaseIn
            ) {
                blur.alpha     = 0
                blur.transform = CGAffineTransform(translationX: 0, y: -12)
            } completion: { _ in
                blur.removeFromSuperview()
            }
        }
    }
}

// MARK: - SwiftUI convenience (keeps old call-sites working)

public extension View {
    /// No-op wrapper kept for API compatibility — prefer calling Toast.show() directly.
    func autoToast(_ message: Binding<String?>, duration: Double = 2.2, icon: String = "checkmark.circle.fill") -> some View {
        self.onChange(of: message.wrappedValue) { val in
            guard let val else { return }
            Toast.show(val, icon: icon, duration: duration)
            DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.3) {
                message.wrappedValue = nil
            }
        }
    }
}
