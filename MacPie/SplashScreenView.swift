import SwiftUI

struct SplashScreenView: View {
    @State private var isLoading = true
    @State private var loadingText = "Starting"
    @State private var dots = ""
    @State private var loadingTimer: Timer?
    
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    
    var body: some View {
        ZStack {
            // Background
            Color(hex: "222425")
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // App Icon
                Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                
                // App Name
                Text("MacPie")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
                
                // Version
                Text("Version \(appVersion) (\(buildNumber))")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(hex: "8b8b8b"))
                
                // Loading indicator
                VStack(spacing: 16) {
                    // Progress bar
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "4a9eff")))
                        .scaleEffect(1.2)
                    
                    // Loading text with animated dots
                    HStack(spacing: 0) {
                        Text(loadingText)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                        Text(dots)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(Color(hex: "4a9eff"))
                    }
                }
                .padding(.top, 20)
            }
        }
        .frame(width: 400, height: 500)
        .onAppear {
            startLoadingAnimation()
        }
        .onDisappear {
            cleanup()
        }
    }
    
    private func startLoadingAnimation() {
        // Animate dots
        loadingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            if dots.count >= 3 {
                dots = ""
            } else {
                dots += "."
            }
        }
        
        // Hide splash screen after 3.5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            withAnimation(.easeInOut(duration: 0.5)) {
                isLoading = false
            }
        }
    }
    
    private func cleanup() {
        loadingTimer?.invalidate()
        loadingTimer = nil
    }
}

#Preview {
    SplashScreenView()
}
