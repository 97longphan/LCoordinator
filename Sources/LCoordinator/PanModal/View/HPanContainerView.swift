//
//  HPanContainerView.swift
//  PanModal
//
//  Copyright © 2018 Tiny Speck, Inc. All rights reserved.
//

#if os(iOS)
    import UIKit

    /**
     A view wrapper around the presented view in a PanModal transition.

     This allows us to make modifications to the presented view without
     having to do those changes directly on the view
     */
    class HPanContainerView: UIView {

        init(presentedView: UIView, frame: CGRect) {
            super.init(frame: frame)
            addSubview(presentedView)
        }

        @available(*, unavailable)
        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

    }

    extension UIView {

        /**
         Convenience property for retrieving a HPanContainerView instance
         from the view hierachy
         */
        var panContainerView: HPanContainerView? {
            return subviews.first(where: { view -> Bool in
                view is HPanContainerView
            }) as? HPanContainerView
        }

    }
#endif
