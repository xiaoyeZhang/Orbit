import SwiftUI
import CoreImage.CIFilterBuiltins
import Contacts
import OrbitCore
import OrbitUI
import OrbitServices

struct AddFriendView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    @State private var code            = ""
    @State private var toast: String?
    @State private var showQR          = false
    @State private var showScanner     = false
    @State private var contactsStatus  = CNContactStore.authorizationStatus(for: .contacts)

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    searchBar

                    if !code.isEmpty {
                        addButton
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    optionsSection

                    myCodeCard

                    syncCard

                    Color.clear.frame(height: 20)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            .background(Theme.Palette.bg.ignoresSafeArea())
            .navigationTitle("添加好友")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                        .foregroundStyle(Theme.Palette.primary)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.80), value: code.isEmpty)
            .sheet(isPresented: $showQR) { qrSheet }
            .sheet(isPresented: $showScanner) { scannerSheet }
            .autoToast($toast)
        }
    }

    // MARK: - Search bar
    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.Palette.textSecondary)
                .font(.system(size: 15))
            TextField("通过用户ID搜索", text: $code)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .foregroundStyle(.white)
                .tint(Theme.Palette.primary)
            if !code.isEmpty {
                Button { code = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(Theme.Palette.card2, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(
            code.isEmpty ? Theme.Palette.separator : Theme.Palette.primary.opacity(0.5),
            lineWidth: 0.8
        ))
    }

    // MARK: - Add button
    private var addButton: some View {
        Button {
            Task {
                let ok = await session.addFriend(code: code)
                if ok { toast = "已添加好友 🎉"; code = "" }
                else  { toast = session.errorMessage ?? "添加失败，请检查邀请码" }
            }
        } label: {
            Group {
                if session.isBusy { ProgressView().tint(.white) }
                else { Text("添加好友").fontWeight(.bold) }
            }
            .frame(maxWidth: .infinity).frame(height: 50)
            .background(Theme.Palette.primary, in: RoundedRectangle(cornerRadius: 14))
            .foregroundStyle(.white)
        }
        .disabled(code.count < 4 || session.isBusy)
        .opacity(code.count < 4 ? 0.55 : 1)
    }

    // MARK: - Options
    private var optionsSection: some View {
        VStack(spacing: 1) {
            optionRow(icon: "qrcode", iconColor: Theme.Palette.primary,
                      label: "我的二维码", sub: "让好友扫码添加你") {
                showQR = true
            }
            optionRow(icon: "person.crop.circle.badge.plus", iconColor: Theme.Palette.mint,
                      label: "通过通讯录", sub: "同步手机联系人") {
                requestContacts()
            }
            optionRow(icon: "qrcode.viewfinder", iconColor: Theme.Palette.sky,
                      label: "扫一扫", sub: "扫好友二维码", last: true) {
                showScanner = true
            }
        }
        .background(Theme.Palette.card, in: RoundedRectangle(cornerRadius: 16))
    }

    private func optionRow(icon: String, iconColor: Color, label: String,
                           sub: String, last: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 44, height: 44)
                    .background(iconColor.opacity(0.15), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(sub)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.Palette.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
            .padding(.horizontal, 16).padding(.vertical, 13)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                if !last {
                    Rectangle()
                        .fill(Theme.Palette.separator)
                        .frame(height: 0.5)
                        .padding(.leading, 74)
                }
            }
        }
        .buttonStyle(.pressable(scale: 0.94))
    }

    // MARK: - My invite code
    private var myCodeCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("我的邀请码")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textSecondary)
                Spacer()
            }

            Text(session.currentUser?.inviteCode ?? "—")
                .font(.system(size: 28, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                UIPasteboard.general.string = session.currentUser?.inviteCode
                toast = "已复制邀请码"
            } label: {
                Label("复制", systemImage: "doc.on.doc")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.Palette.primary)
                    .frame(maxWidth: .infinity).frame(height: 44)
                    .background(Theme.Palette.primary.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.Palette.primary.opacity(0.4), lineWidth: 0.8))
            }
            .buttonStyle(.pressable(scale: 0.94))
        }
        .padding(16)
        .background(Theme.Palette.card, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Sync contacts
    private var syncCard: some View {
        VStack(spacing: 10) {
            Text("同步你的联系人")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
            Text("给应用开启通讯录权限，我们可以帮助你找到已在应用上的朋友")
                .font(.system(size: 13))
                .foregroundStyle(Theme.Palette.textSecondary)
                .multilineTextAlignment(.center)

            Button { requestContacts() } label: {
                Text(contactsStatus == .authorized ? "已开启 ✓" : "去同步")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 48)
                    .background(
                        contactsStatus == .authorized ? Theme.Palette.mint : Theme.Palette.primary,
                        in: RoundedRectangle(cornerRadius: 14)
                    )
            }
            .buttonStyle(.pressable(scale: 0.94))
            .disabled(contactsStatus == .authorized)
        }
        .padding(16)
        .background(Theme.Palette.card, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - QR code sheet
    @ViewBuilder
    private var qrSheet: some View {
        NavigationStack {
            VStack(spacing: 28) {
                if let img = generateQR(from: session.currentUser?.inviteCode ?? "ORBIT") {
                    Image(uiImage: img)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 220, height: 220)
                        .padding(20)
                        .background(.white, in: RoundedRectangle(cornerRadius: 20))
                        .shadow(color: .black.opacity(0.15), radius: 20, y: 8)
                }

                VStack(spacing: 6) {
                    Text(session.currentUser?.displayName ?? "")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Text(session.currentUser?.inviteCode ?? "")
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Theme.Palette.textSecondary)
                }

                Text("让好友扫描二维码添加你")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Palette.textSecondary)

                Spacer()
            }
            .padding(.top, 40)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.Palette.bg.ignoresSafeArea())
            .navigationTitle("我的二维码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { showQR = false }
                        .foregroundStyle(Theme.Palette.primary)
                }
            }
        }
    }

    // MARK: - Scanner sheet
    @ViewBuilder
    private var scannerSheet: some View {
        NavigationStack {
            QRScannerView { result in
                showScanner = false
                code = result
                toast = "已扫描，点击添加好友"
            }
            .ignoresSafeArea()
            .navigationTitle("扫一扫")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { showScanner = false }
                        .foregroundStyle(.white)
                }
            }
        }
    }

    // MARK: - Helpers
    private func generateQR(from string: String) -> UIImage? {
        let context = CIContext()
        let filter  = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    private func requestContacts() {
        switch contactsStatus {
        case .authorized:
            toast = "通讯录已开启"
        case .notDetermined:
            CNContactStore().requestAccess(for: .contacts) { granted, _ in
                DispatchQueue.main.async {
                    contactsStatus = CNContactStore.authorizationStatus(for: .contacts)
                    toast = granted ? "通讯录已开启 ✓" : "未获得通讯录权限"
                }
            }
        default:
            // 已拒绝 → 引导去系统设置
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        }
    }
}

