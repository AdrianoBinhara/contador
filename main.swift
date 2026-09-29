import SwiftUI
import AppKit

import ServiceManagement

// Preferências (UserDefaults). Datas em segundos desde 1970.
let prefs = UserDefaults.standard
let week: Double = 7 * 86400

let themes: [(name: String, colors: [Color])] = [
    ("Aurora", [Color(red: 0.49, green: 0.95, blue: 0.84), Color(red: 0.43, green: 0.66, blue: 1.0), Color(red: 0.66, green: 0.56, blue: 1.0)]),
    ("Brasa", [Color(red: 1.0, green: 0.78, blue: 0.35), Color(red: 1.0, green: 0.45, blue: 0.4), Color(red: 0.93, green: 0.3, blue: 0.62)]),
    ("Oceano", [Color(red: 0.4, green: 0.9, blue: 1.0), Color(red: 0.25, green: 0.55, blue: 1.0), Color(red: 0.35, green: 0.3, blue: 0.95)]),
    ("Lima", [Color(red: 0.85, green: 1.0, blue: 0.4), Color(red: 0.45, green: 0.92, blue: 0.5), Color(red: 0.2, green: 0.78, blue: 0.7)]),
    ("Grafite", [Color(white: 0.95), Color(white: 0.75), Color(white: 0.55)]),
]
func gradient(_ i: Int) -> LinearGradient {
    LinearGradient(colors: themes[min(max(i, 0), themes.count - 1)].colors, startPoint: .leading, endPoint: .trailing)
}

// Poses da gota: fechada (quase só o menisco) e aberta (esticada como língua de líquido).
let closedR: CGFloat = 15, closedD: CGFloat = 8, closedF: CGFloat = 11
let openR: CGFloat = 47, openD: CGFloat = 262, openF: CGFloat = 18

// Gota presa na borda direita: calota de raio r com centro a d px da borda,
// fundida à borda por um menisco de raio f.
struct Drop: Shape {
    var cy: CGFloat, r: CGFloat, d: CGFloat, f: CGFloat

    func path(in rect: CGRect) -> Path {
        let w = rect.maxX, r = max(r, 1), d = max(d, 0), f = max(f, 1)
        // menisco encosta na calota (d < f) ou na lateral reta do corpo (d >= f)
        let dy = d < f ? sqrt((r + f) * (r + f) - (f - d) * (f - d)) : r + f
        let t = d < f ? atan2(dy, f - d) : .pi / 2
        var p = Path()
        p.move(to: CGPoint(x: w, y: cy - dy))
        arc(&p, CGPoint(x: w - f, y: cy - dy), f, 0, t)
        arc(&p, CGPoint(x: w - d, y: cy), r, .pi + t, .pi - t)
        arc(&p, CGPoint(x: w - f, y: cy + dy), f, -t, 0)
        p.closeSubpath()
        return p
    }

    // ponytail: arco como polilinha densa, evita a ambiguidade de sentido do addArc com y pra baixo
    private func arc(_ p: inout Path, _ c: CGPoint, _ r: CGFloat, _ a0: CGFloat, _ a1: CGFloat) {
        for i in 0...32 {
            let a = a0 + (a1 - a0) * CGFloat(i) / 32
            p.addLine(to: CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a)))
        }
    }
}

