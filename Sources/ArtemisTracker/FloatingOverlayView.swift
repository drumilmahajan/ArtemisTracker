import SwiftUI

struct FloatingOverlayView: View {
    @ObservedObject var viewModel: ArtemisViewModel
    var onClose: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 14))
                .foregroundStyle(.yellow)

            // MET
            Text(viewModel.met)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.primary)

            if let data = viewModel.latestData {
                Rectangle().fill(.separator).frame(width: 1, height: 24)

                VStack(alignment: .leading, spacing: 1) {
                    Text("EARTH")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundStyle(.blue.opacity(0.7))
                    Text(data.distanceFromEarthFormatted)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                }

                Rectangle().fill(.separator).frame(width: 1, height: 24)

                VStack(alignment: .leading, spacing: 1) {
                    Text("MOON")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundStyle(.gray)
                    Text(data.distanceFromMoonFormatted)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                }

                Rectangle().fill(.separator).frame(width: 1, height: 24)

                VStack(alignment: .leading, spacing: 1) {
                    Text("SPEED")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundStyle(.orange.opacity(0.7))
                    Text(MissionData.speedContext(kmPerSec: data.speedKmS))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                }

                Circle().fill(.green).frame(width: 5, height: 5)
            } else if viewModel.isLoading {
                ProgressView().scaleEffect(0.7)
            }

            Spacer(minLength: 2)

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}
