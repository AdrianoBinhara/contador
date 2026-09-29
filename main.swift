import SwiftUI
import AppKit

import ServiceManagement
import ApplicationServices

// Idioma: português se o Mac estiver em português, senão inglês.
let pt = Locale.preferredLanguages.first?.hasPrefix("pt") ?? false
func tr(_ p: String, _ e: String) -> String { pt ? p : e }

// Preferências (UserDefaults). Datas em segundos desde 1970.
let prefs = UserDefaults.standard
let week: Double = 7 * 86400

let themes: [(name: String, colors: [Color])] = [
    ("Aurora", [Color(red: 0.49, green: 0.95, blue: 0.84), Color(red: 0.43, green: 0.66, blue: 1.0), Color(red: 0.66, green: 0.56, blue: 1.0)]),
    (tr("Brasa", "Ember"), [Color(red: 1.0, green: 0.78, blue: 0.35), Color(red: 1.0, green: 0.45, blue: 0.4), Color(red: 0.93, green: 0.3, blue: 0.62)]),
    (tr("Oceano", "Ocean"), [Color(red: 0.4, green: 0.9, blue: 1.0), Color(red: 0.25, green: 0.55, blue: 1.0), Color(red: 0.35, green: 0.3, blue: 0.95)]),
    (tr("Lima", "Lime"), [Color(red: 0.85, green: 1.0, blue: 0.4), Color(red: 0.45, green: 0.92, blue: 0.5), Color(red: 0.2, green: 0.78, blue: 0.7)]),
    (tr("Grafite", "Graphite"), [Color(white: 0.95), Color(white: 0.75), Color(white: 0.55)]),
]
func gradient(_ i: Int) -> LinearGradient {
    LinearGradient(colors: themes[min(max(i, 0), themes.count - 1)].colors, startPoint: .leading, endPoint: .trailing)
}

// Poses da gota: fechada (quase só o menisco) e aberta (língua nas laterais, gota achatada no topo/base).
let closedR: CGFloat = 15, closedD: CGFloat = 8, closedF: CGFloat = 11
struct Pose { let r, d, f, len: CGFloat }
let sideOpen = Pose(r: 47, d: 262, f: 18, len: 0)
let flatOpen = Pose(r: 44, d: 56, f: 18, len: 220)

// Tudo é calculado num espaço canônico com a parede à direita (P fundo × A ao longo da parede)
// e transformado pra borda real. Assim a mesma física serve pras 4 bordas.
let P: CGFloat = 360, A: CGFloat = 380

// Notch do monitor principal (em coordenadas de tela), se houver.
var notchRect: CGRect? {
    guard let s = NSScreen.screens.first, let l = s.auxiliaryTopLeftArea, let r = s.auxiliaryTopRightArea else { return nil }
    let h = s.safeAreaInsets.top
    return CGRect(x: l.maxX, y: s.frame.maxY - h, width: r.minX - l.maxX, height: h)
}

// Dock visível no monitor principal (coordenadas de tela, y pra cima) e em que borda ele está.
// Com permissão de Acessibilidade pega o retângulo exato; sem ela, a faixa que o macOS reserva.
func dockFrame() -> (rect: CGRect, side: Edge)? {
    guard let s = NSScreen.screens.first else { return nil }
    let f = s.frame, v = s.visibleFrame
    var result: (rect: CGRect, side: Edge)
    if v.minY > f.minY { result = (CGRect(x: f.minX, y: f.minY, width: f.width, height: v.minY - f.minY), .bottom) }
    else if v.minX > f.minX { result = (CGRect(x: f.minX, y: v.minY, width: v.minX - f.minX, height: v.height), .left) }
    else if v.maxX < f.maxX { result = (CGRect(x: v.maxX, y: v.minY, width: f.maxX - v.maxX, height: v.height), .right) }
    else { return nil } // Dock escondido: as bordas são as da tela
    guard AXIsProcessTrusted(), let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else {
        // sem Acessibilidade: estima o comprimento pelos ícones (célula ≈ 1,09 × tilesize, calibrado num Dock real)
        // ponytail: não conta janelas minimizadas; erra alguns ícones pra menos
        let prefs = UserDefaults(suiteName: "com.apple.dock")
        let tile = CGFloat(prefs?.double(forKey: "tilesize") ?? 0).nonZero ?? 48
        let pinned = (prefs?.array(forKey: "persistent-apps") ?? []).compactMap { (($0 as? [String: Any])?["tile-data"] as? [String: Any])?["bundle-identifier"] as? String }
        let running = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular && !pinned.contains($0.bundleIdentifier ?? "") }.count
        let cells = 2 + pinned.count + running + (prefs?.array(forKey: "persistent-others") ?? []).count // + Finder e Lixeira
        let length = CGFloat(cells) * tile * 1.09 + 40
        switch result.side {
        case .bottom: result.rect = CGRect(x: f.midX - length / 2, y: f.minY, width: length, height: result.rect.height)
        default: result.rect = CGRect(x: result.rect.minX, y: f.midY - length / 2, width: result.rect.width, height: length)
        }
        return result
    }
    var children: CFTypeRef?, pos: CFTypeRef?, size: CFTypeRef?
    let app = AXUIElementCreateApplication(dock.processIdentifier)
    guard AXUIElementCopyAttributeValue(app, kAXChildrenAttribute as CFString, &children) == .success,
          let list = (children as? [AXUIElement])?.first,
          AXUIElementCopyAttributeValue(list, kAXPositionAttribute as CFString, &pos) == .success,
          AXUIElementCopyAttributeValue(list, kAXSizeAttribute as CFString, &size) == .success else { return result }
    var pt = CGPoint.zero, sz = CGSize.zero
    AXValueGetValue(pos as! AXValue, .cgPoint, &pt)
    AXValueGetValue(size as! AXValue, .cgSize, &sz)
    let r = CGRect(x: pt.x, y: f.maxY - pt.y - sz.height, width: sz.width, height: sz.height) // AX usa origem no topo
    // encosta o retângulo na borda da tela (a barra do Dock flutua um pouco acima)
    result.rect = switch result.side {
    case .bottom: CGRect(x: r.minX, y: f.minY, width: r.width, height: r.maxY - f.minY)
    case .left: CGRect(x: f.minX, y: r.minY, width: r.maxX - f.minX, height: r.height)
    default: CGRect(x: r.minX, y: r.minY, width: f.maxX - r.minX, height: r.height)
    }
    return result
}

extension CGFloat { var nonZero: CGFloat? { self == 0 ? nil : self } }

