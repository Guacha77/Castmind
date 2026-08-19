import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var app: AppState
    @State private var page = 0
    @State private var choice: LocalModelChoice = .balanced

    var body: some View {
        ZStack {
            CastmindBackground(accent: CM.orange)
            ScrollView {
                VStack(alignment:.leading, spacing:22) {
                    Text("CASTMIND_V3").font(.system(.largeTitle, design:.monospaced).weight(.black))
                    Text(pageTitle).font(.system(.title, design:.monospaced).weight(.black))
                    Text(pageSubtitle).foregroundStyle(CM.textSecondary)
                    if page == 0 { intro }
                    else if page == 1 { modelPicker }
                    else { ready }
                }.padding(20).padding(.bottom,110)
            }.scrollBounceBehavior(.basedOnSize)
        }
        .safeAreaInset(edge:.bottom, spacing:0) {
            VStack(spacing:9) {
                HStack(spacing:5) { ForEach(0..<3,id:\.self){i in Rectangle().fill(i==page ? CM.orange : CM.border).frame(height:3)} }
                Button(page == 2 ? "ENTER_CASTMIND" : "CONTINUAR →") {
                    if page < 2 { page += 1 }
                    else { app.settings.modelChoice=choice; app.saveSettings(); app.completeOnboarding(); Task{await app.preloadModel()} }
                }.buttonStyle(CMPrimaryButtonStyle())
            }.padding(12).background(CM.background).overlay(alignment:.top){Rectangle().fill(CM.border).frame(height:1)}
        }
    }

    private var pageTitle:String { ["LOCAL CHARACTER SYSTEM","ELIGE EL CEREBRO","LISTO"][page] }
    private var pageSubtitle:String { ["Personajes locales, memoria propia y voz. Sin cuentas ni coste por mensaje.","Todos los personajes comparten un único modelo en RAM.","El modelo se descargará una vez y después se cargará automáticamente."][page] }
    private var intro: some View { VStack(alignment:.leading,spacing:0){row("01","PROMPT ÚNICO POR PERSONAJE");row("02","MEMORIA INDEPENDIENTE");row("03","VOZ + MICRÓFONO LOCAL");row("04","SALAS SINGLE-SPEAKER")}.overlay(Rectangle().stroke(CM.border)) }
    private func row(_ n:String,_ t:String)->some View { HStack{Text(n).foregroundStyle(CM.orange).frame(width:32);Text(t);Spacer()}.font(.caption.monospaced().bold()).padding(13).overlay(alignment:.bottom){Rectangle().fill(CM.border).frame(height:1)} }

    private var modelPicker: some View {
        VStack(spacing:0){ ForEach(LocalModelChoice.allCases){m in Button{choice=m}label:{HStack(spacing:12){Text(choice==m ? "●":"○").foregroundStyle(choice==m ? CM.orange:CM.textTertiary);VStack(alignment:.leading,spacing:4){Text(m.title.uppercased()).font(.headline.monospaced().bold()).foregroundStyle(.white);Text(m.subtitle).font(.caption).foregroundStyle(CM.textSecondary)};Spacer();Text(m.badge).font(.caption2.monospaced().bold()).foregroundStyle(m == .balanced ? CM.orange:CM.textSecondary)}.padding(14).background(choice==m ? CM.elevated2:.clear).overlay(alignment:.bottom){Rectangle().fill(CM.border).frame(height:1)}}.buttonStyle(.plain)} }.overlay(Rectangle().stroke(CM.border))
    }
    private var ready: some View { VStack(alignment:.leading,spacing:10){Text("MODEL / \(choice.title)");Text("AUTO_LOAD / ON");Text("STRICT_BEHAVIOR / ON");Text("LOCAL_MEMORY / ON")}.font(.body.monospaced().bold()).padding(16).frame(maxWidth:.infinity,alignment:.leading).overlay(Rectangle().stroke(CM.border)) }
}
