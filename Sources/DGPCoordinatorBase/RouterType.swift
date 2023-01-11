import Foundation
import UIKit

public enum PresentationType {
    case fullScreen
    case pageSheet(dismissOnSwipeDown: Bool)
    case overCurrentContext
}

public protocol RouterType: AnyObject {
    func start()
    func pushViewController(_ viewController: UIViewController, animated: Bool)
    func popViewController(animated: Bool)
    func popToRootViewController(animated: Bool)
    func setViewController(
        _ viewController: UIViewController,
        animated: Bool)

    func present(
        coordinator: (RouterType) -> CoordinatorType,
        presentationType: PresentationType,
        onCompletion: (VoidClosure)?)
    func pushFlow(coordinator: (RouterType) -> CoordinatorType)

    func back()
    func close(_ completion: (VoidClosure)?)
}

private protocol BaseRouter: RouterType {
    var navigationController: UINavigationController? { get }
}

extension BaseRouter {
    public func pushViewController(_ viewController: UIViewController, animated: Bool) {
        navigationController?.pushViewController(viewController, animated: animated)
    }

    public func present(
        coordinator: (RouterType) -> CoordinatorType,
        presentationType: PresentationType,
        onCompletion: (VoidClosure)?
    ) {
        guard let navigationController = navigationController else { return }
        let vNavigation = VerticalRouter(
            presenter: navigationController,
            presentationType: presentationType,
            onCloseButtonTap: nil,
            onPresentedCompletion: onCompletion)

        coordinator(vNavigation).start()
        vNavigation.start()
    }

    public func pushFlow(coordinator: (RouterType) -> CoordinatorType) {
        guard let navigationController = navigationController else { return }
        let newRouter = HorizontalRouter(navigationController: navigationController)
        coordinator(newRouter).start()
        newRouter.start()
    }

    public func popViewController(animated: Bool) {
        navigationController?.popViewController(animated: animated)
    }

    public func popToRootViewController(animated: Bool) {
        navigationController?.popToRootViewController(animated: animated)
    }

    public func setViewController(_ viewController: UIViewController, animated: Bool) {
        guard let navigationController = navigationController else { return }
        if !navigationController.viewControllers.isEmpty {
            var viewControllers = navigationController.viewControllers
            viewControllers.removeLast()
            viewControllers.append(viewController)
            navigationController.setViewControllers(viewControllers, animated: animated)
        }
    }
}

public class HorizontalRouter: BaseRouter {
    weak var navigationController: UINavigationController?
    private let coordinatorRootViewController: UIViewController?

    private let onCloseButtonTap: (VoidClosure)?

    public init(
        navigationController: UINavigationController,
        onCloseButtonTap: (VoidClosure)? = nil
    ) {
        self.navigationController = navigationController
        self.onCloseButtonTap = onCloseButtonTap
        self.coordinatorRootViewController = navigationController.topViewController
    }

    public func close(_ completion: (VoidClosure)?) {
        guard let coordinatorRootViewController = coordinatorRootViewController,
        let navigationController = navigationController else {
            assertionFailure("Unexpected nil value")
            completion?()
            return
        }

        navigationController.popToViewController(coordinatorRootViewController, animated: true)
        completion?()
    }

    public func back() {
        guard let navigationController = navigationController else {
            return
        }

        var previousController: UIViewController? {
            let viewControllers = navigationController.viewControllers
            return viewControllers.count > 1 ?
            viewControllers[viewControllers.count - 2] : nil
        }

        if previousController == coordinatorRootViewController {
            close(onCloseButtonTap)
        } else {
            navigationController.popViewController(animated: true)
        }
    }

    // Horizontal Router does not have to do anything for starting
    // as will remain in the current navigationFlow. The vertical navigator
    // will configure and present itself in this method
    public func start() {

    }

}

public class VerticalRouter: BaseRouter {
    weak var navigationController: UINavigationController?

    /// Keep a strong references until controller it's presented
    private var navigationControllerNotPresented: UINavigationController?

    private weak var presenter: UIViewController?
    private let presentationType: PresentationType
    private let onCloseButtonTap: (VoidClosure)?
    private let onPresentedCompletion: (VoidClosure)?

    public init(
        presenter: UIViewController,
        presentationType: PresentationType,
        onCloseButtonTap: (VoidClosure)? = nil,
        onPresentedCompletion: (VoidClosure)? = nil
    ) {
        self.presenter = presenter
        self.presentationType = presentationType
        self.onCloseButtonTap = onCloseButtonTap
        self.onPresentedCompletion = onPresentedCompletion
        self.navigationControllerNotPresented = UINavigationController()
        self.navigationController = navigationControllerNotPresented
    }

    public func close(_ completion: (VoidClosure)?) {
        presenter?.dismiss(animated: true, completion: completion)
    }

    public func back() {
        guard let navigationController = navigationController else {
            return
        }
        if navigationController.viewControllers.count <= 1 {
            close(onCloseButtonTap)
        } else {
            navigationController.popViewController(animated: true)
        }
    }

    public func start() {
        guard let navigationControllerNotPresented = navigationControllerNotPresented, let presenter = presenter else {
            return
        }

        navigationControllerNotPresented.setPresentationType(presentationType)

        if case let .pageSheet(dismissOnSwipeDown) = presentationType {
            navigationControllerNotPresented.isModalInPresentation = !dismissOnSwipeDown
        }

        if case .overCurrentContext = presentationType,
           presenter.tabBarController != nil {
            presenter.tabBarController?.present(
                navigationControllerNotPresented,
                animated: true,
                completion: self.onPresentedCompletion)
        } else {
            presenter.present(navigationControllerNotPresented, animated: true, completion: self.onPresentedCompletion)
        }

        self.navigationControllerNotPresented = nil
    }
}

extension UINavigationController {
    func setPresentationType(_ type: PresentationType) {
        switch type {
        case .fullScreen:
            self.modalPresentationStyle = .fullScreen
        case .pageSheet:
            self.modalPresentationStyle = .pageSheet
        case .overCurrentContext:
            self.modalPresentationStyle = .overCurrentContext
        }
    }
}
