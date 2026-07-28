import SwiftUI
import OrbitUI
import OrbitCore
import OrbitServices
import CoreLocation

struct WeatherDetailView: View {
    let temperature: Double
    let cityName: String
    let coordinate: Coordinate
    let accuracy: Int
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionStore

    @State private var humidity: String = "—"
    @State private var altitude: String = "—"
    @State private var latitude: String = "—"
    @State private var longitude: String = "—"
    @State private var gpsAccuracy: Int = 0
    @State private var showMembership = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x1A1A2E), Color(hex: 0x0D0D0D)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
            .onAppear {
                latitude  = String(format: "%.4f", coordinate.latitude)
                longitude = String(format: "%.4f", coordinate.longitude)
                gpsAccuracy = accuracy
            }
            .sheet(isPresented: $showMembership) { MembershipView().environmentObject(session) }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    // ── Close button ──
                    HStack {
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Theme.Palette.textSecondary)
                                .frame(width: 32, height: 32)
                                .background(Theme.Palette.card2, in: Circle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    // ── Big weather display ──
                    VStack(spacing: 10) {
                        Image(systemName: "cloud.fill")
                            .font(.system(size: 72))
                            .foregroundStyle(.white.opacity(0.85))

                        Text(String(format: "%.1f°C", temperature))
                            .font(.system(size: 60, weight: .thin, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .padding(.top, 8)

                    // ── Info grid ──
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                              spacing: 12) {
                        infoCard(title: "湿度", value: humidity, icon: "humidity")
                        infoCard(title: "GPS定位精度", value: gpsAccuracy > 0 ? "\(gpsAccuracy)m" : "获取中",
                                 icon: "location.circle.fill", iconColor: Theme.Palette.danger,
                                 large: true, warning: true)
                        altCard
                        VStack(spacing: 8) {
                            infoCard(title: "经度", value: longitude, icon: "arrow.left.arrow.right")
                            infoCard(title: "纬度", value: latitude, icon: "arrow.up.arrow.down")
                        }
                    }
                    .padding(.horizontal, 20)

                    // ── Tips ──
                    VStack(alignment: .leading, spacing: 10) {
                        Text("温馨提示:")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                        Text("App 获取的定位依赖于手机系统提供，主要会根据卫星信号来定位，在建筑物、地下室、地铁内等地区，GPS 信号会很弱，容易受到干扰。\n\n应用会使用基站定位、WiFi定位等方式进行辅助定位，帮助位置更准确，但仍受限于手机性能影响，可能导致位置数据不准。\n\n一般情况下，当你处于空旷环境中，GPS 信号会更好一些。")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.Palette.textSecondary)
                            .lineSpacing(4)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Theme.Palette.card, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20)

                    // ── Unlock button ──
                    Button { showMembership = true } label: {
                        Text("立即解锁")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity).frame(height: 56)
                            .background(
                                LinearGradient(colors: [Theme.Palette.sky, Theme.Palette.primary],
                                               startPoint: .leading, endPoint: .trailing),
                                in: RoundedRectangle(cornerRadius: 16)
                            )
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    private func infoCard(title: String, value: String, icon: String,
                          iconColor: Color = .white, large: Bool = false,
                          warning: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.Palette.textSecondary)
                Spacer()
                if warning {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.Palette.danger)
                }
            }
            HStack(spacing: 8) {
                Text(value)
                    .font(.system(size: large ? 36 : 20, weight: large ? .bold : .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: large ? 28 : 20))
                    .foregroundStyle(iconColor.opacity(0.6))
            }
        }
        .padding(14)
        .background(Theme.Palette.card, in: RoundedRectangle(cornerRadius: 14))
    }

    private var altCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("海拔")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.Palette.textSecondary)
                Spacer()
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
            // Simplified altitude graph
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Theme.Palette.card2)
                    .frame(height: 40)

                // Fake wave line
                GeometryReader { geo in
                    Path { p in
                        let w = geo.size.width
                        let h = geo.size.height
                        p.move(to: CGPoint(x: 0, y: h * 0.7))
                        p.addCurve(to: CGPoint(x: w * 0.5, y: h * 0.3),
                                   control1: CGPoint(x: w * 0.2, y: h * 0.8),
                                   control2: CGPoint(x: w * 0.35, y: h * 0.1))
                        p.addCurve(to: CGPoint(x: w, y: h * 0.5),
                                   control1: CGPoint(x: w * 0.65, y: h * 0.5),
                                   control2: CGPoint(x: w * 0.8, y: h * 0.7))
                    }
                    .stroke(Theme.Palette.sky.opacity(0.6), lineWidth: 2)
                }
                .frame(height: 40)

                Circle()
                    .fill(Theme.Palette.sky)
                    .frame(width: 8, height: 8)
                    .offset(x: 12, y: -28)
            }
            Text(altitude)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
        }
        .padding(14)
        .background(Theme.Palette.card, in: RoundedRectangle(cornerRadius: 14))
    }
}
