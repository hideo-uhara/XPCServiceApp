//
// XPCServiceProtocol.swift
//

import Foundation

@objc(XPCServiceProtocol)
protocol XPCServiceProtocol {

	func fileList(bookmarkData: Data, clientServiceProxy: ClientServiceProtocol, reply: @escaping ([FileItem]) -> Void)

}
