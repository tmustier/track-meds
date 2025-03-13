import SwiftUI

// This is a standalone Swift file to generate the app icon
// You can run this file in Xcode or with swift command line

struct MedicationIconView: View {
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color(#colorLiteral(red: 0.2392156869, green: 0.6745098233, blue: 0.9686274529, alpha: 1)), Color(#colorLiteral(red: 0.2196078449, green: 0.007843137719, blue: 0.8549019694, alpha: 1))]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Pill icon
            VStack(spacing: 0) {
                Image(systemName: "pills.fill")
                    .font(.system(size: 400, weight: .bold))
                    .foregroundColor(.white)
                    .opacity(0.9)
                
                // Optional: Add a small text badge or indicator
                Text("Reminder")
                    .font(.system(size: 100, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 50)
            }
            .padding(100)
        }
        .frame(width: 1024, height: 1024)
    }
}

// Preview provider
struct MedicationIconView_Previews: PreviewProvider {
    static var previews: some View {
        MedicationIconView()
    }
}