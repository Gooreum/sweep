import SwiftUI

/// 검색과 정리의 진행 정보를 같은 배치로 보여줘 단계가 바뀌어도 읽기 쉽다.
struct Retro95ScanPanel: View {
    let title: String
    let headline: String
    let detail: String?
    let fraction: Double?
    let percentText: String?
    let leftFooter: String?
    let rightFooter: String?

    var body: some View {
        Retro95GroupBox(title: title) {
            HStack(spacing: 16) {
                PixelIcon(art: .computerLarge, size: 64)

                VStack(alignment: .leading, spacing: 8) {
                    Text(headline)
                        .font(R95.ui(13, bold: true))

                    if let detail {
                        Text(detail)
                            .font(R95.ui(12))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    HStack(spacing: 8) {
                        Retro95ProgressBar(fraction: fraction)
                        if let percentText {
                            Text(percentText)
                                .font(R95.mono(13))
                                .frame(width: 48, alignment: .trailing)
                        }
                    }

                    if leftFooter != nil || rightFooter != nil {
                        HStack {
                            if let leftFooter { Text(leftFooter) }
                            Spacer()
                            if let rightFooter { Text(rightFooter) }
                        }
                        .font(R95.mono(12))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .foregroundStyle(R95.black)
        }
        .frame(maxWidth: .infinity)
    }
}