struct Tick {
    let left: Int, elapsed: Double, progress: Double
    let unit: String, unitSize: Double, units: Int
    init(_ now: Date, start: Double, end: Double) {
        let total = max(end - start, 60)
        elapsed = min(max(now.timeIntervalSince1970 - start, 0), total)
        left = Int(total - elapsed)
        progress = elapsed / total
        // segmentos: dias até 2 semanas, semanas até ~6 meses, depois meses
        (unit, unitSize) = total <= 14 * 86400 ? ("dia", 86400) : total <= 26 * week ? ("semana", week) : ("mês", 30.44 * 86400)
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
                    let f = min(max(t.elapsed / t.unitSize - Double(i), 0), 1)
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
        let days = t.left / 86400
        let current = min(t.units, Int(t.elapsed / t.unitSize) + 1)
        let plural = t.unit == "mês" ? "meses" : t.unit + "s"
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("\(days)").font(.system(size: 32, weight: .semibold, design: .rounded))
                Text(days == 1 ? "dia" : "dias").font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%02d:%02d:%02d", t.left % 86400 / 3600, t.left % 3600 / 60, t.left % 60))
                    .font(.system(size: 15, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
            }
            .monospacedDigit()
            .contentTransition(.numericText(countsDown: true))
            .animation(.snappy, value: t.left)
            Segments(t: t, theme: theme)
            HStack {
                Text((title.isEmpty ? "" : title + " · ") + "\(t.unit) \(current) de \(t.units)")
                    .lineLimit(1)
                    .accessibilityLabel("\(t.unit) \(current) de \(t.units) \(plural)")
                Spacer()
                Text(t.progress, format: .percent.precision(.fractionLength(1))).foregroundStyle(gradient(theme))
            }
            .font(.system(size: 10.5, weight: .medium, design: .rounded))
            .foregroundStyle(.secondary)
        }
    }
}

// Ótica de gota: brilho especular em cima à esquerda, cáustica colorida embaixo.
struct Shine: View {
    let drop: Drop, w: CGFloat, theme: Int, e: CGFloat
    var body: some View {
        let r = drop.r, reach = drop.d + drop.r
        let cap = CGPoint(x: w - drop.d, y: drop.cy)
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
                .frame(width: reach * 0.9, height: r * 0.6)
                .blur(radius: r * 0.35)
                .opacity(0.55)
                .blendMode(.plusLighter)
                .position(x: w - reach / 2, y: drop.cy + r * 0.72)
            Ellipse().fill(.white.opacity(0.9))
                .frame(width: min(r * 0.6, 12), height: min(r * 0.26, 4.5))
                .blur(radius: 1)
                .rotationEffect(.degrees(-38))
                .position(x: w - drop.d - r * 0.62, y: drop.cy - r * 0.5)
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
    @Published var drop = Drop(cy: 130, r: closedR, d: closedD, f: closedF)
    @Published var open = false
    @Published var ripple: Date? // instante da adesão: luz corre pela borda
}

// Onda de luz subindo e descendo pela borda a partir do ponto de contato.
struct Ripple: View {
    let start: Date, cy: CGFloat, w: CGFloat, theme: Int
    var body: some View {
        TimelineView(.animation) { ctx in
            let t = min(ctx.date.timeIntervalSince(start) / 0.7, 1)
            let ease = 1 - (1 - t) * (1 - t)
            ZStack {
                ForEach([-1.0, 1.0], id: \.self) { dir in
                    Capsule().fill(gradient(theme))
                        .frame(width: 2, height: 26 * (1 - t) + 6)
                        .blur(radius: 1.5)
                        .shadow(color: themes[theme].colors[1], radius: 6)
                        .position(x: w - 1, y: cy + dir * (18 + 110 * ease))
                        .opacity(1 - t)
                }
            }
            .blendMode(.plusLighter)
        }
    }
}

struct Widget: View {
    @ObservedObject var liquid: Liquid
    @AppStorage("start") var start = 0.0
    @AppStorage("end") var end = 0.0
    @AppStorage("title") var title = ""
    @AppStorage("theme") var theme = 0
    @AppStorage("left") var left = false