// Parede de cada borda num ponto ao longo dela: em cima do Dock onde ele está, na borda da tela fora dele.
func wall(_ edge: Edge, at along: CGFloat) -> CGFloat {
    guard let s = NSScreen.screens.first else { return 0 }
    let f = s.frame, dock = dockFrame()
    func onDock(_ side: Edge, _ span: ClosedRange<CGFloat>) -> Bool { dock?.side == side && span.contains(along) }
    switch edge {
    case .bottom: return dock.map { onDock(.bottom, $0.rect.minX...$0.rect.maxX) ? $0.rect.maxY : f.minY } ?? f.minY
    case .left: return dock.map { onDock(.left, $0.rect.minY...$0.rect.maxY) ? $0.rect.maxX : f.minX } ?? f.minX
    case .right: return dock.map { onDock(.right, $0.rect.minY...$0.rect.maxY) ? $0.rect.minX : f.maxX } ?? f.maxX
    case .top, .notch: return s.visibleFrame.maxY
    }
}

enum Edge: Int {
    case right, left, top, bottom, notch
    var isSide: Bool { self == .right || self == .left }
    var closed: Pose {
        guard self == .notch, let n = notchRect else { return Pose(r: closedR, d: closedD, f: closedF, len: 0) }
        // envolve o notch: mesma forma, 4 px maior de cada lado, cantos de baixo arredondados
        return Pose(r: 10, d: n.height + 5 - 10, f: 6, len: n.width + 8 - 20)
    }
    var open: Pose {
        if self == .notch, let n = notchRect { return Pose(r: 24, d: n.height + 88 - 24, f: 10, len: max(n.width, 330) - 48) }
        return isSide ? sideOpen : flatOpen
    }
    var size: CGSize { isSide ? CGSize(width: P, height: A) : CGSize(width: A, height: P) }
    // canônico → janela (y pra baixo)
    var transform: CGAffineTransform {
        switch self {
        case .right: .identity
        case .left: CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: P, ty: 0)
        case .top, .notch: CGAffineTransform(a: 0, b: -1, c: 1, d: 0, tx: 0, ty: P)
        case .bottom: CGAffineTransform(a: 0, b: 1, c: 1, d: 0, tx: 0, ty: 0)
        }
    }
}

// Gota presa na parede: calota de raio r com centro a d px da parede (esticada em len ao longo dela),
// fundida à parede por um menisco de raio f.
struct Drop: Shape {
    var cy: CGFloat, r: CGFloat, d: CGFloat, f: CGFloat, len: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let w = rect.maxX, r = max(r, 1), d = max(d, 0), f = max(f, 1), h = max(len, 0) / 2
        // menisco encosta na calota (d < f) ou na lateral reta do corpo (d >= f)
        let dy = d < f ? sqrt((r + f) * (r + f) - (f - d) * (f - d)) : r + f
        let t = d < f ? atan2(dy, f - d) : .pi / 2
        var p = Path()
        p.move(to: CGPoint(x: w, y: cy - h - dy))
        arc(&p, CGPoint(x: w - f, y: cy - h - dy), f, 0, t)
        arc(&p, CGPoint(x: w - d, y: cy - h), r, .pi + t, .pi)
        arc(&p, CGPoint(x: w - d, y: cy + h), r, .pi, .pi - t)
        arc(&p, CGPoint(x: w - f, y: cy + h + dy), f, -t, 0)
        p.closeSubpath()
        return p
    }

    // ponytail: arco como polilinha densa, evita a ambiguidade de sentido do addArc com y pra baixo
    private func arc(_ p: inout Path, _ c: CGPoint, _ r: CGFloat, _ a0: CGFloat, _ a1: CGFloat) {
        for i in 0...24 {
            let a = a0 + (a1 - a0) * CGFloat(i) / 24
            p.addLine(to: CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a)))
        }
    }
}

// A gota canônica levada pra borda real.
struct EdgeDrop: Shape {
    let drop: Drop, edge: Edge
    func path(in rect: CGRect) -> Path { drop.path(in: CGRect(x: 0, y: 0, width: P, height: A)).applying(edge.transform) }
}

struct Tick {
    let left: Int, before: Int, elapsed: Double, progress: Double
    let unit: String, units: Int, unitSize: Double, start: Double
    init(_ now: Date, start: Double, end: Double) {
        let total = max(end - start, 60), t = now.timeIntervalSince1970
        self.start = start
        before = max(0, Int(start - t)) // > 0: ainda não começou
        elapsed = min(max(t - start, 0), total)
        left = Int(total - elapsed)
        progress = elapsed / total
        // segmentos: dias até 2 semanas, semanas até ~6 meses, depois meses
        (unit, unitSize) = total <= 14 * 86400 ? (tr("dia", "day"), 86400) : total <= 26 * week ? (tr("semana", "week"), week) : (tr("mês", "month"), 30.44 * 86400)
        units = min(36, max(1, Int(ceil(total / unitSize - 0.001))))
    }
}

struct Segments: View {
    let t: Tick, theme: Int
    var body: some View {
        let gap: CGFloat = t.units > 20 ? 2 : 3
        let track = HStack(spacing: gap) { ForEach(0..<t.units, id: \.self) { _ in Capsule() } }
        gradient(theme)
            .mask(HStack(spacing: gap) {
                ForEach(0..<t.units, id: \.self) { i in
                    let f = t.left == 0 ? 1 : min(max(t.elapsed / t.unitSize - Double(i), 0), 1) // concluído: tudo cheio
                    Capsule().scaleEffect(x: f > 0 ? max(f, 0.3) : 0, anchor: .leading)
                }
            })
            .shadow(color: themes[theme].colors[1].opacity(0.7), radius: 3)
            .background(track.foregroundStyle(.white.opacity(0.12)))
            .frame(height: 4)
    }
}

struct Details: View {
    let t: Tick, title: String, theme: Int
    var body: some View {
        let shown = t.before > 0 ? t.before : t.left // antes de começar, conta até o início
        let days = shown / 86400
        let current = t.left == 0 ? t.units : min(t.units, Int(t.elapsed / t.unitSize) + 1)
        let prefix = title.isEmpty ? "" : title + " · "
        let footer = t.before > 0
            ? tr("começa ", "starts ") + Date(timeIntervalSince1970: t.start).formatted(.dateTime.day().month().hour().minute())
            : "\(t.unit) \(current) " + tr("de", "of") + " \(t.units)"
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                if t.left == 0 {
                    Text(tr("Concluído", "Done")).font(.system(size: 30, weight: .semibold, design: .rounded))
                    Image(systemName: "checkmark.seal.fill").font(.system(size: 18)).foregroundStyle(gradient(theme))
                    Spacer()
                } else {
                    Text("\(days)").font(.system(size: 32, weight: .semibold, design: .rounded))
                    Text(t.before > 0 ? tr("dias até começar", "days to start") : days == 1 ? tr("dia", "day") : tr("dias", "days"))
                        .font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%02d:%02d:%02d", shown % 86400 / 3600, shown % 3600 / 60, shown % 60))
                        .font(.system(size: 15, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
                }
            }
            .monospacedDigit()
            .contentTransition(.numericText(countsDown: true))
            .animation(.snappy, value: shown)
            Segments(t: t, theme: theme)
            HStack {
                Text(prefix + footer).lineLimit(1)
                Spacer()
                Text(t.progress, format: .percent.precision(.fractionLength(t.left == 0 ? 0 : 1))).foregroundStyle(gradient(theme))
            }
            .font(.system(size: 10.5, weight: .medium, design: .rounded))
            .foregroundStyle(.secondary)
        }
    }
}

