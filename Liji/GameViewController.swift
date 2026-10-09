import UIKit
import WebKit
import UniformTypeIdentifiers

// The app only renders its bundled page. No remote pages or script dependencies.
final class GameViewController: UIViewController, WKUIDelegate, WKNavigationDelegate, WKScriptMessageHandler, UIDocumentPickerDelegate {
    private var webView: WKWebView!
    private var exportURL: URL?
    private var importing = false
    private var store: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("liji-data.json")
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.965, green: 0.969, blue: 0.976, alpha: 1)
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.userContentController.add(self, name: "liji")
        var source = "window.__lijiNative = true;"
        var readError: String?
        if FileManager.default.fileExists(atPath: store.path) {
            do {
                let data = try Data(contentsOf: store)
                let object = try JSONSerialization.jsonObject(with: data)
                guard let dict = object as? [String: Any], dict["schema"] as? Int == 1 else { throw CocoaError(.fileReadCorruptFile) }
                let base64 = data.base64EncodedString()
                source += "window.__lijiInitial = JSON.parse(new TextDecoder().decode(Uint8Array.from(atob('\(base64)'), c=>c.charCodeAt(0))));"
            } catch {
                // Never silently overwrite a damaged native record.
                source += "window.__lijiReadError = true;"
                readError = "本地数据未能读取。请先备份现有文件，或导入之前导出的备份。当前页面不会自动覆盖损坏的数据。"
            }
        }
        config.userContentController.addUserScript(WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        webView = WKWebView(frame: .zero, configuration: config)
        webView.uiDelegate = self
        webView.navigationDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = view.backgroundColor
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor)
        ])
        if let url = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "Web") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else {
            readError = "缺少内置页面，请重新构建应用。"
        }
        if let message = readError { DispatchQueue.main.async { self.showError(message) } }
    }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame, message.frameInfo.request.url?.isFileURL == true,
              let body = message.body as? [String: Any], let action = body["action"] as? String else { return }
        if action == "import" {
            guard presentedViewController == nil else { return }
            importing = true
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.json], asCopy: true)
            picker.delegate = self
            picker.allowsMultipleSelection = false
            present(picker, animated: true)
            return
        }
        guard let text = body["text"] as? String, let bytes = text.data(using: .utf8), bytes.count <= 10 * 1024 * 1024 else { return }
        do {
            let object = try JSONSerialization.jsonObject(with: bytes)
            guard let dict = object as? [String: Any], dict["schema"] as? Int == 1 else { throw CocoaError(.fileReadCorruptFile) }
            if action == "save" {
                try FileManager.default.createDirectory(at: store.deletingLastPathComponent(), withIntermediateDirectories: true)
                try bytes.write(to: store, options: .atomic)
            } else if action == "export" {
                guard presentedViewController == nil else { return }
                let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd"
                let file = directory.appendingPathComponent("立记-备份-\(formatter.string(from: Date())).json")
                try bytes.write(to: file, options: .atomic)
                exportURL = file
                importing = false
                let picker = UIDocumentPickerViewController(forExporting: [file], asCopy: true)
                picker.delegate = self
                present(picker, animated: true)
            }
        } catch {
            if action == "save" {
                webView.evaluateJavaScript("warn('手机未能写入本地数据，请立即导出备份。');", completionHandler: nil)
            } else { showError("文件操作失败：\(error.localizedDescription)") }
        }
    }
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        if importing, let file = urls.first {
            importing = false
            let granted = file.startAccessingSecurityScopedResource()
            defer { if granted { file.stopAccessingSecurityScopedResource() } }
            do {
                let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard size <= 10 * 1024 * 1024 else { throw CocoaError(.fileReadTooLarge) }
                let bytes = try Data(contentsOf: file)
                guard bytes.count <= 10 * 1024 * 1024 else { throw CocoaError(.fileReadTooLarge) }
                let base64 = bytes.base64EncodedString()
                // Delay the confirmation until the file picker has dismissed.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    self.webView.evaluateJavaScript("window.lijiImportBase64('\(base64)');", completionHandler: nil)
                }
            } catch { DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { self.showError("无法读取备份：\(error.localizedDescription)") } }
        }
        cleanupExport()
    }
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { importing = false; cleanupExport() }
    private func cleanupExport() {
        if let file = exportURL { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        exportURL = nil
    }
    private func showError(_ message: String) {
        guard presentedViewController == nil else { return }
        let alert = UIAlertController(title: "立记", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "知道了", style: .default))
        present(alert, animated: true)
    }
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        guard presentedViewController == nil else { completionHandler(); return }
        let alert = UIAlertController(title: "立记", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好", style: .default) { _ in completionHandler() })
        present(alert, animated: true)
    }
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        guard presentedViewController == nil else { completionHandler(false); return }
        let alert = UIAlertController(title: "请确认", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: "确认", style: .default) { _ in completionHandler(true) })
        present(alert, animated: true)
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let url = navigationAction.request.url
        decisionHandler(url?.isFileURL == true ? .allow : .cancel)
    }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        // Reloading restores persisted localStorage after an OS WebKit process eviction.
        webView.reload()
    }
}
