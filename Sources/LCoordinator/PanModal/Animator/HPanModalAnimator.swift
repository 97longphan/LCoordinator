//
//  HPanModalAnimator.swift
//  PanModal
//
//  Copyright © 2019 Tiny Speck, Inc. All rights reserved.
//

#if os(iOS)
    import UIKit

    /**
     Helper animation function to keep animations consistent.
     */
    struct HPanModalAnimator {

        /**
         Constant Animation Properties
         */
        struct Constants {
            static let defaultTransitionDuration: TimeInterval = 0.5
        }

        static func animate(
            _ animations: @escaping HPanModalPresentable.AnimationBlockType,
            config: HPanModalPresentable?,
            _ completion: HPanModalPresentable.AnimationCompletionType? = nil
        ) {

            let transitionDuration = config?.transitionDuration ?? Constants.defaultTransitionDuration
            let springDamping = config?.springDamping ?? 1.0
            let animationOptions = config?.transitionAnimationOptions ?? []

            UIView.animate(
                withDuration: transitionDuration,
                delay: 0,
                usingSpringWithDamping: springDamping,
                initialSpringVelocity: 0,
                options: animationOptions,
                animations: animations,
                completion: completion
            )
        }
    }
#endif