// Ótica de gota: brilho especular em cima à esquerda, cáustica colorida embaixo.
struct Shine: View {
    let drop: Drop, w: CGFloat, theme: Int, e: CGFloat, top: Bool
    var body: some View {
        let r = drop.r, reach = drop.d + drop.r, h = drop.len / 2
        let cap = CGPoint(x: w - drop.d, y: drop.cy - h)
        ZStack {
            // volume: borda escurece e arco de reflexo, igual à esfera da intro (some quando vira card)
            Circle()
                .fill(RadialGradient(stops: [.init(color: .clear, location: 0.3), .init(color: .black.opacity(0.45), location: 1)], center: UnitPoint(x: 0.45, y: 0.4), startRadius: 0, endRadius: r * 1.1))
                .frame(width: r * 2.4, height: r * 2.4)
                .position(cap)
                .opacity(Double(1 - e * 3))
            Circle().trim(from: 0.6, to: 0.8)
                .stroke(.white.opacity(0.35), style: StrokeStyle(lineWidth: max(r * 0.07, 1), lineCap: .round))
                .frame(width: r * 1.6, height: r * 1.6)
                .blur(radius: 0.8)
                .position(cap)
                .opacity(Double(1 - e * 3))
            Ellipse().fill(gradient(theme))
                .frame(width: reach * 0.9, height: r * 0.6 + drop.len * 0.8)
                .blur(radius: r * 0.35)
                .opacity(0.55)
                .blendMode(.plusLighter)
                .position(x: w - reach / 2, y: drop.cy + (drop.len > 1 ? 0 : r * 0.72))
            Ellipse().fill(.white.opacity(0.9))
                .frame(width: min(r * 0.6, 12), height: min(r * 0.26, 4.5))
                .blur(radius: 1)
                .rotationEffect(.degrees(-38))
                .position(x: w - drop.d + r * (top ? 0.35 : -0.62), y: drop.cy - h - r * (top ? 0.85 : 0.5)) // no topo a luz vem do lado da parede
        }
    }
}

struct Glass<S: Shape>: ViewModifier {
    let shape: S
    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content.glassEffect(.regular.tint(.black.opacity(0.42)), in: shape)
        } else {
            content.background(.ultraThinMaterial, in: shape)
        }
    }
}

final class Liquid: ObservableObject {
    @Published var drop = Drop(cy: A / 2, r: closedR, d: closedD, f: closedF)
    @Published var edge = Edge.right
    @Published var open = false
    @Published var ripple: Date? // instante da adesão: luz corre pela borda
    var rippleStrength: CGFloat = 0.4 // 0 = toque leve, 1 = impacto forte
}

// Onda de luz subindo e descendo pela borda a partir do ponto de contato.
struct Ripple: View {
    let start: Date, cy: CGFloat, w: CGFloat, theme: Int, strength: CGFloat
    var body: some View {
        TimelineView(.animation) { ctx in
            RippleFrame(t: ctx.date.timeIntervalSince(start), cy: cy, w: w, theme: theme, k: min(max(strength, 0), 1))
        }
    }
}

struct RippleFrame: View {
    let t: Double, cy: CGFloat, w: CGFloat, theme: Int, k: CGFloat
    var body: some View {
        let u = CGFloat(min(t / (0.5 + 0.5 * Double(k)), 1)) // impacto forte dura mais
        let ease = 1 - (1 - u) * (1 - u)
        let length: CGFloat = (18 + 44 * k) * (1 - u) + 6
        let reach: CGFloat = 18 + (60 + 230 * k) * ease // vai mais longe
        let alpha = Double((0.55 + 0.45 * k) * (1 - u))
        ZStack {
            ForEach([-1.0, 1.0], id: \.self) { (dir: CGFloat) in
                Capsule().fill(gradient(theme))
                    .frame(width: 1.5 + 2.5 * k, height: length)
                    .blur(radius: 1.5)
                    .shadow(color: themes[theme].colors[1], radius: 4 + 8 * k)
                    .position(x: w - 1, y: cy + dir * reach)
                    .opacity(alpha)
            }
        }
        .blendMode(.plusLighter)
    }
}

struct Widget: View {
    @ObservedObject var liquid: Liquid
    @AppStorage("start") var start = 0.0
    @AppStorage("end") var end = 0.0
    @AppStorage("title") var title = ""
    @AppStorage("theme") var theme = 0

    var body: some View {
        let drop = liquid.drop, edge = liquid.edge, t = edge.transform
        let e = min(max((drop.d - edge.closed.d) / (edge.open.d - edge.closed.d), 0), 1) // 0 = gota, 1 = aberta
        let shape = EdgeDrop(drop: drop, edge: edge)
        let depth: CGFloat = edge == .notch ? (notchRect?.height ?? 0) / 2 + 48 : edge.isSide ? 150 : 52 // centro do texto a partir da parede
        let center = CGPoint(x: P - depth, y: drop.cy).applying(t)
        let slide = CGPoint(x: 40 * (1 - e), y: 0).applying(CGAffineTransform(a: t.a, b: t.b, c: t.c, d: t.d, tx: 0, ty: 0))
        ZStack(alignment: .topLeading) {
            if edge == .notch {
                shape.fill(.black) // funde com o notch, como a Dynamic Island
                Ellipse().fill(gradient(theme)) // brilho da cor do tema por baixo do líquido
                    .frame(width: drop.len * 0.8 + 20, height: 18)
                    .blur(radius: 12)
                    .opacity(0.25 + 0.3 * e)
                    .position(CGPoint(x: P - drop.d - drop.r * 0.6, y: drop.cy).applying(t))
                    .blendMode(.plusLighter)
            } else {
                Color.clear.modifier(Glass(shape: shape))
                Shine(drop: drop, w: P, theme: theme, e: e, top: edge == .top)
                    .frame(width: P, height: A)
                    .projectionEffect(ProjectionTransform(t))
            }
            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                Details(t: Tick(ctx.date, start: start, end: end), title: title, theme: theme)
                    .frame(width: 252)
                    .position(center)
                    .opacity(Double((e - 0.5) * 2))
                    .blur(radius: (1 - e) * 8)
                    .offset(x: slide.x, y: slide.y)
            }
        }
        .frame(width: edge.size.width, height: edge.size.height, alignment: .topLeading)
        .mask(shape)
        .overlay(alignment: .topLeading) {
            if let t0 = liquid.ripple {
                Ripple(start: t0, cy: drop.cy, w: P, theme: theme, strength: liquid.rippleStrength)
                    .frame(width: P, height: A)
                    .projectionEffect(ProjectionTransform(t))
            }
        }
        .environment(\.colorScheme, .dark)
    }
}

