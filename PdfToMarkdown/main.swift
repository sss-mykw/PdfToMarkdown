import Foundation
import PDFKit

// 引数取得
let arguments = CommandLine.arguments

guard arguments.count > 1 else {
    print("使い方: swift pdf_to_md.swift /path/to/file.pdf")
    exit(1)
}

let pdfPath = arguments[1]
let pdfURL = URL(fileURLWithPath: pdfPath)

// 出力ファイル名（PDFと同名で拡張子.md）
let outputURL = pdfURL.deletingPathExtension().appendingPathExtension("md")

// PDF読み込み
guard let pdfDocument = PDFDocument(url: pdfURL) else {
    print("エラー: PDFを読み込めませんでした")
    exit(1)
}

// Markdownテキストを構築
var markdownText = "# PDFから抽出されたテキスト\n\n"

for i in 0..<pdfDocument.pageCount {
    guard let page = pdfDocument.page(at: i) else { continue }
    let text = page.string ?? ""
    markdownText += "## Page \(i + 1)\n\n"
    markdownText += text
    markdownText += "\n\n---\n\n"
}

// 書き出し
do {
    try markdownText.write(to: outputURL, atomically: true, encoding: .utf8)
    print("✅ Markdownとして保存されました: \(outputURL.path)")
} catch {
    print("❌ 書き込みに失敗しました: \(error.localizedDescription)")
    exit(1)
}
