import Foundation
import PDFKit

import Foundation // URLやFileManagerを使うために必要

// MARK: - 引数パース
/// コマンドライン引数をパースし、入力PDFファイルのURLと出力MarkdownファイルのURLを返します。
///
/// 使い方: swift main.swift <入力PDFファイルパス> [--output <出力ディレクトリまたはファイルパス>]
///
/// - Returns: (pdfURL: 入力PDFファイルのURL, outputURL: 出力MarkdownファイルのURL)
/// - Exits: 引数が不適切、入力ファイルが存在しない、またはデフォルト出力先ディレクトリが存在しない場合
func parseArguments() -> (pdfURL: URL, outputURL: URL) {
    let args = CommandLine.arguments

    // 引数の最小数をチェック（スクリプト名 + inputファイルパス = 2つ）
    guard args.count >= 2 else {
        print("使い方: swift main.swift /path/to/input.pdf [--output /path/to/output_directory_or_file.md]")
        print("例1: swift main.swift input.pdf") // デフォルト出力先: ./output/input.md
        print("例2: swift main.swift input.pdf --output ./my_output/") // 指定ディレクトリ内: ./my_output/input.md
        print("例3: swift main.swift input.pdf --output ./specific_output.md") // 指定ファイルパス: ./specific_output.md
        exit(1)
    }

    let inputPath = args[1]
    let inputURL = URL(fileURLWithPath: inputPath)

    // 入力ファイルが存在するかチェック
    if !FileManager.default.fileExists(atPath: inputURL.path) {
        print("エラー: 入力ファイル '\(inputURL.path)' が見つかりません。")
        exit(1)
    }

    // 入力ファイル名（拡張子なし）を取得
    let baseName = inputURL.deletingPathExtension().lastPathComponent

    var outputURL: URL?

    // MARK: --output オプションのハンドリング
    if let outputIndex = args.firstIndex(of: "--output"), outputIndex + 1 < args.count {
        let outputPath = args[outputIndex + 1]
        let potentialOutputURL = URL(fileURLWithPath: outputPath)

        var isDirectory: ObjCBool = false
        let fileManager = FileManager.default

        // 指定されたパスが既存のディレクトリとして存在するか確認
        // fileExistsはファイルとディレクトリ両方でtrueになるため、isDirectoryフラグも確認
        if fileManager.fileExists(atPath: potentialOutputURL.path, isDirectory: &isDirectory) && isDirectory.boolValue {
            // パスが既存のディレクトリの場合：
            // そのディレクトリ配下に inputファイル名.md で保存するファイルパスを生成
            outputURL = potentialOutputURL.appendingPathComponent("\(baseName).md")
            print("INFO: 出力先ディレクトリが指定されました: '\(potentialOutputURL.path)'")
            print("INFO: 実際の出力ファイルパス: '\(outputURL!.path)'")
        } else {
            // パスが既存のファイル、または存在しない場合：
            // 指定されたパスをそのまま出力ファイルパスとして扱う
            outputURL = potentialOutputURL
            if fileManager.fileExists(atPath: potentialOutputURL.path) {
                print("INFO: 出力先ファイルパスが指定されました (既存ファイル): '\(outputURL!.path)'")
            } else {
                print("INFO: 新しい出力先ファイルパスが指定されました: '\(outputURL!.path)'")
            }
        }

    } else {
        // MARK: --output オプションが指定されなかった場合（デフォルトの出力先）
        // スクリプト実行ディレクトリにある "output" フォルダに保存
        let scriptPath = URL(fileURLWithPath: CommandLine.arguments[0])
        let scriptDir = scriptPath.deletingLastPathComponent()
        let outputDir = scriptDir.appendingPathComponent("output")

        var isDirectory: ObjCBool = false
        let fileManager = FileManager.default

        // デフォルトの出力ディレクトリが存在し、かつディレクトリであることを確認
        if !fileManager.fileExists(atPath: outputDir.path, isDirectory: &isDirectory) || !isDirectory.boolValue {
            print("エラー: デフォルトの出力先ディレクトリ '\(outputDir.path)' が見つからないか、ディレクトリではありません。")
            print("スクリプトと同じ階層に 'output' という名前のディレクトリを作成してください、")
            print("または --output オプションで出力先を指定してください。")
            exit(1)
        }

        // デフォルトの出力ファイルパスを生成: ./output/inputファイル名.md
        outputURL = outputDir.appendingPathComponent("\(baseName).md")
        print("INFO: デフォルトの出力先: '\(outputURL!.path)'")
    }

    // ここまで到達すれば outputURL は確実にセットされている
    guard let finalOutputURL = outputURL else {
        // 論理的にはここに到達しないはずだが、念のためのエラーハンドリング
        print("致命的なエラー: 出力先URLの決定に失敗しました。")
        exit(1)
    }

    return (inputURL, finalOutputURL)
}

// MARK: - 本処理
let (pdfURL, outputURL) = parseArguments()

guard let pdfDoc = PDFDocument(url: pdfURL) else {
    print("❌ PDFを読み込めませんでした: \(pdfURL.path)")
    exit(1)
}

var markdown = "# PDFから抽出されたテキスト\n\n"

for i in 0..<pdfDoc.pageCount {
    guard let page = pdfDoc.page(at: i) else { continue }
    markdown += "## Page \(i + 1)\n\n"
    markdown += page.string ?? "(空のページ)"
    markdown += "\n\n---\n\n"
}

// MARK: - 書き込み
do {
    try markdown.write(to: outputURL, atomically: true, encoding: .utf8)
    print("✅ Markdownとして保存されました: \(outputURL.path)")
} catch {
    print("❌ 書き込み失敗: \(error.localizedDescription)")
    exit(1)
}