// Bolha solta: segue o cursor, voa quando solta e gruda na borda mais próxima.
final class Ball: ObservableObject {
    @Published var pos = CGPoint.zero
    @Published var vel = CGVector.zero
    @Published var scale: CGFloat = 1
}

struct BallView: View {
    @ObservedObject var ball: Ball
    @AppStorage("theme") var theme = 0
    var body: some View {
        let speed = hypot(ball.vel.dx, ball.vel.dy)
        DropBall(size: 32, tail: min(speed / 900, 1.6), angle: .radians(atan2(ball.vel.dy, ball.vel.dx)), theme: theme)
            .scaleEffect(ball.scale)
            .position(ball.pos)
            .environment(\.colorScheme, .dark)
    }
}

func askAccessibility() { NotificationCenter.default.post(name: .askAccessibility, object: nil) }

extension Notification.Name {
    static let openSettings = Notification.Name("openSettings")
    static let update = Notification.Name("update")
    static let askAccessibility = Notification.Name("askAccessibility")
}

let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
func isNewer(_ v: String) -> Bool { !v.isEmpty && v.compare(version, options: .numeric) == .orderedDescending }

struct SettingsView: View {
    @AppStorage("title") var title = ""
    @AppStorage("start") var start = 0.0
    @AppStorage("end") var end = 0.0
    @AppStorage("theme") var theme = 0
    @AppStorage("edge") var edge = 0
    @AppStorage("height") var height = 0.5
    @AppStorage("locked") var locked = false
    @State var login = SMAppService.mainApp.status == .enabled
    @State var confirmReset = false
    @AppStorage("update") var update = ""
    @State var axTrusted = AXIsProcessTrusted()

    func date(_ v: Binding<Double>) -> Binding<Date> {
        Binding(get: { Date(timeIntervalSince1970: v.wrappedValue) }, set: { v.wrappedValue = $0.timeIntervalSince1970 })
    }

