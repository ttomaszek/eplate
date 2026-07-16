import SwiftUI

struct LookupRowView: View {
    let region: RegionModel
    
    var body: some View {
        HStack(spacing: 16) {
            // Large badge for the prefix
            Text(region.prefix)
                .font(.system(.title3, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 60, height: 42)
                .background(
                    LinearGradient(
                        colors: [Color.blue, Color(red: 0.0, green: 0.4, blue: 0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(region.displayName)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text("siedziba: \(region.seat) • \(region.wojewodztwo)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(14)
        .background(Color.white.opacity(0.04))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}