// MARK: - QR Scanner (AVFoundation)
import AVFoundation

struct QRScannerView: UIViewControllerRepresentable {
    var onResult: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onResult: onResult) }

    func makeUIViewController(context: Context) -> ScannerVC {
        let vc = ScannerVC()
        #if !targetEnvironment(simulator)
        vc.delegate = context.coordinator
        #endif
        return vc
    }
    func updateUIViewController(_ vc: ScannerVC, context: Context) {}

    class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        let onResult: (String) -> Void
        init(onResult: @escaping (String) -> Void) { self.onResult = onResult }

        func metadataOutput(_ output: AVCaptureMetadataOutput,
                            didOutput objects: [AVMetadataObject],
                            from connection: AVCaptureConnection) {
            guard let obj = objects.first as? AVMetadataMachineReadableCodeObject,
                  let str = obj.stringValue else { return }
            DispatchQueue.main.async { self.onResult(str) }
        }
    }
}

class ScannerVC: UIViewController {
    var delegate: AVCaptureMetadataOutputObjectsDelegate?
    private var session: AVCaptureSession?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        #if targetEnvironment(simulator)
        showUnavailable()
        #else
        checkPermissionAndSetup()
        #endif
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        DispatchQueue.global(qos: .userInitiated).async { self.session?.startRunning() }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        session?.stopRunning()
    }

    private func checkPermissionAndSetup() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted { self.setupCamera() } else { self.showUnavailable() }
                }
            }
        default:
            showUnavailable()
        }
    }

    private func setupCamera() {
        let session = AVCaptureSession()
        guard let device = AVCaptureDevice.default(for: .video),
              let input  = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            showUnavailable(); return
        }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { showUnavailable(); return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(delegate, queue: .main)
        output.metadataObjectTypes = [.qr]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.frame = view.bounds
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)

        // Viewfinder overlay
        let overlay = UIView(frame: view.bounds)
        overlay.backgroundColor = .clear
        let cutW: CGFloat = 240
        let cutX = (view.bounds.width - cutW) / 2
        let cutY = (view.bounds.height - cutW) / 2
        let path = UIBezierPath(rect: view.bounds)
        path.append(UIBezierPath(roundedRect: CGRect(x: cutX, y: cutY, width: cutW, height: cutW), cornerRadius: 16).reversing())
        let mask = CAShapeLayer()
        mask.path = path.cgPath
        mask.fillColor = UIColor.black.withAlphaComponent(0.55).cgColor
        overlay.layer.addSublayer(mask)
        // Corner brackets
        for corner in cornerBrackets(in: CGRect(x: cutX, y: cutY, width: cutW, height: cutW)) {
            overlay.layer.addSublayer(corner)
        }
        view.addSubview(overlay)

        self.session = session
        DispatchQueue.global(qos: .userInitiated).async { session.startRunning() }
    }

    private func showUnavailable() {
        DispatchQueue.main.async {
            let label = UILabel()
            label.text = "相机不可用\n(模拟器不支持)"
            label.textColor = .white
            label.textAlignment = .center
            label.numberOfLines = 0
            label.frame = self.view.bounds
            self.view.addSubview(label)
        }
    }

    private func cornerBrackets(in rect: CGRect) -> [CAShapeLayer] {
        let len: CGFloat = 24; let lw: CGFloat = 3
        let corners: [(CGPoint, CGPoint, CGPoint)] = [
            (.init(x: rect.minX, y: rect.minY + len), .init(x: rect.minX, y: rect.minY), .init(x: rect.minX + len, y: rect.minY)),
            (.init(x: rect.maxX - len, y: rect.minY), .init(x: rect.maxX, y: rect.minY), .init(x: rect.maxX, y: rect.minY + len)),
            (.init(x: rect.maxX, y: rect.maxY - len), .init(x: rect.maxX, y: rect.maxY), .init(x: rect.maxX - len, y: rect.maxY)),
            (.init(x: rect.minX + len, y: rect.maxY), .init(x: rect.minX, y: rect.maxY), .init(x: rect.minX, y: rect.maxY - len)),
        ]
        return corners.map { (a, b, c) in
            let path = UIBezierPath()
            path.move(to: a); path.addLine(to: b); path.addLine(to: c)
            let layer = CAShapeLayer()
            layer.path = path.cgPath
            layer.strokeColor = UIColor.white.cgColor
            layer.lineWidth = lw
            layer.fillColor = UIColor.clear.cgColor
            layer.lineCap = .round
            return layer
        }
    }
}