    var body: some View {
        Form {
            if isNewer(update) {
                Section {
                    HStack {
                        Label(tr("Versão \(update) disponível", "Version \(update) available"), systemImage: "arrow.down.circle.fill")
                        Spacer()
                        Button(tr("Atualizar", "Update")) { NotificationCenter.default.post(name: .update, object: nil) }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
            Section(tr("Contagem", "Countdown")) {
                TextField(tr("Nome", "Name"), text: $title, prompt: Text(tr("Ex.: Lançamento", "e.g. Launch")))
                DatePicker(tr("Início", "Start"), selection: date($start), displayedComponents: [.date, .hourAndMinute])
                    .disabled(locked)
                DatePicker(tr("Fim", "End"), selection: date($end), in: Date(timeIntervalSince1970: start + 60)..., displayedComponents: [.date, .hourAndMinute])
                    .disabled(locked)
                HStack {
                    Button(tr("Reiniciar contagem…", "Restart countdown…")) { confirmReset = true }.disabled(locked)
                    Spacer()
                    if locked {
                        Button(tr("Destravar", "Unlock"), systemImage: "lock.open") { locked = false }
                    } else {
                        Button(tr("Travar", "Lock"), systemImage: "lock") { locked = true }
                    }
                }
                if locked {
                    Text(tr("Travada: datas e reinício bloqueados contra clique acidental.", "Locked: dates and restart are protected from accidental clicks."))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Section(tr("Aparência", "Appearance")) {
                LabeledContent(tr("Cor", "Color")) {
                    HStack(spacing: 10) {
                        ForEach(themes.indices, id: \.self) { i in
                            Circle().fill(gradient(i)).frame(width: 20, height: 20)
                                .padding(3)
                                .overlay(Circle().strokeBorder(.primary.opacity(theme == i ? 0.8 : 0), lineWidth: 2))
                                .contentShape(Circle())
                                .onTapGesture { theme = i }
                                .help(themes[i].name)
                                .accessibilityLabel(themes[i].name)
                                .accessibilityAddTraits(theme == i ? [.isButton, .isSelected] : .isButton)
                        }
                    }
                }
                Picker(tr("Borda", "Edge"), selection: $edge) {
                    Text(tr("Direita", "Right")).tag(0)
                    Text(tr("Esquerda", "Left")).tag(1)
                    Text(tr("Topo", "Top")).tag(2)
                    Text(tr("Base", "Bottom")).tag(3)
                    if notchRect != nil { Text("Notch").tag(4) }
                }
                .pickerStyle(.segmented)
                LabeledContent(tr("Posição na borda", "Position on edge")) {
                    Slider(value: $height, in: 0.05...0.95) { EmptyView() }
                        minimumValueLabel: { Image(systemName: edge < 2 ? "arrow.up" : "arrow.left") }
                        maximumValueLabel: { Image(systemName: edge < 2 ? "arrow.down" : "arrow.right") }
                }
                Text(tr("Dica: com a gota aberta, arraste pra arrancar e jogue em qualquer borda.", "Tip: with the drop open, drag to pull it off and throw it at any edge."))
                    .font(.caption).foregroundStyle(.secondary)
                if !axTrusted {
                    LabeledContent(tr("Pousar certinho no Dock", "Land exactly on the Dock")) {
                        Button(tr("Permitir Acessibilidade", "Allow Accessibility")) { askAccessibility() }
                    }
                }
            }
            Section {
                HStack {
                    Text(tr("Contador \(version)", "Contador \(version)")).foregroundStyle(.secondary)
                    Spacer()
                    // sair sem depender do ícone da barra (ele some atrás do notch quando a barra lota)
                    Button(tr("Sair do Contador", "Quit Contador")) { NSApp.terminate(nil) }
                        .keyboardShortcut("q")
                }
            }
            Section {
                Toggle(tr("Abrir ao iniciar o Mac", "Open at login"), isOn: $login)
                    .onChange(of: login) { _, on in
                        try? on ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
                        login = SMAppService.mainApp.status == .enabled
                    }
            }
        }
        .formStyle(.grouped)
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in axTrusted = AXIsProcessTrusted() }
        .scrollDisabled(true)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
        .confirmationDialog(tr("Reiniciar a contagem?", "Restart the countdown?"), isPresented: $confirmReset) {
            Button(tr("Reiniciar", "Restart"), role: .destructive) {
                let now = Date().timeIntervalSince1970
                (start, end) = (now, now + (end - start)) // mesma duração, começando agora
            }
        } message: {
            Text(tr("Começa de novo a partir de agora, com a mesma duração.", "Starts over from now, with the same duration."))
        }
    }
}

// Lágrima: cabeça redonda de raio h/2 no centro, cauda afinando pra -x (tail = comprimento em raios).
struct Tear: Shape {
    var tail: CGFloat
    func path(in rect: CGRect) -> Path {
        let r = rect.height / 2, c = CGPoint(x: rect.midX, y: rect.midY)
        let l = r * (1 + max(tail, 0.001)), a = acos(r / l)
        let tip = CGPoint(x: c.x - l, y: c.y)
        let top = CGPoint(x: c.x - r * cos(a), y: c.y - r * sin(a))
        let bottom = CGPoint(x: top.x, y: c.y + r * sin(a))
        let k = (top.x - tip.x) * 0.45 // cauda côncava: afina suave, tangente à cabeça
        var p = Path()
        p.move(to: tip)
        p.addCurve(to: top, control1: CGPoint(x: tip.x + k * 0.8, y: c.y), control2: CGPoint(x: top.x - k * sin(a), y: top.y + k * cos(a)))
        for i in 1...48 { // arco da frente
            let ang = .pi + a + (2 * .pi - 2 * a) * CGFloat(i) / 48
            p.addLine(to: CGPoint(x: c.x + r * cos(ang), y: c.y + r * sin(ang)))
        }
        p.addCurve(to: tip, control1: CGPoint(x: bottom.x - k * sin(a), y: bottom.y - k * cos(a)), control2: CGPoint(x: tip.x + k * 0.8, y: c.y))
        p.closeSubpath()
        return p
    }
}

// Gota com volume: vidro, borda escura, cáustica, reflexo, especular e sombra projetada.
struct DropBall: View {
    let size: CGFloat, tail: CGFloat, angle: Angle, theme: Int
    var body: some View {
        let shape = Tear(tail: tail).rotation(angle)
        ZStack {
            Ellipse().fill(.black.opacity(0.4))
                .frame(width: size * 0.85, height: size * 0.26)
                .blur(radius: size * 0.12)
                .offset(y: size * 0.66)
            ZStack {
                Color.clear.modifier(Glass(shape: shape))
                RadialGradient(stops: [.init(color: .clear, location: 0.12), .init(color: .black.opacity(0.5), location: 0.5), .init(color: .black.opacity(0.22), location: 1)],
                               center: UnitPoint(x: 0.49, y: 0.4), startRadius: 0, endRadius: size * 1.2) // cobre a cauda também, sem emenda
                Ellipse().fill(gradient(theme))
                    .frame(width: size * 0.7, height: size * 0.38)
                    .blur(radius: size * 0.1)
                    .offset(x: size * 0.06, y: size * 0.27)
                    .blendMode(.plusLighter)
                Circle().trim(from: 0.6, to: 0.88)
                    .stroke(.white.opacity(0.4), style: StrokeStyle(lineWidth: size * 0.045, lineCap: .round))
                    .frame(width: size * 0.8, height: size * 0.8)
                    .blur(radius: 1.2)
                Ellipse().fill(.white)
                    .frame(width: size * 0.22, height: size * 0.11)
                    .rotationEffect(.degrees(-35))
                    .blur(radius: 0.6)
                    .offset(x: -size * 0.19, y: -size * 0.25)
                Circle().fill(.white.opacity(0.85))
                    .frame(width: size * 0.055, height: size * 0.055)
                    .offset(x: -size * 0.02, y: -size * 0.33)
            }
            .frame(width: size * 3, height: size)
            .mask(shape)
            .shadow(color: themes[theme].colors[1].opacity(0.55), radius: size * 0.3)
        }
    }
}

// Intro: a gota nasce no centro com brilho e escorre até a borda.
struct Intro: View {
    static let travelAt = 1.1, contactAt = 1.85, bridgeAt = 1.55
    let start: Date, from: CGPoint, to: CGPoint, theme: Int
    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSince(start)
            let pop = t < 0.7 ? 1 - exp(-7 * t) * cos(14 * t) : 1.0 // nasce com overshoot de mola
            let jelly = 0.14 * exp(-3.5 * t) * sin(17 * t) // balança como gelatina
            let u = min(max((t - Intro.travelAt) / (Intro.contactAt - Intro.travelAt), 0), 1)
            let px = u * u, py = u * (2 - u) // acelera até encostar (sem frear); y adiantado = curva
            let glow = t < 0.15 ? t / 0.15 : max(0, 1 - (t - 0.15) / 1.1)
            let size = 64 - 32 * px
            let tint = themes[theme].colors[1]
            ZStack {
                Color.black.opacity(0.22 * glow).ignoresSafeArea() // escurece a tela um instante pra gota destacar
                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [tint.opacity(0.9), tint.opacity(0.3), .clear], center: .center, startRadius: 0, endRadius: 220))
                        .frame(width: 440, height: 440)
                        .scaleEffect(0.35 + 1.2 * (1 - glow))
                        .opacity(glow)
                        .blendMode(.plusLighter)
                    DropBall(size: size, tail: 2.6 * u * (1 - u * u), // cauda cresce com a velocidade e recolhe ao encostar
                              angle: .radians(atan2(to.y - from.y, to.x - from.x)), theme: theme)
                        .scaleEffect(x: max(pop, 0.01) * (1 + jelly), y: max(pop, 0.01) * (1 - jelly))
                }
                .position(x: from.x + (to.x - from.x) * px, y: from.y + (to.y - from.y) * py)
            }
        }
        .environment(\.colorScheme, .dark)
    }
}

// Mola amortecida: o balanço de líquido vem do overshoot.
struct Spring {
    var x: CGFloat, v: CGFloat = 0
    mutating func step(to target: CGFloat, k: CGFloat, c: CGFloat, dt: CGFloat) {
        v += (k * (target - x) - c * v) * dt
        x += v * dt
    }
}

final class App: NSObject, NSApplicationDelegate {
    let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    let liquid = Liquid()
    var r = Spring(x: closedR), d = Spring(x: closedD), f = Spring(x: closedF), cy = Spring(x: A / 2), len = Spring(x: 0)
    // gesto: parada → clique pendente → puxando a língua → bolha presa ao cursor → voando → gruda
    enum Mode { case docked, pending(NSPoint), pulling, held, flying }
    var mode = Mode.docked, wasPressed = false
    var restCy = A / 2 // onde a gota descansa ao longo da parede (fora do centro perto dos cantos)
    let ball = Ball()
    var ballSpring = (x: Spring(x: 0), y: Spring(x: 0), scale: Spring(x: 1))
    let ballPanel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    let detachSound = NSSound(named: "Bottle")
    var dwell: CGFloat = 0, last = CACurrentMediaTime()
    var introPose: (r: CGFloat, d: CGFloat, f: CGFloat)?
    var rippleArmed = false
    var wasDone = false
    let doneSound = NSSound(named: "Hero") // abriu: ao voltar pra borda, a onda corre // durante a intro: semente e depois ponte
    var status: NSStatusItem!
    lazy var settings: NSWindow = {
        let w = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
        w.title = tr("Ajustes do Contador", "Contador Settings")
        w.styleMask = [.titled, .closable]
        w.isReleasedWhenClosed = false
        return w
    }()

