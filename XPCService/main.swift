//
// main.swift
//

import Foundation

class ServiceDelegate: NSObject, NSXPCListenerDelegate {
    
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        
        newConnection.exportedInterface = NSXPCInterface(with: XPCServiceProtocol.self)
		
		// fileListメソッドのclientServiceProxyの引数はインスタンスではなく、ClientServiceProtocolのProxy
		newConnection.exportedInterface?.setInterface(NSXPCInterface(with: ClientServiceProtocol.self), for: #selector(XPCServiceProtocol.fileList(bookmarkData:clientServiceProxy:reply:)), argumentIndex: 1, ofReply: false)
		
		// fileListメソッドの戻値には、カスタムクラスを含む
		let classes = NSSet(objects: NSArray.self, FileItem.self) as! Set<AnyHashable>
		
		newConnection.exportedInterface?.setClasses(classes, for: #selector(XPCServiceProtocol.fileList(bookmarkData:clientServiceProxy:reply:)), argumentIndex: 0, ofReply: true)
		
        let exportedObject = XPCService()
        newConnection.exportedObject = exportedObject
        
        newConnection.resume()
        
        return true
    }
}

let delegate = ServiceDelegate()

let listener = NSXPCListener.service()
listener.delegate = delegate

listener.resume()
