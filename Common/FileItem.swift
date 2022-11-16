//
// FileItem.swift
//

import Foundation

@objc(FileItem)
class FileItem: NSObject, NSSecureCoding {
	var name: String
	var directory: String
	
	init(url: URL) {
		self.name = FileManager.default.displayName(atPath: url.path)
		self.directory = url.deletingLastPathComponent().path
	}
	
	func encode(with aCoder: NSCoder) {
		aCoder.encode(self.name, forKey: "name")
		aCoder.encode(self.directory, forKey: "directory")
	}
	
	required init?(coder aDecoder: NSCoder) {
		self.name = aDecoder.decodeObject(of: [NSString.self], forKey: "name") as? String ?? ""
		self.directory = aDecoder.decodeObject(of: [NSString.self], forKey: "directory") as? String ?? ""
		super.init()
	}
	
	static var supportsSecureCoding: Bool {
		true
	}

}