    func applicationDidFinishLaunching(_ n: Notification) {
        // primeira vez: 90 dias a partir de agora, e já abre os ajustes
        let firstRun = prefs.object(forKey: "start") == nil
        if firstRun {
            let now = Date().timeIntervalSince1970
            prefs.set(now, forKey: "start")
            prefs.set(now + 90 * 86400, forKey: "end")
        }

        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status.autosaveName = "contador"
        status.button?.image = NSImage(systemSymbolName: "drop.fill", accessibilityDescription: "Contador")
        let menu = NSMenu()
        menu.addItem(withTitle: tr("Ajustes…", "Settings…"), action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: tr("Sair do Contador", "Quit Contador"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        status.menu = menu
        NotificationCenter.default.addObserver(forName: .update, object: nil, queue: .main) { [weak self] _ in self?.runUpdate() }
        NotificationCenter.default.addObserver(forName: .askAccessibility, object: nil, queue: .main) { [weak self] _ in self?.requestAccessibility() }
        // pede logo depois da intro, se tem Dock visível e ainda não foi liberado nem recusado
        if !AXIsProcessTrusted(), !prefs.bool(forKey: "axDismissed"), dockFrame() != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + (firstRun ? 3.5 : 2.6)) { [weak self] in self?.requestAccessibility() }
        }
        checkUpdate()
        Timer.scheduledTimer(withTimeInterval: 86400, repeats: true) { [weak self] _ in self?.checkUpdate() }
        wasDone = Date().timeIntervalSince1970 >= prefs.double(forKey: "end")
        if prefs.object(forKey: "edge") == nil, prefs.bool(forKey: "left") { prefs.set(1, forKey: "edge") } // v1.0 guardava só esquerda/direita

        place()
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in self?.place() }
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in self?.place() }
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true // fechada: cliques passam pro que está atrás
        NotificationCenter.default.addObserver(forName: .openSettings, object: nil, queue: .main) { [weak self] _ in self?.openSettings() }
        let host = NSHostingView(rootView: Widget(liquid: liquid))
        host.sizingOptions = []
        panel.contentView = host
        panel.orderFrontRegardless()
        ballPanel.level = .statusBar
        ballPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        ballPanel.backgroundColor = .clear
        ballPanel.isOpaque = false
        ballPanel.hasShadow = false
        ballPanel.ignoresMouseEvents = true
        ballPanel.contentView = NSHostingView(rootView: BallView(ball: ball))
        // ponytail: polling do mouse a 60 Hz em vez de tracking area; sem redraw quando a gota está parada
        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer, forMode: .common)
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { if firstRun { openSettings() } } else { playIntro(then: firstRun) }
    }

    // abrir o app de novo (Finder, Spotlight) mostra os ajustes: o ícone pode sumir atrás do notch
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings()
        return false
    }

    // sons pré-carregados: decodificar do disco na hora da adesão travava um frame
    let glassSound = NSSound(named: "Glass"), popSound = NSSound(named: "Pop")
    var intro: NSPanel?, introT0: CFTimeInterval?, introSettings = false
    let contact: CGFloat = 16 // raio da bola ao chegar: (64 - 32) / 2

    func playIntro(then settings: Bool) {
        guard let s = NSScreen.screens.first?.frame else { return }
        let edge = screenPoint(CGPoint(x: P - contact, y: restCy))
        let intro = NSPanel(contentRect: s, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        intro.level = .statusBar
        intro.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        intro.backgroundColor = .clear
        intro.isOpaque = false
        intro.hasShadow = false
        intro.ignoresMouseEvents = true
        intro.setFrame(s, display: false)
        // mesmo instante pra view e pra física: a adesão acontece no frame exato do contato
        let startDate = Date()
        introT0 = CACurrentMediaTime()
        intro.contentView = NSHostingView(rootView: Intro(
            start: startDate,
            from: CGPoint(x: s.width / 2, y: s.height / 2),
            to: CGPoint(x: edge.x - s.minX, y: s.maxY - edge.y),
            theme: prefs.integer(forKey: "theme")))
        // semente: só um filete de líquido na borda esperando a gota
        introPose = (4, 0, 3)
        (r.x, d.x, f.x, len.x) = (4, 0, 3, 0)
        intro.orderFrontRegardless()
        self.intro = intro
        introSettings = settings
        glassSound?.play()
    }

    func ripple(_ strength: CGFloat = 0.4) {
        let t = Date()
        liquid.rippleStrength = strength
        liquid.ripple = t
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [self] in if liquid.ripple == t { liquid.ripple = nil } }
    }

    // chamado pelo tick, no relógio da física
    func introStep(_ t: CFTimeInterval) {
        if t >= Intro.bridgeAt, introPose?.d == 0 { introPose = (10, 12, 10) } // a borda estica em direção à gota
        guard t >= Intro.contactAt, let intro else { return }
        // adesão: a bola que encostou vira a gota da borda (mesma posição e tamanho),
        // chega com embalo e é puxada pra dentro: achata, espalha e assenta
        introT0 = nil
        introPose = nil
        r.x = contact; r.v = 90
        d.x = contact; d.v = -260
        f.v = 40
        cy.x = restCy; cy.v = 0
        ripple()
        popSound?.play()
        NSAnimationContext.runAnimationGroup({ $0.duration = 0.12; intro.animator().alphaValue = 0 }) { intro.orderOut(nil) }
        self.intro = nil
        if introSettings { DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [self] in openSettings() } } // depois da animação, pra não disputar frame
    }

    // Atualização: compara com a última release do GitHub; o instalador fecha este app e abre o novo.
    func checkUpdate() {
        URLSession.shared.dataTask(with: URL(string: "https://api.github.com/repos/AdrianoBinhara/contador/releases/latest")!) { data, _, _ in
            guard let data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = json["tag_name"] as? String else { return }
            let latest = tag.trimmingCharacters(in: CharacterSet(charactersIn: "v"))
            DispatchQueue.main.async { [self] in
                prefs.set(latest, forKey: "update")
                guard isNewer(latest), status.menu?.item(withTag: 7) == nil else { return }
                let item = NSMenuItem(title: tr("Atualizar para \(latest)", "Update to \(latest)"), action: #selector(runUpdate), keyEquivalent: "")
                item.target = self
                item.tag = 7
                status.menu?.insertItem(item, at: 0)
            }
        }.resume()
    }

    @objc func runUpdate() {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", "curl -fsSL https://raw.githubusercontent.com/AdrianoBinhara/contador/main/install.sh | sh"]
        try? p.run()
    }

    // Pedido próprio de Acessibilidade: o aviso nativo nem sempre aparece pra app sem janela.
    @objc func requestAccessibility() {
        guard !AXIsProcessTrusted() else { return }
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = tr("Deixar a gota pousar certinho no Dock?", "Let the drop land right on the Dock?")
        alert.informativeText = tr(
            "Pra saber onde o Dock começa e termina, o Contador precisa da permissão de Acessibilidade. Ele só lê a posição do Dock: não controla nada nem vê o que você digita.\n\nClique em Abrir Ajustes e ligue o Contador na lista.",
            "To know where the Dock starts and ends, Contador needs Accessibility permission. It only reads the Dock's position: it doesn't control anything or see what you type.\n\nClick Open Settings and turn Contador on in the list.")
        alert.addButton(withTitle: tr("Abrir Ajustes", "Open Settings"))
        alert.addButton(withTitle: tr("Agora não", "Not now"))
        guard alert.runModal() == .alertFirstButtonReturn else { prefs.set(true, forKey: "axDismissed"); return }
        AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false] as CFDictionary) // coloca o Contador na lista
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        // liberou: passa a usar o Dock exato na hora, sem reiniciar
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] t in
            guard AXIsProcessTrusted() else { return }
            t.invalidate()
            self?.place()
            self?.popSound?.play()
        }
    }

    @objc func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        if !settings.isVisible { settings.center() }
        settings.makeKeyAndOrderFront(nil)
        settings.makeFirstResponder(nil) // sem foco no nome: digitar sem querer não apaga a contagem
    }

    // monitor principal (o da barra de menus), na borda e posição escolhidas
    func place() {
        guard let screen = NSScreen.screens.first else { return }
        let s = screen.frame, v = screen.visibleFrame
        var edge = Edge(rawValue: prefs.integer(forKey: "edge")) ?? .right
        if edge == .notch, notchRect == nil { edge = .top } // monitor sem notch
        let pos = prefs.object(forKey: "height") as? Double ?? 0.5
        let cy = min(max(s.maxY - s.height * pos, s.minY + 30), v.maxY - 30), cx = min(max(s.minX + s.width * pos, s.minX + 30), s.maxX - 30)
        let y = min(max(cy - A / 2, s.minY), v.maxY - A)
        let x = min(max(cx - A / 2, s.minX), s.maxX - A)
        let frame = switch edge {
        case .right: NSRect(x: wall(.right, at: cy) - P, y: y, width: P, height: A)
        case .left: NSRect(x: wall(.left, at: cy), y: y, width: P, height: A)
        case .top: NSRect(x: x, y: v.maxY - P, width: A, height: P)
        case .bottom: NSRect(x: x, y: wall(.bottom, at: cx), width: A, height: P)
        case .notch: NSRect(x: (notchRect?.midX ?? s.midX) - A / 2, y: s.maxY - P, width: A, height: P)
        }
        if liquid.edge != edge { liquid.edge = edge }
        if frame != panel.frame { panel.setFrame(frame, display: true) }
        // a janela pode ter parado na beira da tela; a gota fica no ponto exato, não no centro da janela
        restCy = switch edge {
        case .right, .left: min(max(frame.maxY - cy, 30), A - 30)
        case .top, .bottom: min(max(cx - frame.minX, 30), A - 30)
        case .notch: A / 2
        }
    }

    // canônico ↔ tela
    func screenPoint(_ c: CGPoint) -> CGPoint {
        let l = c.applying(liquid.edge.transform), fr = panel.frame
        return CGPoint(x: fr.minX + l.x, y: fr.maxY - l.y)
    }
    func canonical(_ m: NSPoint) -> CGPoint {
        let fr = panel.frame
        return CGPoint(x: m.x - fr.minX, y: fr.maxY - m.y).applying(liquid.edge.transform.inverted())
    }

    // arrancou: a língua volta pra parede e uma bolha fica presa ao cursor
    func detach(at m: NSPoint) {
        guard let s = NSScreen.screens.first?.frame else { return }
        mode = .held
        liquid.open = false
        ballPanel.setFrame(s, display: false)
        let p = CGPoint(x: m.x - s.minX, y: s.maxY - m.y)
        ballSpring = (Spring(x: p.x), Spring(x: p.y), Spring(x: 0.55, v: 4))
        ball.pos = p
        ball.vel = .zero
        ball.scale = 0.55
        ballPanel.alphaValue = 1
        ballPanel.orderFrontRegardless()
        (r.v, d.v) = (0, -200) // a língua estala de volta
        ripple()
        detachSound?.play()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [self] in
            if case .docked = mode { return }
            panel.alphaValue = 0
        }
    }

    // grudou numa borda: a bolha vira a gota dessa borda com a mesma adesão da intro
    func stick(_ edge: Edge, at p: CGPoint, speed: CGFloat) {
        guard let s = NSScreen.screens.first?.frame, let v = NSScreen.screens.first?.visibleFrame else { return }
        let screen = CGPoint(x: p.x + s.minX, y: s.maxY - p.y)
        let pos = edge.isSide ? (s.maxY - screen.y) / s.height : (screen.x - s.minX) / s.width
        let impact = min(speed / 2200, 1) // quanto mais forte o arremesso, maior a onda e o achatamento
        prefs.set(edge.rawValue, forKey: "edge")
        prefs.set(min(max(Double(pos), 0), 1), forKey: "height") // sem margem extra: gruda onde bateu, até no canto
        place()
        mode = .docked
        liquid.open = false
        panel.ignoresMouseEvents = true
        r.x = contact; r.v = 90
        d.x = contact; d.v = -(140 + 380 * impact)
        r.v = 60 + 160 * impact // espalha mais
        f.x = 1; f.v = 40
        len.x = 0; len.v = 0
        cy.x = min(max(canonical(NSPoint(x: screen.x, y: screen.y)).y, 20), A - 20); cy.v = 0
        liquid.drop = Drop(cy: cy.x, r: r.x, d: d.x, f: f.x)
        panel.alphaValue = 1
        ripple(0.15 + 0.85 * impact)
        popSound?.volume = Float(0.35 + 0.65 * impact)
        popSound?.play()
        NSAnimationContext.runAnimationGroup({ $0.duration = 0.1; ballPanel.animator().alphaValue = 0 }) { [self] in ballPanel.orderOut(nil) }

    }

    func stepBall(_ m: NSPoint, pressed: Bool, dt: CGFloat) {
        guard let s = NSScreen.screens.first?.frame, let v = NSScreen.screens.first?.visibleFrame else { return }
        let cursor = CGPoint(x: m.x - s.minX, y: s.maxY - m.y)
        var (x, y, sc) = ballSpring
        if case .held = mode, !pressed { mode = .flying } // soltou: sai com a velocidade que já tinha
        if case .held = mode {
            x.step(to: cursor.x, k: 380, c: 26, dt: dt) // segue o cursor com atraso de mola
            y.step(to: cursor.y, k: 380, c: 26, dt: dt)
        } else {
            // voando: gravidade (arremesso fraco cai), atrito do ar e, só bem perto de uma borda,
            // tensão superficial puxando pra grudar
            let along = (x: x.x + s.minX, y: s.maxY - y.x) // posição em coordenadas de tela
            let walls: [(Edge, CGFloat)] = [
                (.left, x.x - (wall(.left, at: along.y) - s.minX)), (.right, (wall(.right, at: along.y) - s.minX) - x.x),
                (.top, y.x - (s.maxY - v.maxY)), (.bottom, (s.maxY - wall(.bottom, at: along.x)) - y.x),
            ]
            let (near, dist) = walls.min { $0.1 < $1.1 }!
            let snap = 2200 * max(0, 1 - dist / 70)
            let drag = exp(-0.35 * dt)
            x.v = x.v * drag + (near == .right ? snap : near == .left ? -snap : 0) * dt
            y.v = y.v * drag + (1500 + (near == .bottom ? snap : near == .top ? -snap : 0)) * dt
            x.x += x.v * dt
            y.x += y.v * dt
            if var hit = walls.first(where: { $0.1 <= 16 }) {
                ballSpring = (x, y, sc)
                if hit.0 == .top, let n = notchRect, (n.minX - 40...n.maxX + 40).contains(x.x + s.minX) { hit.0 = .notch } // entra no notch
                stick(hit.0, at: CGPoint(x: x.x, y: y.x), speed: hypot(x.v, y.v))
                return
            }
        }
        sc.step(to: 1, k: 260, c: 12, dt: dt) // nasce balançando
        ballSpring = (x, y, sc)
        ball.pos = CGPoint(x: x.x, y: y.x)
        ball.vel = CGVector(dx: x.v, dy: y.v)
        ball.scale = sc.x
    }

    func tick() {
        let now = CACurrentMediaTime(), dt = CGFloat(min(now - last, 1.0 / 30))
        last = now
        if let t0 = introT0 { introStep(now - t0) }
        let m = NSEvent.mouseLocation
        let pressed = NSEvent.pressedMouseButtons & 1 != 0
        defer { wasPressed = pressed }
        let edge = liquid.edge, open = edge.open, closed = edge.closed
        let p = canonical(m), cy0 = restCy
        let openHalf = open.r + open.len / 2 + open.f + 4
        let openCy = min(max(cy0, openHalf), A - openHalf) // card aberto sempre cabe inteiro na tela

        // intenção: 0,12 s parado na gota abre, 0,3 s fora fecha
        let reach = open.d + open.r, half = open.r + open.len / 2
        let zone = liquid.open
            ? CGRect(x: P - reach - 15, y: openCy - half - 25, width: reach + 15, height: 2 * half + 50)
            : edge == .notch
                ? CGRect(x: P - closed.d - closed.r, y: cy0 - closed.r - closed.len / 2, width: closed.d + closed.r, height: 2 * closed.r + closed.len) // só dentro do notch
                : CGRect(x: P - closed.d - closed.r - 40, y: cy0 - closed.r - closed.len / 2 - 30, width: closed.d + closed.r + 40, height: 2 * closed.r + closed.len + 60)

        switch mode {
        case .docked:
            if introT0 == nil {
                dwell = zone.contains(p) == liquid.open ? 0 : dwell + dt
                if dwell > (liquid.open ? 0.3 : 0.12) {
                    liquid.open.toggle()
                    dwell = 0
                    panel.ignoresMouseEvents = !liquid.open // aberta: dá pra clicar e arrastar
                }
                if pressed, !wasPressed, liquid.open, zone.contains(p) { mode = .pending(m) }
            }
        case .pending(let m0):
            if !pressed { mode = .docked; openSettings() } // clique simples: ajustes
            else if hypot(m.x - m0.x, m.y - m0.y) > 6 { mode = .pulling; liquid.open = false }
        case .pulling:
            if !pressed { mode = .docked } // soltou antes de descolar: volta com mola
            else if P - p.x > 170 { detach(at: m) }
        case .held, .flying:
            stepBall(m, pressed: pressed, dt: dt)
        }

        // magnetismo: perto do cursor a gota incha e escorre na direção dele
        var s = max(0, 1 - hypot(p.x - (P - closed.d - closed.r), p.y - cy0) / 180)
        s = edge == .notch ? 0 : s * s * (3 - 2 * s) // no notch, nada de magnetismo
        let o = liquid.open
        switch mode {
        case .pulling: // a língua segue a mão
            r.step(to: 17, k: 400, c: 30, dt: dt)
            d.step(to: min(max(P - p.x - 17, closed.d), 300), k: 400, c: 30, dt: dt)
            f.step(to: 12, k: 300, c: 26, dt: dt)
            len.step(to: 0, k: 300, c: 26, dt: dt)
            cy.step(to: min(max(p.y, 40), A - 40), k: 400, c: 30, dt: dt)
        case .held, .flying: // descolou: sobra só um filete que some
            r.step(to: 4, k: 140, c: 14, dt: dt)
            d.step(to: 0, k: 190, c: 17, dt: dt)
            f.step(to: 3, k: 160, c: 18, dt: dt)
            len.step(to: 0, k: 200, c: 20, dt: dt)
            cy.step(to: cy.x, k: 1, c: 1, dt: dt)
        default:
            if let pose = introPose {
                r.step(to: pose.r, k: 140, c: 14, dt: dt)
                d.step(to: pose.d, k: 190, c: 17, dt: dt)
                f.step(to: pose.f, k: 160, c: 18, dt: dt)
            } else {
                r.step(to: o ? open.r : closed.r + 3 * s, k: 140, c: 14, dt: dt)
                d.step(to: o ? open.d : closed.d + 12 * s, k: 190, c: 17, dt: dt)
                f.step(to: o ? open.f : closed.f, k: 160, c: 18, dt: dt)
            }
            len.step(to: o ? open.len : closed.len, k: 170, c: 18, dt: dt)
            cy.step(to: o ? openCy : cy0 + min(max(p.y - cy0, -28), 28) * s, k: 220, c: 24, dt: dt)
        }

        // chegou a zero agora: comemora uma vez
        let done = Date().timeIntervalSince1970 >= prefs.double(forKey: "end")
        if done, !wasDone { ripple(); doneSound?.play() }
        wasDone = done

        if liquid.open { rippleArmed = true }
        else if rippleArmed, d.x < closed.d + 24 { rippleArmed = false; ripple() } // a língua bateu de volta na borda

        let old = liquid.drop
        let moved = abs(old.cy - cy.x) + abs(old.r - r.x) + abs(old.d - d.x) + abs(old.f - f.x) + abs(old.len - len.x)
        if moved > 0.02 { liquid.drop = Drop(cy: cy.x, r: r.x, d: d.x, f: f.x, len: len.x) }
    }
}

let app = NSApplication.shared
let delegate = App()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
