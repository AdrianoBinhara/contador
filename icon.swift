// Gera Icon.icns: gota com gradiente Aurora sobre squircle escuro. Uso: swift icon.swift
import SwiftUI

struct Tear: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width, h = r.height
        p.move(to: CGPoint(x: w / 2, y: 0))
        p.addCurve(to: CGPoint(x: w, y: h * 0.64), control1: CGPoint(x: w * 0.58, y: h * 0.16), control2: CGPoint(x: w, y: h * 0.36))
        p.addArc(center: CGPoint(x: w / 2, y: h * 0.64), radius: w / 2, startAngle: .zero, endAngle: .degrees(180), clockwise: false)
        p.addCurve(to: CGPoint(x: w / 2, y: 0), control1: CGPoint(x: 0, y: h * 0.36), control2: CGPoint(x: w * 0.42, y: h * 0.16))
        return p
    }
}

struct Icon: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 185, style: .continuous)
                .fill(LinearGradient(colors: [Color(white: 0.2), Color(white: 0.06)], startPoint: .top, endPoint: .bottom))
                .frame(width: 824, height: 824)
                .shadow(color: .black.opacity(0.35), radius: 20, y: 10)
            Tear()
                .fill(LinearGradient(colors: [Color(red: 0.49, green: 0.95, blue: 0.84), Color(red: 0.43, green: 0.66, blue: 1.0), Color(red: 0.66, green: 0.56, blue: 1.0)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 380, height: 520)
                .shadow(color: Color(red: 0.43, green: 0.66, blue: 1.0).opacity(0.6), radius: 40)
                .offset(y: 10)
            Ellipse().fill(.white.opacity(0.85)).frame(width: 70, height: 34).blur(radius: 6)
                .rotationEffect(.degrees(-40)).offset(x: -80, y: 70)
        }
        .frame(width: 1024, height: 1024)
    }
}

let set = "Icon.iconset"
try? FileManager.default.createDirectory(atPath: set, withIntermediateDirectories: true)
MainActor.assumeIsolated {
    for s in [16, 32, 128, 256, 512] {
        for k in [1, 2] {
            let r = ImageRenderer(content: Icon())
            r.scale = CGFloat(s * k) / 1024
            let rep = NSBitmapImageRep(cgImage: r.cgImage!)
            try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(set)/icon_\(s)x\(s)\(k == 2 ? "@2x" : "").png"))
        }
    }
}
