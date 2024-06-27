//
// XPCService.swift
//

import Foundation

class XPCService: NSObject, XPCServiceProtocol {
    
	@objc func fileList(bookmarkData: Data, clientServiceProxy: ClientServiceProtocol, reply: @Sendable @escaping ([FileItem]) -> Void) {
		var dirUrl: URL! = nil
		do {
			var isStale: Bool = false
			
			dirUrl = try URL(resolvingBookmarkData: bookmarkData, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale)
		} catch let error as NSError {
			if #available(macOS 13.0, *) {
				NSLog("Error:%@[file=%@, line=%d]", error.localizedDescription, URL(filePath: #file).lastPathComponent, #line)
			} else {
				NSLog("Error:%@[file=%@, line=%d]", error.localizedDescription, URL(fileURLWithPath: #file).lastPathComponent, #line)
			}
			reply([])
			return
		}
		
		let _ = dirUrl.startAccessingSecurityScopedResource()
		defer {
			dirUrl.stopAccessingSecurityScopedResource()
		}
		let propertiesForKeys: [URLResourceKey] = [.isDirectoryKey, .isPackageKey]
		let options: FileManager.DirectoryEnumerationOptions = [.skipsPackageDescendants]
		guard let enumerator = FileManager.default.enumerator(at: dirUrl, includingPropertiesForKeys: propertiesForKeys, options: options, errorHandler: { (url, error) -> Bool in
			if #available(macOS 13.0, *) {
				NSLog("Error:%@[path=%@, file=%@, line=%d]", error.localizedDescription, url.path(percentEncoded: false), URL(filePath: #file).lastPathComponent, #line)
			} else {
				NSLog("Error:%@[path=%@, file=%@, line=%d]", error.localizedDescription, url.path, URL(fileURLWithPath: #file).lastPathComponent, #line)
			}
			return true
		}) else {
			if #available(macOS 13.0, *) {
				NSLog("Error:FileManager.enumerator[path=%@, file=%@, line=%d]", dirUrl.path(percentEncoded: false), URL(filePath: #file).lastPathComponent, #line)
			} else {
				NSLog("Error:FileManager.enumerator[path=%@, file=%@, line=%d]", dirUrl.path, URL(fileURLWithPath: #file).lastPathComponent, #line)
			}
			reply([])
			return
		}
		
		var fileItems: [FileItem] = []
		
		for case let url as URL in enumerator {
			do {
				let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
				let isDirectory: Bool = values.isDirectory ?? false
				let isPackage: Bool = values.isPackage ?? false
				
				if isPackage || !isDirectory {
					clientServiceProxy.add(url: url) // サービスからクライアントへの呼び出し
					
					fileItems.append(FileItem(url: url))
				}
				
			} catch {
				if #available(macOS 13.0, *) {
					NSLog("Error:URL.resourceValues[path=%@, file=%@, line=%d]", url.path(percentEncoded: false), URL(filePath: #file).lastPathComponent, #line)
				} else {
					NSLog("Error:URL.resourceValues[path=%@, file=%@, line=%d]", url.path, URL(fileURLWithPath: #file).lastPathComponent, #line)
				}
			}
		}
		
		reply(fileItems)
	}
	
}
