//
// ViewController.swift
//

import Cocoa

class ViewController: NSViewController, ClientServiceProtocol {
	var connectionToService: NSXPCConnection! = nil
	var proxy: XPCServiceProtocol! = nil
	var openPanel: NSOpenPanel! = nil
	var urls: [URL] = []
	
	@IBOutlet var tableView: NSTableView!
	@IBOutlet var selectDirectoryButton: NSButton!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		self.connectionToService = NSXPCConnection(serviceName: "com.mac.uhara.XPCService")
		self.connectionToService.remoteObjectInterface = NSXPCInterface(with: XPCServiceProtocol.self)
		self.proxy = self.connectionToService.remoteObjectProxy as? XPCServiceProtocol
		
		// fileListメソッドのclientServiceProxyの引数はインスタンスではなく、ClientServiceProtocolのProxy
		self.connectionToService.remoteObjectInterface?.setInterface(NSXPCInterface(with: ClientServiceProtocol.self), for: #selector(XPCServiceProtocol.fileList(bookmarkData:clientServiceProxy:reply:)), argumentIndex: 1, ofReply: false)
		
		// fileListメソッドの戻値には、カスタムクラスを含む
		let classes = NSSet(objects: NSArray.self, FileItem.self) as! Set<AnyHashable>
		
		self.connectionToService.remoteObjectInterface?.setClasses(classes, for: #selector(XPCServiceProtocol.fileList(bookmarkData:clientServiceProxy:reply:)), argumentIndex: 0, ofReply: true)

		
		self.connectionToService.resume()
		
		// 保存したURLでファイル一覧取得
		guard let savedBookmarkData: Data = UserDefaults.standard.object(forKey: "bookmarkData") as? Data else {
			return
		}
			
		var url: URL! = nil
		
		do {
			var isStale: Bool = false
			
			url = try URL(resolvingBookmarkData: savedBookmarkData, options: [.withSecurityScope, .withoutMounting, .withoutUI], relativeTo: nil, bookmarkDataIsStale: &isStale)
			
			// bookmarkData再作成
			if isStale {
				var bookmarkData: Data! = nil
				
				do {
					let _ = url.startAccessingSecurityScopedResource()
					
					bookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
					url.stopAccessingSecurityScopedResource()
				} catch {
					if #available(macOS 13.0, *) {
						NSLog("Error:%@[file=%@, line=%d]", error.localizedDescription, URL(filePath: #file).lastPathComponent, #line)
					} else {
						NSLog("Error:%@[file=%@, line=%d]", error.localizedDescription, URL(fileURLWithPath: #file).lastPathComponent, #line)
					}
					return
				}
				
				// urlを保存
				UserDefaults.standard.set(bookmarkData, forKey: "bookmarkData")
			}
		} catch {
			if #available(macOS 13.0, *) {
				NSLog("Error:%@[file=%@, line=%d]", error.localizedDescription, URL(filePath: #file).lastPathComponent, #line)
			} else {
				NSLog("Error:%@[file=%@, line=%d]", error.localizedDescription, URL(fileURLWithPath: #file).lastPathComponent, #line)
			}
			return
		}
		
		var bookmarkData: Data! = nil
		do {
			let _ = url.startAccessingSecurityScopedResource()
			bookmarkData = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
			url.stopAccessingSecurityScopedResource()
		} catch let error as NSError {
			if #available(macOS 13.0, *) {
				NSLog("Error:%@[file=%@, line=%d]", error.localizedDescription, URL(filePath: #file).lastPathComponent, #line)
			} else {
				NSLog("Error:%@[file=%@, line=%d]", error.localizedDescription, URL(fileURLWithPath: #file).lastPathComponent, #line)
			}
			return
		}
			
		self.selectDirectoryButton.isEnabled = false
		
		self.proxy.fileList(bookmarkData: bookmarkData, clientServiceProxy: self) { fileItems in
			for fileItem: FileItem in fileItems {
				print("\(fileItem.name) - \(fileItem.directory)")
			}
			
			DispatchQueue.main.async {
				self.selectDirectoryButton.isEnabled = true
			}
		}

	}
	
	override var representedObject: Any? {
		didSet {
		}
	}
	
	@IBAction func buttonAction(_ sender: NSButton) {
		if self.openPanel == nil {
			self.openPanel = NSOpenPanel()
			self.openPanel.canChooseFiles = false
			self.openPanel.canChooseDirectories = true
			self.openPanel.allowsMultipleSelection = false
			self.openPanel.message = NSLocalizedString("Open", comment: "")
			
			self.openPanel.begin(completionHandler: { (num) -> Void in
				if num == NSApplication.ModalResponse.OK {
					
					if let url = self.openPanel.url {
						var bookmarkData: Data! = nil
						do {
							bookmarkData = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
						} catch let error as NSError {
							if #available(macOS 13.0, *) {
								NSLog("Error:%@[file=%@, line=%d]", error.localizedDescription, URL(filePath: #file).lastPathComponent, #line)
							} else {
								NSLog("Error:%@[file=%@, line=%d]", error.localizedDescription, URL(fileURLWithPath: #file).lastPathComponent, #line)
							}
							return
						}
						
						sender.isEnabled = false
						self.urls = []
						self.tableView.reloadData()
						
						self.proxy.fileList(bookmarkData: bookmarkData, clientServiceProxy: self) { fileItems in
							for fileItem: FileItem in fileItems {
								print("\(fileItem.name) - \(fileItem.directory)")
							}
							
							DispatchQueue.main.async {
								sender.isEnabled = true
								
								var bookmarkData: Data! = nil
								
								do {
									bookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
								} catch {
									if #available(macOS 13.0, *) {
										NSLog("Error:%@[file=%@, line=%d]", error.localizedDescription, URL(filePath: #file).lastPathComponent, #line)
									} else {
										NSLog("Error:%@[file=%@, line=%d]", error.localizedDescription, URL(fileURLWithPath: #file).lastPathComponent, #line)
									}
									return
								}
								
								// urlを保存
								UserDefaults.standard.set(bookmarkData, forKey: "bookmarkData")
							}
						}
					}
				} else if num == NSApplication.ModalResponse.cancel {
				}
				
				self.openPanel = nil
			})
		} else {
			self.openPanel.makeKeyAndOrderFront(self)
		}
	}
	
	@objc nonisolated func add(url: URL) {
		/*
		if #available(macOS 13.0, *) {
			print(url.path(percentEncoded: false))
		} else {
			print(url.path)
		}
		*/
		
		DispatchQueue.main.async {
			self.urls.append(url)
			self.tableView.insertRows(at: IndexSet(integer: self.urls.count - 1), withAnimation: .slideUp)
		}
	}
	
}

extension ViewController: NSTableViewDataSource {
	
	func numberOfRows(in tableView: NSTableView) -> Int {
		return self.urls.count
	}
	
}

extension ViewController: NSTableViewDelegate {
	
	func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
		return 24.0
	}
	
	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
		let tableCellView: NSTableCellView = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "TableCellView"), owner: nil) as! NSTableCellView
		let titleTextField: NSTextField = tableCellView.viewWithTag(1) as! NSTextField
		
		if tableColumn?.identifier.rawValue == "NameColumn" {
			if #available(macOS 13.0, *) {
				titleTextField.stringValue = FileManager.default.displayName(atPath: self.urls[row].path(percentEncoded: false))
			} else {
				titleTextField.stringValue = FileManager.default.displayName(atPath: self.urls[row].path)
			}
		} else if tableColumn?.identifier.rawValue == "DirectoryColumn" {
			if #available(macOS 13.0, *) {
				titleTextField.stringValue = self.urls[row].deletingLastPathComponent().path(percentEncoded: false)
			} else {
				titleTextField.stringValue = self.urls[row].deletingLastPathComponent().path
			}
		}
		
		return tableCellView
	}

}