    var body: some View {
        let drop = liquid.drop
        let flip: CGFloat = left ? -1 : 1 // lado esquerdo = mesma gota espelhada
        GeometryReader { g in
            let w = g.size.width
            let e = min(max((drop.d - closedD) / (openD - closedD), 0), 1) // 0 = gota, 1 = aberta
            ZStack {
                Color.clear.modifier(Glass(shape: drop))
                Shine(drop: drop, w: w, theme: theme, e: e)
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    Details(t: Tick(ctx.date, start: start, end: end), title: title, theme: theme)
                        .frame(width: 252)
                        .scaleEffect(x: flip)
                        .position(x: w - 24 - 126, y: drop.cy)
                        .opacity(Double((e - 0.5) * 2))
                        .blur(radius: (1 - e) * 8)
                        .offset(x: (1 - e) * 40)
                }
            }
            .mask(drop)
            .overlay { if let t0 = liquid.ripple { Ripple(start: t0, cy: drop.cy, w: w, theme: theme) } }
            .contentShape(drop)
            .onTapGesture { NotificationCenter.default.post(name: .openSettings, object: nil) }
        }
        .scaleEffect(x: flip)
        .environment(\.colorScheme, .dark)
    }
}

extension Notification.Name { static let openSettings = Notification.Name("openSettings") }

struct SettingsView: View {
    @AppStorage("title") var title = ""
    @AppStorage("start") var start = 0.0
    @AppStorage("end") var end = 0.0
    @AppStorage("theme") var theme = 0
    @AppStorage("left") var left = false
    @AppStorage("height") var height = 0.5
    @AppStorage("locked") var locked = false
    @State var login = SMAppService.mainApp.status == .enabled
    @State var confirmReset = false

    func date(_ v: Binding<Double>) -> Binding<Date> {
        Binding(get: { Date(timeIntervalSince1970: v.wrappedValue) }, set: { v.wrappedValue = $0.timeIntervalSince1970 })
    }

