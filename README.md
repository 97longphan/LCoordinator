# Coordinator Architecture Documentation

## Table of Contents
1. [Overview](#overview)
2. [Core Components](#core-components)
3. [Data Flow & Communication](#data-flow--communication)
4. [Navigation System](#navigation-system)
5. [Advanced Patterns](#advanced-patterns)
6. [Memory Management](#memory-management)
7. [Best Practices](#best-practices)

---

## Overview

### What is Coordinator Pattern?

Coordinator pattern là một architectural pattern giúp tách biệt navigation logic khỏi ViewControllers. Trong project này, Coordinator đảm nhận vai trò điều phối flow giữa các màn hình, quản lý lifecycle của ViewControllers, và xử lý communication giữa các modules.

### Why Coordinators?

**Problems Solved:**
- **ViewControllers không còn phải biết về navigation** → Reusable & Testable
- **Centralized navigation logic** → Dễ maintain & debug
- **Clear separation of concerns** → ViewModel chỉ handle business logic, Coordinator handle navigation
- **Better deep linking support** → Có thể navigate từ bất kỳ đâu trong app
- **Improved testability** → Mock coordinators để test flows

---

## Core Components

### 1. Coordinator Protocol

```swift
protocol Coordinator: AnyObject {
    var parentCoordinator: Coordinator? { get set }
    var children: [Coordinator] { get set }

    func start()
    func childDidFinish(_ child: Coordinator)
}
```

**Core Concepts:**
- **Parent-Child Hierarchy:** Mỗi coordinator có thể có parent và nhiều children, tạo thành một tree structure
- **`start()`:** Entry point để khởi động flow của coordinator
- **`childDidFinish()`:** Cleanup method khi child coordinator hoàn thành và cần được remove

**Tree Structure:**
```
AppCoordinator (root)
  ├─ MHStartupCoordinator
  │   └─ MHPopupFlowCoordinator
  └─ MHTabbarCoordinator
      ├─ MHHomeCoordinator
      │   ├─ MHHomeHeaderPluginCoordinator [embedded]
      │   └─ DetailCoordinator [pushed]
      ├─ ProfileCoordinator
      └─ OrderCoordinator
```

### 2. RouterCoordinator Protocol

```swift
protocol RouterCoordinator: Coordinator {
    var router: RouterProtocol { get set }
    var presentationStyle: RouterPresentationStyle { get }
    var parentRouter: RouterProtocol { get set }
}
```

**Presentation Styles:**
- **`.push`** → Push vào navigation stack
- **`.present(UIModalPresentationStyle)`** → Present modal với style (fullScreen, pageSheet, etc.)
- **`.panModel`** → Present bottom sheet sử dụng PanModal
- **`.none`** → No presentation (dành cho embedded coordinators như plugins)

**Router vs ParentRouter:**
- **`router`:** Router hiện tại của coordinator (có thể thay đổi khi present modal)
- **`parentRouter`:** Lưu trữ router ban đầu, dùng để dismiss/pop về parent

**Flow when presenting modal:**
```
1. Before present: router === parentRouter (cùng instance)
2. Create new NavigationController for modal
3. Create new Router for modal's navigation stack
4. parentRouter = router (save current)
5. router = newRouter (replace with modal router)
6. On dismiss: router restored to parentRouter
```

### 3. Base Coordinator Hierarchy

Project có nhiều base classes phục vụ cho các use cases khác nhau:

```
BaseCoordinator
  ├─ BaseContextCoordinator<Context>
  └─ BaseRouterCoordinator
       └─ BaseRouterContextCoordinator<Context>

BaseAppCoordinator<Factory: FlowFactory>
```

**BaseCoordinator:**
- Simplest form, chỉ implement Coordinator protocol
- Use case: Non-router coordinators (như HomeStartupCoordinator - chỉ orchestrate flow, không present UI)

**BaseRouterCoordinator:**
- Coordinator có router để navigate
- Use case: Hầu hết các coordinators present UI (push/modal)

**BaseContextCoordinator<Context>:**
- Coordinator nhận context khi khởi tạo
- Context chứa data cần thiết cho flow
- Use case: Coordinator cần external data (user info, configuration, etc.)

**BaseRouterContextCoordinator<Context>:**
- Combine cả Router và Context
- Use case: Most common - coordinator cần navigation và data

**BaseAppCoordinator<Factory>:**
- Root coordinator của app
- Manage app-level flows thông qua FlowFactory
- Responsible for switching major flows (onboarding → login → home)

### 4. Router & Navigation System

**Router Protocol:**
```swift
protocol RouterProtocol: AnyObject {
    var navigationController: UINavigationController { get }

    // Push navigation
    func push(drawable: Drawable, to: Coordinator, isAnimated: Bool, onNavigateBack: (() -> Void)?)
    func pop(isAnimated: Bool)
    func popToRootCoordinator(isAnimated: Bool)
    func popToCoordinator(coordinator: Coordinator, isAnimated: Bool, completion: (() -> Void)?)

    // Modal presentation
    func present(drawable: Drawable, coordinator: Coordinator, isAnimated: Bool, onDismiss: (() -> Void)?)
    func dismiss(ofType: Coordinator.Type, isAnimated: Bool, completion: (() -> Void)?)
    func dismiss(coordinator: Coordinator, isAnimated: Bool, completion: (() -> Void)?)
    func dismissAllPresented(isAnimated: Bool, completion: (() -> Void)?)

    // Alert
    func showAlert(title: String, message: String, from: Coordinator, animated: Bool, actions: [AlertAction])
}
```

**Key Features:**

**1. Automatic Cleanup:**
Router tự động track lifecycle của ViewControllers và cleanup coordinators khi:
- User swipe back (gesture)
- User tap back button
- Modal dismissed by user

**2. Callback Support:**
- **`onNavigateBack`** (push): Called khi user quay lại từ pushed screen
- **`onDismiss`** (present): Called khi modal dismissed

**3. Context Tracking:**
Router maintain internal dictionary mapping `Coordinator → RouterContext`:
```swift
private struct RouterContext {
    weak var viewController: UIViewController?
    var onNavigateBack: NavigationBackClosure?
    var presentationDelegate: RouterPresentationDelegate?
    var coordinatorType: Coordinator.Type
}
```

### 5. Context Pattern

Context là struct chứa data/configuration cho coordinator:

```swift
struct MHStartupContext {
    let sharedState: MHSharedStateStreaming
    let isFromDeeplink: Bool
}

final class MHStartupCoordinator: BaseRouterContextCoordinator<MHStartupContext> {
    override func start() {
        // Access context.sharedState, context.isFromDeeplink
    }
}
```

**Benefits:**
- **Type-safe data passing:** Compile-time check cho data requirements
- **Clear dependencies:** Dễ thấy coordinator cần data gì
- **Immutable by default:** Context thường là struct → thread-safe

### 6. FlowFactory & AppCoordinator

**FlowFactory Pattern:**
Factory responsible for building major app flows (onboarding, login, home)

```swift
protocol FlowFactory {
    associatedtype Route: FlowRoute
    func make(_ route: Route, parent: Coordinator?) -> AppFlowBuildResult
}

struct AppFlowBuildResult {
    let rootViewController: UIViewController
    let rootCoordinator: Coordinator
    let childCoordinators: [Coordinator] // Pre-initialized children
}
```

**AppFlowFactory Example:**
```swift
enum AppRoute: FlowRoute {
    case onboarding
    case loginInput
    case homeStartup
    case mhStartup(MHStartupContext)
}

func make(_ route: AppRoute, parent: Coordinator?) -> AppFlowBuildResult {
    switch route {
    case .mhStartup(let context):
        let nav = UINavigationController()
        let router = Router(navigationController: nav)

        let startupCoordinator = MHStartupCoordinator(router: router, presentationStyle: .push, context: context)
        let tabbarCoordinator = MHTabbarCoordinator(router: router, tabBarController: MHCustomTabBarController())

        return AppFlowBuildResult(
            rootViewController: nav,
            rootCoordinator: startupCoordinator,
            childCoordinators: [tabbarCoordinator] // Tabbar được init sẵn nhưng chưa start
        )
    }
}
```

**Flow Setup in BaseAppCoordinator:**
```
1. AppCoordinator.navigate(to: .mhStartup)
2. Factory builds: rootVC + rootCoordinator + childCoordinators
3. Setup hierarchy:
   - rootCoordinator.parentCoordinator = AppCoordinator
   - rootCoordinator.children = childCoordinators
   - childCoordinator.parentCoordinator = rootCoordinator
4. Start coordinators:
   - rootCoordinator.start() first
   - childCoordinators.forEach { $0.start() }
5. Set window.rootViewController = rootVC
```

---

## Data Flow & Communication

### 1. Parent-Child Communication

**Upward Communication (Child → Parent): Delegate Pattern**

```swift
protocol MHLoginCoordinatorDelegate: AnyObject {
    func didLoginSuccess()
    func didRequestRegister()
}

final class MHLoginCoordinator: BaseRouterCoordinator {
    weak var delegate: MHLoginCoordinatorDelegate?

    func handleSuccess() {
        delegate?.didLoginSuccess() // Notify parent
    }
}

// Parent implements delegate
extension AppCoordinator: MHLoginCoordinatorDelegate {
    func didLoginSuccess() {
        navigate(to: .home) // Parent decides what to do
    }
}
```

**Downward Communication (Parent → Child): Direct Method Calls**

```swift
final class ParentCoordinator: BaseRouterCoordinator {
    private var childCoordinator: ChildCoordinator?

    func updateChild(with data: Data) {
        childCoordinator?.updateData(data) // Direct call
    }
}
```

### 2. Sibling Communication

**Via Shared State (Reactive):**
```swift
protocol MHSharedStateStreaming {
    var tabbarItems: Observable<[MHTabbarType]> { get }
    var selectedStore: Observable<Store?> { get }
}

// Coordinator A updates shared state
sharedState.selectedStore.accept(newStore)

// Coordinator B observes changes
sharedState.selectedStore
    .subscribeNext { [weak self] store in
        self?.handleStoreChanged(store)
    }
    .disposed(by: disposeBag)
```

**Via Global Delegates (Event Broadcasting):**
```swift
protocol MHCreateStoreGlobalDelegate: AnyObject {
    func didFinishFlowCreateStoreFromHome()
}

// Any coordinator in tree can implement this
extension MHStartupCoordinator: MHCreateStoreGlobalDelegate {
    func didFinishFlowCreateStoreFromHome() {
        // Handle event
    }
}

// Find ancestor implementing protocol
if let handler = findAncestor(ofType: MHCreateStoreGlobalDelegate.self) {
    handler.didFinishFlowCreateStoreFromHome()
}
```

### 3. ViewModel ↔ Coordinator Communication

**ViewModel → Coordinator: Delegate Pattern**

```swift
protocol MHLoginViewModelDelegate: AnyObject {
    func performLogin(with type: MHLoginStrategyType)
    func pushToRegister()
}

final class MHLoginViewModel {
    weak var delegate: MHLoginViewModelDelegate?

    func handleLoginTapped() {
        // ViewModel doesn't know about navigation
        delegate?.performLogin(with: .password(credential))
    }
}

final class MHLoginCoordinator: BaseRouterCoordinator {
    private var viewModel: MHLoginViewModel!

    override func start() {
        viewModel = builder.make(delegate: self)
        // Coordinator handles navigation
    }
}

extension MHLoginCoordinator: MHLoginViewModelDelegate {
    func performLogin(with type: MHLoginStrategyType) {
        strategyFactory.getStrategy(for: type)?.perform(with: type)
    }

    func pushToRegister() {
        let coordinator = MHRegisterCoordinator(router: router)
        coordinator.parentCoordinator = self
        children.append(coordinator)
        coordinator.start()
    }
}
```

**Why ViewModel doesn't hold Coordinator reference:**
- ViewModel should be testable without UI dependencies
- ViewModel focuses on business logic, Coordinator focuses on navigation
- Clearer separation of concerns

### 4. Context Passing

**Immutable Context (Struct):**
```swift
struct DetailContext {
    let productId: String
    let sourceScreen: AnalyticsSource
}

// Pass when creating coordinator
let context = DetailContext(productId: "123", sourceScreen: .home)
let coordinator = DetailCoordinator(router: router, presentationStyle: .push, context: context)
```

**Mutable Shared State (Class with Reactive):**
```swift
final class MHSharedState: MHSharedStateStreaming {
    private let selectedStoreRelay = BehaviorRelay<Store?>(value: nil)
    var selectedStore: Observable<Store?> { selectedStoreRelay.asObservable() }

    func updateStore(_ store: Store) {
        selectedStoreRelay.accept(store)
    }
}

// Multiple coordinators share same instance
let sharedState = MHSharedState()
let coordinator1 = Coordinator1(context: Context(sharedState: sharedState))
let coordinator2 = Coordinator2(context: Context(sharedState: sharedState))
```

---

## Navigation System

### 1. Push Navigation Flow

```
User Action → ViewModel → Coordinator → Router → UIKit

Example:
1. User taps "Detail" button
2. ViewController calls viewModel.handleDetailTapped()
3. ViewModel calls delegate.showDetail(productId: "123")
4. Coordinator creates DetailCoordinator with context
5. Coordinator calls router.push(vc, to: detailCoordinator, onNavigateBack: cleanup)
6. Router pushes VC and registers cleanup callback
7. When user swipes back → Router automatically calls cleanup → childDidFinish
```

**Code Flow:**
```swift
// In Coordinator
func showDetail(productId: String) {
    let context = DetailContext(productId: productId)
    let coordinator = DetailCoordinator(
        router: router,
        presentationStyle: .push,
        context: context
    )
    coordinator.parentCoordinator = self
    children.append(coordinator)
    coordinator.start()
}

// In DetailCoordinator.start()
override func start() {
    let vc = builder.make(context: context, delegate: self)
    perform(vc, from: self) { [weak self] in
        // Cleanup when popped
        guard let self = self else { return }
        self.parentCoordinator?.childDidFinish(self)
    }
}
```

### 2. Modal Presentation Flow

```
Presentation Flow:
1. Create new UINavigationController (modal's own nav stack)
2. Create new Router(navigationController: modalNav)
3. parentRouter = currentRouter (save for dismiss)
4. router = newRouter (replace)
5. Router presents modal
6. Coordinator now uses newRouter for any subsequent pushes inside modal

Dismiss Flow:
1. User dismisses modal (swipe down or button)
2. Router detects dismiss → calls onDismiss callback
3. Coordinator cleanup
4. router automatically restored to parentRouter
```

### 3. Pop/Dismiss Operations

**Pop to Root:**
```swift
router.popToRootCoordinator(isAnimated: true)
// → Pops all VCs except root
// → Cleanup all affected coordinators
```

**Pop to Specific Coordinator:**
```swift
router.popToCoordinator(coordinator: targetCoordinator, isAnimated: true) {
    // Completion after pop
}
// → Pops back to targetCoordinator's VC
// → Cleanup all coordinators between current and target
```

**Dismiss Specific Modal:**
```swift
router.dismiss(ofType: DetailCoordinator.self, isAnimated: true)
// → Find first coordinator of type DetailCoordinator
// → Dismiss its VC
// → Cleanup coordinator
```

**Dismiss All Modals:**
```swift
router.dismissAllPresented(isAnimated: true) {
    // All modals dismissed
}
// → Walk up presentation chain
// → Dismiss all at once from root presenter
// → Cleanup all affected coordinators
```

### 4. Deep Linking

**Deepest Visible Coordinator:**
```swift
var deepestVisibleCoordinator: Coordinator {
    // Logic:
    // 1. If ActiveChildCoordinator (Tabbar) → check if something presented on top
    //    - Yes → recurse into presented coordinator
    //    - No → recurse into activeChildCoordinator
    // 2. If regular coordinator → recurse into last child (skip embedded plugins)
    // 3. Return self if no children
}
```

**Deep Link Flow:**
```swift
// 1. App receives deeplink
// 2. AppCoordinator finds deepest visible router coordinator
let target = deepestVisibleRouterCoordinator

// 3. Build coordinator for deeplink
let deeplinkCoordinator = plugin.buildCoordinator(router: target.router)

// 4. Add as child and start
deeplinkCoordinator.parentCoordinator = target
target.children.append(deeplinkCoordinator)
deeplinkCoordinator.start()

// → Deeplink screen pushed from currently visible screen
```

---

## Advanced Patterns

### 1. Strategy Pattern with Factory

**Problem:** Coordinator có multiple strategies xử lý cùng một action (ví dụ: login có nhiều methods: password, biometric, OTP)

**Solution:** Factory tạo và cache strategy coordinators

**Architecture:**
```
MHLoginCoordinator (orchestrator)
  ├─ MHLoginStrategyFactory (factory)
  │   ├─ MHLoginPasswordStrategyCoordinator (strategy 1)
  │   └─ MHLoginBiometricStrategyCoordinator (strategy 2)
  └─ MHHomePreparationCoordinator (next flow)
```

**Implementation Pattern:**

```swift
// 1. Strategy Type Enum
enum MHLoginStrategyType {
    case password(MHLoginPasswordCredential)
    case biometric

    var cacheKey: String {
        switch self {
        case .password: return "password"
        case .biometric: return "biometric"
        }
    }
}

// 2. Factory Protocol
protocol MHLoginStrategyFactory {
    func configure(router: RouterProtocol, parentCoordinator: BaseRouterCoordinator?,
                   viewModelDelegate: MHLoginStrategyDelegate, addChild: @escaping (Coordinator) -> Void)
    func preloadStrategies(_ types: [MHLoginStrategyType])
    func getStrategy(for type: MHLoginStrategyType) -> MHLoginStrategyProtocol?
}

// 3. Factory Implementation
final class DefaultMHLoginStrategyFactory: MHLoginStrategyFactory {
    private var cachedStrategies: [String: MHLoginStrategyProtocol] = [:]
    private weak var router: RouterProtocol?
    private weak var parentCoordinator: BaseRouterCoordinator?

    func getStrategy(for type: MHLoginStrategyType) -> MHLoginStrategyProtocol? {
        let key = type.cacheKey
        if let cached = cachedStrategies[key] { return cached }

        // Create strategy coordinator
        let strategy = createStrategy(for: type, router: router, parentCoordinator: parentCoordinator)
        cachedStrategies[key] = strategy
        return strategy
    }
}

// 4. Usage in Coordinator
final class MHLoginCoordinator: BaseRouterCoordinator {
    @Injected var strategyFactory: MHLoginStrategyFactory

    override func start() {
        configureStrategyFactory()
    }

    private func configureStrategyFactory() {
        strategyFactory.configure(
            router: router,
            parentCoordinator: self,
            viewModelDelegate: viewModel,
            addChild: { [weak self] coordinator in
                self?.children.append(coordinator)
            }
        )
        strategyFactory.preloadStrategies([.biometric]) // Preload if needed
    }
}

extension MHLoginCoordinator: MHLoginViewModelDelegate {
    func performLogin(with type: MHLoginStrategyType) {
        strategyFactory.getStrategy(for: type)?.perform(with: type)
    }
}
```

**Key Benefits:**
- **Separation of concerns:** Main coordinator không handle strategy logic
- **Lazy creation:** Strategy coordinators chỉ tạo khi cần
- **Caching:** Reuse coordinators thay vì recreate
- **Testability:** Mock factory để test different strategies
- **Presentation style `.none`:** Strategy coordinators embedded, share parent's router

**When to Use:**
- Có nhiều cách xử lý cùng một action
- Strategies phức tạp, có own ViewModel và business logic
- Muốn giảm gánh nặng cho main coordinator

### 2. Popup Flow Coordinator

**Problem:** Cần show multiple popups theo thứ tự (queue), mỗi popup phải dismiss trước khi show popup tiếp theo

**Solution:** MHPopupFlowCoordinator manages sequential popup queue

**Architecture:**
```
MHStartupCoordinator
  └─ MHPopupFlowCoordinator (queue manager)
      ├─ [Item 1: Notification Permission] → System popup
      ├─ [Item 2: Create Store] → Coordinator popup
      └─ [Item 3: Biometric Prompt] → Coordinator popup
```

**Flow:**
```
1. Add popups to queue with priority
2. Start queue processing
3. Show first popup → wait for dismiss
4. On dismiss → notifyClosed() → show next popup
5. Repeat until queue empty → popupFlowFinished()
```

**Implementation:**
```swift
final class MHPopupFlowCoordinator<Item: PopupItem, Delegate: MHPopupFlowCoordinatorDelegate> {
    private var queue: [Item] = []
    private var currentPopup: Item?

    func addPopup(_ popup: Item) {
        queue.append(popup)
        queue.sort { $0.priority < $1.priority } // Sort by priority
    }

    func start() {
        processNext()
    }

    func notifyClosed() {
        // Remove current popup
        currentPopup = nil
        processNext()
    }

    private func processNext() {
        guard let next = queue.first else {
            delegate?.popupFlowFinished()
            return
        }

        currentPopup = next
        // Show popup and pass onDismiss callback
        currentCoordinator = delegate?.showPopup(next) { [weak self] in
            self?.notifyClosed()
        }
    }
}
```

**Delegate Wiring:**
```swift
extension MHStartupCoordinator: MHPopupFlowCoordinatorDelegate {
    func showPopup(_ item: MHStartupPopupItem, onDismiss: @escaping () -> Void) -> Coordinator? {
        switch item {
        case .requestNotification:
            // System popup - no coordinator
            requestNotificationAuthorization()
            return nil

        case .createStore(let type):
            // Coordinator popup
            return popupFactory.showActionPrompt(.init(type: type), onDismiss: onDismiss)
        }
    }

    func popupClosed(_ item: MHStartupPopupItem) {
        // Analytics or cleanup
    }

    func popupFlowFinished() {
        // All popups completed → finish startup flow
    }
}
```

**Key Benefits:**
- **Sequential execution:** Popups show one at a time
- **Priority support:** Sort queue by priority
- **Flexible popup types:** System popups (no coordinator) or custom popups (with coordinator)
- **Clean separation:** Popup logic tách ra khỏi main coordinator

### 3. Popup Factory Pattern

**Problem:** Coordinator có nhiều popup types cần show, mỗi popup có setup logic phức tạp và delegates

**Solution:** Factory encapsulates popup creation và delegate handling

**Before Refactoring (Code in Coordinator):**
```swift
final class MHStartupCoordinator {
    private weak var actionPromptCoordinator: MHActionPromptBottomSheetCoordinator?

    // ~100 lines popup creation code
    // Multiple delegate implementations
    // Hard to test
}
```

**After Refactoring (Using Factory):**
```swift
final class MHStartupCoordinator {
    @Injected var popupFactory: MHStartupPopupFactory

    override func start() {
        configurePopupFactory()
    }

    private func configurePopupFactory() {
        popupFactory.configure(
            router: router,
            parentCoordinator: self,
            delegate: self,
            addChild: { [weak self] coordinator in
                self?.children.append(coordinator)
            }
        )
    }
}

extension MHStartupCoordinator: MHPopupFlowCoordinatorDelegate {
    func showPopup(_ item: MHStartupPopupItem, onDismiss: @escaping () -> Void) -> Coordinator? {
        switch item {
        case .createStore(let type):
            return popupFactory.showActionPrompt(.init(type: type), onDismiss: onDismiss)
        case .suggestBiometric:
            return popupFactory.showInfoAction(.init(infoType: .biometric), onDismiss: onDismiss)
        }
    }
}
```

**Factory Implementation:**
```swift
final class DefaultMHStartupPopupFactory: MHStartupPopupFactory {
    private weak var router: RouterProtocol?
    private weak var delegate: MHStartupPopupFactoryDelegate?
    private var addChild: ((Coordinator) -> Void)?

    private weak var actionPromptCoordinator: MHActionPromptBottomSheetCoordinator?

    func showActionPrompt(_ context: MHActionPromptBottomSheetContext, onDismiss: @escaping () -> Void) -> Coordinator? {
        let coordinator = MHActionPromptBottomSheetCoordinator(router: router, presentationStyle: .panModel, context: context)
        coordinator.onMHPopupDismiss = onDismiss
        coordinator.parentCoordinator = parentCoordinator
        coordinator.delegate = self
        addChild?(coordinator)
        coordinator.start()
        actionPromptCoordinator = coordinator
        return coordinator
    }

    func dismissActionPrompt() {
        router?.dismiss(ofType: MHActionPromptBottomSheetCoordinator.self, isAnimated: true) {
            self.delegate?.reloadMasterData()
        }
    }
}

// Factory implements popup delegates
extension DefaultMHStartupPopupFactory: MHActionPromptBottomSheetCoordinatorDelegate {
    func handleAction(_ type: MHActionPromptItemType, action: MHActionPromptActionType) {
        // Handle popup actions
        delegate?.purchaseSubscription()
    }
}
```

**Key Benefits:**
- **Reduced coordinator complexity:** ~100 lines code moved to factory
- **Reusability:** Factory có thể reuse ở nhiều coordinators
- **Testability:** Test popup logic độc lập
- **Single Responsibility:** Factory chỉ handle popup, coordinator handle main flow

### 4. Plugin Coordinators (Embedded Components)

**Problem:** Màn hình composite có nhiều sub-components (header, banner, report sections), mỗi component có own logic và ViewModel

**Solution:** Plugin coordinators with `.none` presentation style, share parent's router

**Architecture:**
```
MHHomeCoordinator [push, router: R1]
  ├─ MHHomeHeaderPluginCoordinator [none, router: R1] ← Embedded
  ├─ MHHomeBannerPluginCoordinator [none, router: R1] ← Embedded
  ├─ MHHomeReportPluginCoordinator [none, router: R1] ← Embedded
  └─ DetailCoordinator [push, router: R1] ← Navigation destination
```

**Plugin Protocol:**
```swift
protocol MHHomePluginCoordinator: BaseRouterContextCoordinator<MHHomePluginStreaming> {
    var pluginId: MHHomePluginIdentifier { get }
    var pluginViewController: UIViewController? { get }
    var pluginDelegate: MHHomePluginDelegate? { get set }
}
```

**Plugin Implementation:**
```swift
final class MHHomeHeaderPluginCoordinator: MHHomePluginCoordinator {
    var pluginId: MHHomePluginIdentifier { .header }
    var pluginViewController: UIViewController? { viewController }

    private var viewController: MHHomeHeaderPluginViewController!

    override func start() {
        // Build ViewModel + ViewController
        // NO perform() call - không present UI
        let result = builder.make(delegate: self)
        self.viewController = result.vc
    }
}
```

**Parent Coordinator Usage:**
```swift
final class MHHomeCoordinator: BaseRouterCoordinator {
    private var pluginCoordinators: [MHHomePluginCoordinator] = []

    override func start() {
        setupPlugins()

        let vc = builder.make(
            pluginViewControllers: pluginCoordinators.compactMap { $0.pluginViewController }
        )
        perform(vc, from: self)
    }

    private func setupPlugins() {
        let plugins: [MHHomePluginCoordinator] = [
            MHHomeHeaderPluginCoordinator(router: router, presentationStyle: .none, context: context),
            MHHomeBannerPluginCoordinator(router: router, presentationStyle: .none, context: context),
            MHHomeReportPluginCoordinator(router: router, presentationStyle: .none, context: context)
        ]

        plugins.forEach { plugin in
            plugin.parentCoordinator = self
            plugin.pluginDelegate = self
            children.append(plugin)
            plugin.start()
        }

        pluginCoordinators = plugins
    }
}
```

**Key Characteristics:**
- **`.none` presentation:** No navigation action
- **Shared router:** Use parent's router (same instance)
- **Embedded UI:** VCs embedded trong parent VC's view hierarchy
- **Independent logic:** Mỗi plugin có own ViewModel và business logic
- **Skipped in deeplink traversal:** `deepestVisibleCoordinator` bỏ qua plugins

**When to Use:**
- Screen có nhiều independent sub-components
- Mỗi component có complex logic đáng để tách ra coordinator riêng
- Muốn reuse components ở nhiều screens

### 5. ActiveChildCoordinator (Container Coordinators)

**Problem:** Container coordinators (Tabbar, Segment, PageView) có nhiều children nhưng chỉ 1 child visible tại một thời điểm

**Solution:** ActiveChildCoordinator protocol để identify visible child

**Protocol:**
```swift
protocol ActiveChildCoordinator: Coordinator {
    var activeChildCoordinator: Coordinator? { get }
}
```

**Tabbar Implementation:**
```swift
final class MHTabbarCoordinator: BaseRouterCoordinator, ActiveChildCoordinator {
    private let tabBarController: UITabBarController

    var activeChildCoordinator: Coordinator? {
        let index = tabBarController.selectedIndex
        return children[safe: index]
    }

    override func start() {
        setupTabs()
        perform(tabBarController, from: self)
    }

    private func setupTabs() {
        for tab in MHTabbarType.allCases {
            let (coordinator, viewController) = makeTab(for: tab)
            children.append(coordinator)
        }
    }

    private func makeTab(for tab: MHTabbarType) -> (Coordinator, UIViewController) {
        // Create new nav controller and router for each tab
        let navigationController = UINavigationController()
        let router = Router(navigationController: navigationController)

        let coordinator = tab.makeCoordinator(router: router)
        coordinator.parentCoordinator = self
        coordinator.start()

        return (coordinator, navigationController)
    }
}
```

**Deep Link with ActiveChildCoordinator:**
```
User on Tab 2 → deepestVisibleCoordinator logic:

1. Start at MHTabbarCoordinator
2. Is ActiveChildCoordinator? Yes
3. Check if something presented on top? No
4. Return activeChildCoordinator (Tab 2's coordinator)
5. Recurse into Tab 2's children
6. Return deepest coordinator in Tab 2's stack

→ Deeplink pushes from Tab 2, not Tab 1
```

**Key Benefits:**
- **Correct deep linking:** Always push from visible tab/segment
- **Multiple independent flows:** Mỗi tab có own navigation stack
- **Preserved state:** Switch tabs không reset state

---

## Memory Management

### 1. Weak References

**Critical weak references:**
- **`parentCoordinator`:** Weak để tránh retain cycle (parent owns child)
- **`delegate`:** Weak để tránh retain cycle (owner-delegate pattern)
- **Factory dependencies:** Weak router, weak parentCoordinator trong factories

**Strong references:**
- **`children`:** Strong array để keep children alive
- **`router`:** Strong để coordinator own router instance (modal case)

### 2. Cleanup Flow

**Push Navigation Cleanup:**
```
User swipes back
  ↓
Router detects VC.didMove(toParent: nil)
  ↓
Router calls onNavigateBack closure
  ↓
Closure calls parentCoordinator?.childDidFinish(self)
  ↓
Parent removes child from children array
  ↓
Child coordinator deallocated (no strong references left)
```

**Modal Dismiss Cleanup:**
```
User dismisses modal
  ↓
Router's presentation delegate detects dismiss
  ↓
Router calls onDismiss closure
  ↓
Closure calls parentCoordinator?.childDidFinish(self)
  ↓
Parent removes child from children array
  ↓
Child coordinator + modal nav controller deallocated
```

### 3. Router Context Tracking

Router maintain internal dictionary tracking each coordinator:
```swift
private var coordinatorContexts: [ObjectIdentifier: RouterContext] = [:]

// On push/present
coordinatorContexts[ObjectIdentifier(coordinator)] = RouterContext(
    viewController: vc,
    onNavigateBack: callback,
    coordinatorType: type(of: coordinator)
)

// On cleanup
coordinatorContexts.removeValue(forKey: ObjectIdentifier(coordinator))
```

**Why ObjectIdentifier:**
- Unique identifier cho coordinator instance
- Lightweight (just a pointer)
- Works với weak references

### 4. Common Memory Issues

**Issue 1: Retain Cycle in Closures**
```swift
// ❌ Bad - retains self
coordinator.start()
router.push(vc, to: coordinator, onNavigateBack: {
    self.handleBack() // Captures self strongly
})

// ✅ Good - weak self
router.push(vc, to: coordinator, onNavigateBack: { [weak self] in
    self?.handleBack()
})
```

**Issue 2: Strong Delegate**
```swift
// ❌ Bad
var delegate: SomeDelegate? // Strong reference

// ✅ Good
weak var delegate: SomeDelegate?
```

**Issue 3: Forgot to Remove Child**
```swift
// ❌ Bad - child never removed
func dismiss() {
    router.dismiss(coordinator: childCoordinator)
    // Missing: children.removeAll { $0 === childCoordinator }
}

// ✅ Good - let router cleanup handle it
router.push(vc, to: coordinator, onNavigateBack: { [weak self] in
    self?.parentCoordinator?.childDidFinish(self)
})
```

---

## Best Practices

### 1. Separation of Concerns

**✅ Do:**
- **Coordinator:** Navigation, flow control, coordinator lifecycle
- **ViewModel:** Business logic, API calls, data transformation
- **ViewController:** UI rendering, user interactions

**❌ Don't:**
- ViewController biết về navigation logic
- ViewModel biết về UIKit hoặc navigation
- Coordinator chứa business logic

### 2. When to Use Factories

**Use Factory Pattern when:**
- ✅ Có nhiều strategies/variants của cùng một flow
- ✅ Creation logic phức tạp (nhiều delegates, configurations)
- ✅ Muốn reuse logic ở nhiều nơi
- ✅ Cần lazy initialization và caching

**Don't Use Factory when:**
- ❌ Chỉ có 1 simple coordinator creation
- ❌ Logic quá đơn giản, factory làm phức tạp thêm
- ❌ Coordinator chỉ dùng 1 lần, không reuse

### 3. Delegate vs Closures

**Use Delegate when:**
- ✅ Có nhiều methods cần communicate (>2-3 methods)
- ✅ Long-lived relationship (coordinator lifetime)
- ✅ Muốn type-safe protocol

**Use Closures when:**
- ✅ Single event (onDismiss, onComplete)
- ✅ Short-lived callback
- ✅ Simple notification

### 4. Common Pitfalls

**❌ Pitfall 1: Forgot [weak self] in closures**
```swift
// Creates retain cycle
router.push(vc, to: coordinator, onNavigateBack: {
    self.cleanup()
})
```

**❌ Pitfall 2: Strong delegate reference**
```swift
var delegate: CoordinatorDelegate? // Should be weak
```

**❌ Pitfall 3: Not removing child coordinators**
```swift
// Child never deallocated
func showDetail() {
    let coordinator = DetailCoordinator(...)
    children.append(coordinator)
    coordinator.start()
    // Missing: cleanup logic
}
```

**❌ Pitfall 4: Creating circular dependencies**
```swift
// Parent → Child → Parent (retain cycle)
coordinator.delegate = self // Delegate must be weak
```

**❌ Pitfall 5: Using wrong router**
```swift
// In strategy/factory coordinators với .none presentation
func navigate() {
    router.push(...) // ❌ Wrong - uses child's router
    parentRouter.push(...) // ✅ Correct - uses parent's router
}
```

### 5. Testing Coordinators

**Mock Dependencies:**
```swift
final class MockRouter: RouterProtocol {
    var pushCalled = false
    var pushedViewController: UIViewController?

    func push(drawable: Drawable, to: Coordinator, isAnimated: Bool, onNavigateBack: (() -> Void)?) {
        pushCalled = true
        pushedViewController = drawable.viewController
    }
}

// Test
func testShowDetail() {
    let mockRouter = MockRouter()
    let coordinator = MyCoordinator(router: mockRouter)

    coordinator.showDetail()

    XCTAssertTrue(mockRouter.pushCalled)
    XCTAssertTrue(mockRouter.pushedViewController is DetailViewController)
}
```

---

## Summary

**Coordinator Architecture trong project này provides:**

✅ **Clear separation of concerns:** Navigation tách khỏi business logic và UI
✅ **Flexible navigation:** Support push, modal, bottom sheet, deep linking
✅ **Reusable patterns:** Factory, Strategy, Plugin patterns cho code reusability
✅ **Type-safe communication:** Protocols cho coordinator communication
✅ **Automatic memory management:** Router tự động cleanup coordinators
✅ **Testability:** Dễ mock và test navigation flows
✅ **Scalability:** Dễ add new flows và screens

**Key Takeaways:**
- Coordinator handles navigation, ViewModel handles logic
- Use factories để tách complex creation logic
- Always use weak references cho delegates và parent
- Let router handle cleanup automatically
- Plugins cho embedded components, Strategies cho variants
- ActiveChildCoordinator cho containers (Tabbar, Segment)

---

**Document Version:** 1.0
**Last Updated:** 2026-02-12
**Maintained By:** iOS Team
