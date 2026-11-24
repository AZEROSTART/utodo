import Foundation

public let storeChangedNotification = Notification.Name("com.azerostart.utodo.storeChanged")

public func postStoreChanged() {
    DistributedNotificationCenter.default().post(name: storeChangedNotification, object: nil)
}
