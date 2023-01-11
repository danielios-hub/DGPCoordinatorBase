import Foundation

public typealias VoidClosure = () -> Void
public typealias InputClosure<T> = (T) -> Void

public protocol CoordinatorType {
    func start()
    func close(_ completion: VoidClosure?)
}