    var body: some View {
        Form {
            Section("Contagem") {
                TextField("Nome", text: $title, prompt: Text("Ex.: Lançamento"))
                DatePicker("Início", selection: date($start), displayedComponents: [.date, .hourAndMinute])
                    .disabled(locked)
                DatePicker("Fim", selection: date($end), in: Date(timeIntervalSince1970: start + 60)..., displayedComponents: [.date, .hourAndMinute])
                    .disabled(locked)
                HStack {
                    Button("Reiniciar contagem…") { confirmReset = true }.disabled(locked)
                    Spacer()
                    if locked {
                        Button("Destravar", systemImage: "lock.open") { locked = false }
                    } else {
                        Button("Travar", systemImage: "lock") { locked = true }
                    }
                }
                if locked {
                    Text("Travada: datas e reinício bloqueados contra clique acidental.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Section("Aparência") {
                LabeledContent("Cor") {
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
                Picker("Lado da tela", selection: $left) {
                    Text("Direita").tag(false)
                    Text("Esquerda").tag(true)
                }
                .pickerStyle(.segmented)
                LabeledContent("Altura na borda") {
                    Slider(value: $height, in: 0.1...0.9) { EmptyView() } minimumValueLabel: { Image(systemName: "arrow.up") } maximumValueLabel: { Image(systemName: "arrow.down") }
                }
            }
            Section {
                Toggle("Abrir ao iniciar o Mac", isOn: $login)
                    .onChange(of: login) { _, on in
                        try? on ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
                        login = SMAppService.mainApp.status == .enabled
                    }
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
        .confirmationDialog("Reiniciar a contagem?", isPresented: $confirmReset) {
            Button("Reiniciar", role: .destructive) {
                let now = Date().timeIntervalSince1970
                (start, end) = (now, now + (end - start)) // mesma duração, começando agora
            }
        } message: {
            Text("Começa de novo a partir de agora, com a mesma duração.")
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
    var r = Spring(x: closedR), d = Spring(x: closedD), f = Spring(x: closedF), cy = Spring(x: 130)
    var dwell: CGFloat = 0, last = CACurrentMediaTime()
    var introPose: (r: CGFloat, d: CGFloat, f: CGFloat)?
    var rippleArmed = false // abriu: ao voltar pra borda, a onda corre // durante a intro: semente e depois ponte
    var status: NSStatusItem!
    lazy var settings: NSWindow = {
        let w = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
        w.title = "Ajustes do Contador"
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
        menu.addItem(withTitle: "Ajustes…", action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Sair do Contador", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        status.menu = menu

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
        let fr = panel.frame
        let edge = CGPoint(x: prefs.bool(forKey: "left") ? fr.minX + contact : fr.maxX - contact, y: fr.midY)
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
        (r.x, d.x, f.x) = (4, 0, 3)
        intro.orderFrontRegardless()
        self.intro = intro
        introSettings = settings
        glassSound?.play()
    }

    func ripple() {
        let t = Date()
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
        cy.x = panel.frame.height / 2; cy.v = 0
        ripple()
        popSound?.play()
        NSAnimationContext.runAnimationGroup({ $0.duration = 0.12; intro.animator().alphaValue = 0 }) { intro.orderOut(nil) }
        self.intro = nil
        if introSettings { DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [self] in openSettings() } } // depois da animação, pra não disputar frame
    }

    @objc func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        if !settings.isVisible { settings.center() }
        settings.makeKeyAndOrderFront(nil)
    }

    // monitor principal (o da barra de menus), na borda e altura escolhidas
    func place() {
        guard let s = NSScreen.screens.first?.visibleFrame else { return }
        let h = prefs.object(forKey: "height") as? Double ?? 0.5
        let y = min(max(s.maxY - s.height * h - 130, s.minY), s.maxY - 260)
        let frame = NSRect(x: prefs.bool(forKey: "left") ? s.minX : s.maxX - 360, y: y, width: 360, height: 260)
        if frame != panel.frame { panel.setFrame(frame, display: true) }
    }

    func tick() {
        let now = CACurrentMediaTime(), dt = CGFloat(min(now - last, 1.0 / 30))
        last = now
        if let t0 = introT0 { introStep(now - t0) }
        let fr = panel.frame, m = NSEvent.mouseLocation
        var p = CGPoint(x: m.x - fr.minX, y: fr.maxY - m.y) // coordenada local, y pra baixo
        if prefs.bool(forKey: "left") { p.x = fr.width - p.x } // mesma física, espelhada
        let w = fr.width, cy0 = fr.height / 2

        // intenção: 0,12 s parado na gota abre, 0,3 s fora fecha
        let zone = liquid.open
            ? CGRect(x: w - 325, y: cy0 - 75, width: 325, height: 150)
            : CGRect(x: w - 56, y: cy0 - 50, width: 56, height: 100)
        dwell = zone.contains(p) == liquid.open ? 0 : dwell + dt
        if dwell > (liquid.open ? 0.3 : 0.12) {
            liquid.open.toggle()
            dwell = 0
            panel.ignoresMouseEvents = !liquid.open // aberta: clique no card abre os ajustes
        }

        // magnetismo: perto do cursor a gota incha e escorre na direção dele
        var s = max(0, 1 - hypot(p.x - (w - 18), p.y - cy0) / 180)
        s = s * s * (3 - 2 * s)
        let o = liquid.open
        if let pose = introPose {
            r.step(to: pose.r, k: 140, c: 14, dt: dt)
            d.step(to: pose.d, k: 190, c: 17, dt: dt)
            f.step(to: pose.f, k: 160, c: 18, dt: dt)
        } else {
            r.step(to: o ? openR : closedR + 3 * s, k: 140, c: 14, dt: dt)
            d.step(to: o ? openD : closedD + 12 * s, k: 190, c: 17, dt: dt)
            f.step(to: o ? openF : closedF, k: 160, c: 18, dt: dt)
        }
        cy.step(to: o ? cy0 : cy0 + min(max(p.y - cy0, -28), 28) * s, k: 220, c: 24, dt: dt)

        if liquid.open { rippleArmed = true }
        else if rippleArmed, d.x < closedD + 24 { rippleArmed = false; ripple() } // a língua bateu de volta na borda

        let old = liquid.drop
        let moved = abs(old.cy - cy.x) + abs(old.r - r.x) + abs(old.d - d.x) + abs(old.f - f.x)
        if moved > 0.02 { liquid.drop = Drop(cy: cy.x, r: r.x, d: d.x, f: f.x) }
    }
}

let app = NSApplication.shared
let delegate = App()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
