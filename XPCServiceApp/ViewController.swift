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
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		self.connectionToService = NSXPCConnection(serviceName: "com.mac.uhara.XPCService")
		self.connectionToService.remoteObjectInterface = NSXPCInterface(with: XPCServiceProtocol.self)
		self.proxy = connectionToService.remoteObjectProxy as? XPCServiceProtocol
		
		// fileListメソッドのclientServiceProxyの引数はインスタンスではなく、ClientServiceProtocolのProxy
		self.connectionToService.remoteObjectInterface?.setInterface(NSXPCInterface(with: ClientServiceProtocol.self), for: #selector(XPCServiceProtocol.fileList(bookmarkData:clientServiceProxy:reply:)), argumentIndex: 1, ofReply: false)
		
		// fileListメソッドの戻値には、カスタムクラスを含む
		let classes = NSSet(objects: NSArray.self, FileItem.self) as! Set<AnyHashable>
		
		self.connectionToService.remoteObjectInterface?.setClasses(classes, for: #selector(XPCServiceProtocol.fileList(bookmarkData:clientServiceProxy:reply:)), argumentIndex: 0, ofReply: true)

		
		self.connectionToService.resume()
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
							NSLog("Error:%@[file=%@, line=%d]", error.localizedDescription, URL(fileURLWithPath: #file).lastPathComponent, #line)
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
	
	@objc func add(url: URL) {
		//print(url.path)
		
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
	
	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
		let tableCellView: NSTableCellView = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "TableCellView"), owner: nil) as! NSTableCellView
		let titleTextField: NSTextField = tableCellView.viewWithTag(1) as! NSTextField
		
		if tableColumn?.identifier.rawValue == "NameColumn" {
			titleTextField.stringValue = FileManager.default.displayName(atPath: self.urls[row].path)
		} else if tableColumn?.identifier.rawValue == "DirectoryColumn" {
			titleTextField.stringValue = self.urls[row].deletingLastPathComponent().path
		}
		
		return tableCellView
	}
	
}

extension ViewController: NSTableViewDelegate {
	
	func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
		return 24.0
	}
}

