# LCoordinator - iOS Navigation & Coordination SDK

A clean, powerful Coordinator + Router + Deeplink SDK for iOS apps with support for push/present/panModal navigation flows.

## Table of Contents
1. [Overview](#overview)
2. [Installation](#installation)
3. [Core Components](#core-components)
4. [Data Flow & Communication](#data-flow--communication)
5. [Navigation System](#navigation-system)
6. [Advanced Patterns](#advanced-patterns)
7. [Memory Management](#memory-management)
8. [Best Practices](#best-practices)

---

## Overview

### What is the Coordinator Pattern?

The Coordinator pattern is an architectural pattern that separates navigation logic from ViewControllers. In this SDK, Coordinators manage the flow between screens, control the lifecycle of ViewControllers, and handle communication between modules.

### Why Use Coordinators?

**Problems Solved:**
- **ViewControllers don't need to know about navigation** → Reusable & Testable
- **Centralized navigation logic** → Easy to maintain & debug
- **Clear separation of concerns** → ViewModels handle business logic, Coordinators handle navigation
- **Better deep linking support** → Navigate from anywhere in the app
- **Improved testability** → Mock coordinators to test flows

---

## Installation

### CocoaPods

```ruby
pod 'LCoordinator'
```

Then run:
```bash
pod install
```

### Requirements
- iOS 14.0+
- Swift 5.9+

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
- **Parent-Child Hierarchy:** Each coordinator can have a parent and multiple children, forming a tree structure
- **`start()`:** Entry point to start the coordinator's flow
- **`childDidFinish()`:** Cleanup method called when a child coordinator finishes and needs to be removed

**Example Hierarchy:**
```
AppCoordinator (root)
  ├─ StartupCoordinator
  │   └─ PopupFlowCoordinator
  └─ TabbarCoordinator
      ├─ HomeCoordinator
      │   ├─ HomeHeaderPluginCoordinator [embedded]
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
- **`.push`** → Push onto navigation stack
- **`.present(UIModalPresentationStyle)`** → Present as modal with style (fullScreen, pageSheet, etc.)
- **`.panModel`** → Present as bottom sheet using PanModal
- **`.none`** → No presentation (for embedded coordinators like plugins)

**Router vs ParentRouter:**
- **`router`:** Current router of the coordinator (can change when presenting modals)
- **`parentRouter`:** Stores the original router, used to dismiss/pop back to parent

**Modal Presentation Flow:**
```
1. Before present: router === parentRouter (same instance)
2. Create new NavigationController for modal
3. Create new Router for modal's navigation stack
4. parentRouter = router (save current)
5. router = newRouter (replace with modal router)
6. On dismiss: router restored to parentRouter
```

### 3. Base Coordinator Hierarchy

The SDK provides multiple base classes for different use cases:

```
BaseCoordinator
  ├─ BaseContextCoordinator<Context>
  └─ BaseRouterCoordinator
       └─ BaseRouterContextCoordinator<Context>

BaseAppCoordinator<Factory: FlowFactory>
```

**BaseCoordinator:**
- Simplest form, implements only the Coordinator protocol
- Use case: Non-router coordinators (orchestrate flow without presenting UI)

**BaseRouterCoordinator:**
- Coordinator with a router for navigation
- Use case: Most coordinators that present UI (push/modal)

**BaseContextCoordinator<Context>:**
- Coordinator that receives context during initialization
- Context contains necessary data for the flow
- Use case: Coordinators that need external data (user info, configuration, etc.)

**BaseRouterContextCoordinator<Context>:**
- Combines both Router and Context
- Use case: Most common - coordinator needs both navigation and data

**BaseAppCoordinator<Factory>:**
- Root coordinator of the app
- Manages app-level flows through FlowFactory
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
Router automatically tracks the lifecycle of ViewControllers and cleans up coordinators when:
- User swipes back (gesture)
- User taps back button
- Modal is dismissed by user

**2. Callback Support:**
- **`onNavigateBack`** (push): Called when user returns from a pushed screen
- **`onDismiss`** (present): Called when a modal is dismissed

**3. Context Tracking:**
Router maintains an internal dictionary mapping `Coordinator → RouterContext`:
```swift
private struct RouterContext {
    weak var viewController: UIViewController?
    var onNavigateBack: NavigationBackClosure?
    var presentationDelegate: RouterPresentationDelegate?
    var coordinatorType: Coordinator.Type
}
```

### 5. Context Pattern

Context is a struct that holds data/configuration for a coordinator:

```swift
struct StartupContext {
    let sharedState: SharedStateStreaming
    let isFromDeeplink: Bool
}

final class StartupCoordinator: BaseRouterContextCoordinator<StartupContext> {
    override func start() {
        // Access context.sharedState, context.isFromDeeplink
    }
}
```

**Benefits:**
- **Type-safe data passing:** Compile-time checks for data requirements
- **Clear dependencies:** Easy to see what data a coordinator needs
- **Immutable by default:** Structs are thread-safe by design

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
    case startup(StartupContext)
}

func make(_ route: AppRoute, parent: Coordinator?) -> AppFlowBuildResult {
    switch route {
    case .startup(let context):
        let nav = UINavigationController()
        let router = Router(navigationController: nav)

        let startupCoordinator = StartupCoordinator(router: router, presentationStyle: .push, context: context)
        let tabbarCoordinator = TabbarCoordinator(router: router, tabBarController: CustomTabBarController())

        return AppFlowBuildResult(
            rootViewController: nav,
            rootCoordinator: startupCoordinator,
            childCoordinators: [tabbarCoordinator]
        )
    }
}
```

**Flow Setup in BaseAppCoordinator:**
```
1. AppCoordinator.navigate(to: .startup)
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
protocol LoginCoordinatorDelegate: AnyObject {
    func didLoginSuccess()
    func didRequestRegister()
}

final class LoginCoordinator: BaseRouterCoordinator {
    weak var delegate: LoginCoordinatorDelegate?

    func handleSuccess() {
        delegate?.didLoginSuccess() // Notify parent
    }
}

// Parent implements delegate
extension AppCoordinator: LoginCoordinatorDelegate {
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
protocol SharedStateStreaming {
    var tabbarItems: Observable<[TabbarType]> { get }
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
protocol CreateStoreGlobalDelegate: AnyObject {
    func didFinishFlowCreateStoreFromHome()
}

// Any coordinator in tree can implement this
extension StartupCoordinator: CreateStoreGlobalDelegate {
    func didFinishFlowCreateStoreFromHome() {
        // Handle event
    }
}

// Find ancestor implementing protocol
if let handler = findAncestor(ofType: CreateStoreGlobalDelegate.self) {
    handler.didFinishFlowCreateStoreFromHome()
}
```

### 3. ViewModel ↔ Coordinator Communication

**ViewModel → Coordinator: Delegate Pattern**

```swift
protocol LoginViewModelDelegate: AnyObject {
    func performLogin(with type: LoginStrategyType)
    func pushToRegister()
}

final class LoginViewModel {
    weak var delegate: LoginViewModelDelegate?

    func handleLoginTapped() {
        // ViewModel doesn't know about navigation
        delegate?.performLogin(with: .password(credential))
    }
}

final class LoginCoordinator: BaseRouterCoordinator {
    private var viewModel: LoginViewModel!

    override func start() {
        viewModel = builder.make(delegate: self)
        // Coordinator handles navigation
    }
}

extension LoginCoordinator: LoginViewModelDelegate {
    func performLogin(with type: LoginStrategyType) {
        strategyFactory.getStrategy(for: type)?.perform(with: type)
    }

    func pushToRegister() {
        let coordinator = RegisterCoordinator(router: router)
        coordinator.parentCoordinator = self
        children.append(coordinator)
        coordinator.start()
    }
}
```

**Why ViewModel doesn't hold Coordinator reference:**
- ViewModels should be testable without UI dependencies
- ViewModels focus on business logic, Coordinators focus on navigation
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
final class SharedState: SharedStateStreaming {
    private let selectedStoreRelay = BehaviorRelay<Store?>(value: nil)
    var selectedStore: Observable<Store?> { selectedStoreRelay.asObservable() }

    func updateStore(_ store: Store) {
        selectedStoreRelay.accept(store)
    }
}

// Multiple coordinators share same instance
let sharedState = SharedState()
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

**Problem:** Coordinator has multiple strategies for handling the same action (e.g., login with multiple methods: password, biometric, OTP)

**Solution:** Factory creates and caches strategy coordinators

**Architecture:**
```
LoginCoordinator (orchestrator)
  ├─ LoginStrategyFactory (factory)
  │   ├─ LoginPasswordStrategyCoordinator (strategy 1)
  │   └─ LoginBiometricStrategyCoordinator (strategy 2)
  └─ HomePreparationCoordinator (next flow)
```

**Implementation Pattern:**

```swift
// 1. Strategy Type Enum
enum LoginStrategyType {
    case password(LoginPasswordCredential)
    case biometric

    var cacheKey: String {
        switch self {
        case .password: return "password"
        case .biometric: return "biometric"
        }
    }
}

// 2. Factory Protocol
protocol LoginStrategyFactory {
    func configure(router: RouterProtocol, parentCoordinator: BaseRouterCoordinator?,
                   viewModelDelegate: LoginStrategyDelegate, addChild: @escaping (Coordinator) -> Void)
    func preloadStrategies(_ types: [LoginStrategyType])
    func getStrategy(for type: LoginStrategyType) -> LoginStrategyProtocol?
}

// 3. Factory Implementation
final class DefaultLoginStrategyFactory: LoginStrategyFactory {
    private var cachedStrategies: [String: LoginStrategyProtocol] = [:]
    private weak var router: RouterProtocol?
    private weak var parentCoordinator: BaseRouterCoordinator?

    func getStrategy(for type: LoginStrategyType) -> LoginStrategyProtocol? {
        let key = type.cacheKey
        if let cached = cachedStrategies[key] { return cached }

        // Create strategy coordinator
        let strategy = createStrategy(for: type, router: router, parentCoordinator: parentCoordinator)
        cachedStrategies[key] = strategy
        return strategy
    }
}

// 4. Usage in Coordinator
final class LoginCoordinator: BaseRouterCoordinator {
    @Injected var strategyFactory: LoginStrategyFactory

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

extension LoginCoordinator: LoginViewModelDelegate {
    func performLogin(with type: LoginStrategyType) {
        strategyFactory.getStrategy(for: type)?.perform(with: type)
    }
}
```

**Key Benefits:**
- **Separation of concerns:** Main coordinator doesn't handle strategy logic
- **Lazy creation:** Strategy coordinators only created when needed
- **Caching:** Reuse coordinators instead of recreating
- **Testability:** Mock factory to test different strategies
- **Presentation style `.none`:** Strategy coordinators are embedded, share parent's router

**When to Use:**
- Multiple ways to handle the same action
- Strategies are complex with own ViewModel and business logic
- Want to reduce main coordinator's responsibility

### 2. Popup Flow Coordinator

**Problem:** Need to show multiple popups in sequence, each popup must be dismissed before showing the next one

**Solution:** PopupFlowCoordinator manages sequential popup queue

**Architecture:**
```
StartupCoordinator
  └─ PopupFlowCoordinator (queue manager)
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
final class PopupFlowCoordinator<Item: PopupItem, Delegate: PopupFlowCoordinatorDelegate> {
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
extension StartupCoordinator: PopupFlowCoordinatorDelegate {
    func showPopup(_ item: StartupPopupItem, onDismiss: @escaping () -> Void) -> Coordinator? {
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

    func popupClosed(_ item: StartupPopupItem) {
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
- **Clean separation:** Popup logic separated from main coordinator

### 3. Popup Factory Pattern

**Problem:** Coordinator has multiple popup types to show, each popup has complex setup logic and delegates

**Solution:** Factory encapsulates popup creation and delegate handling

**Before Refactoring (Code in Coordinator):**
```swift
final class StartupCoordinator {
    private weak var actionPromptCoordinator: ActionPromptBottomSheetCoordinator?

    // ~100 lines popup creation code
    // Multiple delegate implementations
    // Hard to test
}
```

**After Refactoring (Using Factory):**
```swift
final class StartupCoordinator {
    @Injected var popupFactory: StartupPopupFactory

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

extension StartupCoordinator: PopupFlowCoordinatorDelegate {
    func showPopup(_ item: StartupPopupItem, onDismiss: @escaping () -> Void) -> Coordinator? {
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
final class DefaultStartupPopupFactory: StartupPopupFactory {
    private weak var router: RouterProtocol?
    private weak var delegate: StartupPopupFactoryDelegate?
    private var addChild: ((Coordinator) -> Void)?

    private weak var actionPromptCoordinator: ActionPromptBottomSheetCoordinator?

    func showActionPrompt(_ context: ActionPromptBottomSheetContext, onDismiss: @escaping () -> Void) -> Coordinator? {
        let coordinator = ActionPromptBottomSheetCoordinator(router: router, presentationStyle: .panModel, context: context)
        coordinator.onPopupDismiss = onDismiss
        coordinator.parentCoordinator = parentCoordinator
        coordinator.delegate = self
        addChild?(coordinator)
        coordinator.start()
        actionPromptCoordinator = coordinator
        return coordinator
    }

    func dismissActionPrompt() {
        router?.dismiss(ofType: ActionPromptBottomSheetCoordinator.self, isAnimated: true) {
            self.delegate?.reloadMasterData()
        }
    }
}

// Factory implements popup delegates
extension DefaultStartupPopupFactory: ActionPromptBottomSheetCoordinatorDelegate {
    func handleAction(_ type: ActionPromptItemType, action: ActionPromptActionType) {
        // Handle popup actions
        delegate?.purchaseSubscription()
    }
}
```

**Key Benefits:**
- **Reduced coordinator complexity:** ~100 lines code moved to factory
- **Reusability:** Factory can be reused across multiple coordinators
- **Testability:** Test popup logic independently
- **Single Responsibility:** Factory handles popups, coordinator handles main flow

### 4. Plugin Coordinators (Embedded Components)

**Problem:** Composite screens have multiple sub-components (header, banner, report sections), each with its own logic and ViewModel

**Solution:** Plugin coordinators with `.none` presentation style, share parent's router

**Architecture:**
```
HomeCoordinator [push, router: R1]
  ├─ HomeHeaderPluginCoordinator [none, router: R1] ← Embedded
  ├─ HomeBannerPluginCoordinator [none, router: R1] ← Embedded
  ├─ HomeReportPluginCoordinator [none, router: R1] ← Embedded
  └─ DetailCoordinator [push, router: R1] ← Navigation destination
```

**Plugin Protocol:**
```swift
protocol HomePluginCoordinator: BaseRouterContextCoordinator<HomePluginStreaming> {
    var pluginId: HomePluginIdentifier { get }
    var pluginViewController: UIViewController? { get }
    var pluginDelegate: HomePluginDelegate? { get set }
}
```

**Plugin Implementation:**
```swift
final class HomeHeaderPluginCoordinator: HomePluginCoordinator {
    var pluginId: HomePluginIdentifier { .header }
    var pluginViewController: UIViewController? { viewController }

    private var viewController: HomeHeaderPluginViewController!

    override func start() {
        // Build ViewModel + ViewController
        // NO perform() call - doesn't present UI
        let result = builder.make(delegate: self)
        self.viewController = result.vc
    }
}
```

**Parent Coordinator Usage:**
```swift
final class HomeCoordinator: BaseRouterCoordinator {
    private var pluginCoordinators: [HomePluginCoordinator] = []

    override func start() {
        setupPlugins()

        let vc = builder.make(
            pluginViewControllers: pluginCoordinators.compactMap { $0.pluginViewController }
        )
        perform(vc, from: self)
    }

    private func setupPlugins() {
        let plugins: [HomePluginCoordinator] = [
            HomeHeaderPluginCoordinator(router: router, presentationStyle: .none, context: context),
            HomeBannerPluginCoordinator(router: router, presentationStyle: .none, context: context),
            HomeReportPluginCoordinator(router: router, presentationStyle: .none, context: context)
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
- **Embedded UI:** ViewControllers embedded in parent VC's view hierarchy
- **Independent logic:** Each plugin has its own ViewModel and business logic
- **Skipped in deeplink traversal:** `deepestVisibleCoordinator` skips plugins

**When to Use:**
- Screen has multiple independent sub-components
- Each component has complex logic worth separating into its own coordinator
- Want to reuse components across multiple screens

### 5. ActiveChildCoordinator (Container Coordinators)

**Problem:** Container coordinators (Tabbar, Segment, PageView) have multiple children but only 1 child is visible at a time

**Solution:** ActiveChildCoordinator protocol to identify the visible child

**Protocol:**
```swift
protocol ActiveChildCoordinator: Coordinator {
    var activeChildCoordinator: Coordinator? { get }
}
```

**Tabbar Implementation:**
```swift
final class TabbarCoordinator: BaseRouterCoordinator, ActiveChildCoordinator {
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
        for tab in TabbarType.allCases {
            let (coordinator, viewController) = makeTab(for: tab)
            children.append(coordinator)
        }
    }

    private func makeTab(for tab: TabbarType) -> (Coordinator, UIViewController) {
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

1. Start at TabbarCoordinator
2. Is ActiveChildCoordinator? Yes
3. Check if something presented on top? No
4. Return activeChildCoordinator (Tab 2's coordinator)
5. Recurse into Tab 2's children
6. Return deepest coordinator in Tab 2's stack

→ Deeplink pushes from Tab 2, not Tab 1
```

**Key Benefits:**
- **Correct deep linking:** Always push from visible tab/segment
- **Multiple independent flows:** Each tab has its own navigation stack
- **Preserved state:** Switching tabs doesn't reset state

---

## Memory Management

### 1. Weak References

**Critical weak references:**
- **`parentCoordinator`:** Weak to prevent retain cycle (parent owns child)
- **`delegate`:** Weak to prevent retain cycle (owner-delegate pattern)
- **Factory dependencies:** Weak router, weak parentCoordinator in factories

**Strong references:**
- **`children`:** Strong array to keep children alive
- **`router`:** Strong to give coordinator ownership of router instance (modal case)

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

Router maintains an internal dictionary tracking each coordinator:
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
- Unique identifier for each coordinator instance
- Lightweight (just a pointer)
- Works with weak references

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
- ViewControllers knowing about navigation logic
- ViewModels knowing about UIKit or navigation
- Coordinators containing business logic

### 2. When to Use Factories

**Use Factory Pattern when:**
- ✅ Multiple strategies/variants of the same flow
- ✅ Complex creation logic (many delegates, configurations)
- ✅ Want to reuse logic in multiple places
- ✅ Need lazy initialization and caching

**Don't Use Factory when:**
- ❌ Only simple coordinator creation
- ❌ Logic too simple, factory adds complexity
- ❌ Coordinator used only once, no reuse

### 3. Delegate vs Closures

**Use Delegate when:**
- ✅ Multiple methods to communicate (>2-3 methods)
- ✅ Long-lived relationship (coordinator lifetime)
- ✅ Want type-safe protocol

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
// In strategy/factory coordinators with .none presentation
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

**LCoordinator SDK provides:**

✅ **Clear separation of concerns:** Navigation separated from business logic and UI
✅ **Flexible navigation:** Support for push, modal, bottom sheet, and deep linking
✅ **Reusable patterns:** Factory, Strategy, Plugin patterns for code reusability
✅ **Type-safe communication:** Protocols for coordinator communication
✅ **Automatic memory management:** Router automatically cleans up coordinators
✅ **Testability:** Easy to mock and test navigation flows
✅ **Scalability:** Easy to add new flows and screens

**Key Takeaways:**
- Coordinators handle navigation, ViewModels handle logic
- Use factories to separate complex creation logic
- Always use weak references for delegates and parents
- Let router handle cleanup automatically
- Use plugins for embedded components, strategies for variants
- Use ActiveChildCoordinator for container coordinators (Tabbar, Segment)

---

## Getting Help

For issues, feature requests, or contributions, visit: [GitHub Repository](https://github.com/97longphan/LCoordinator)

---

**SDK Version:** 1.0.0
**iOS Minimum:** 14.0+
**Swift Version:** 5.9+
**License:** MIT
