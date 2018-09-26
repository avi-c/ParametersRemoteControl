//
//  DebugWindow.swift
//  WeatherOverground
//
//  Created by Avi Cieplinski on 7/17/18.
//  Copyright © 2018 Avi Cieplinski. All rights reserved.
//

import UIKit
import SwiftTweaks

class DebugTouchesView : UIView {
    var visibleTouchViews: [NSValue : UIView] = [:]

    override init(frame: CGRect = .zero) {
        super.init(frame: frame)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func visibleTouchView(for touch: UITouch) -> UIView? {
        let valueForUITouch = NSValue(nonretainedObject: touch)

        let visibleTouch = visibleTouchViews[valueForUITouch]

        return visibleTouch
    }

    fileprivate func update(with touches: Set<UITouch>) -> Void {

        // iterate through the UITouches and update the state of our visible touch views
        for touch in touches {
            var visibleTouchView = self.visibleTouchView(for: touch)

            if visibleTouchView == nil && touch.phase == .began {
                visibleTouchView = UIView.init(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
                if let newVisibleTouchView = visibleTouchView {
                    newVisibleTouchView.alpha = 0.0
                    newVisibleTouchView.backgroundColor = UIColor.mapboxBlue
                    newVisibleTouchView.layer.borderColor = UIColor.darkGray.cgColor
                    newVisibleTouchView.layer.borderWidth = 1.0
                    newVisibleTouchView.layer.cornerRadius = newVisibleTouchView.bounds.size.height / 2.0
                    newVisibleTouchView.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
                    newVisibleTouchView.center = touch.location(in: self)

                    let valueForUITouch = NSValue(nonretainedObject: touch)
                    self.visibleTouchViews.updateValue(newVisibleTouchView, forKey: valueForUITouch)
                    self.addSubview(newVisibleTouchView)

                    UIView.beginAnimations("addition", context: nil)
                    UIView.setAnimationDuration(0.6)
                    UIView.animate(withDuration: 0.6, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.1, options: .curveEaseInOut, animations: {
                        newVisibleTouchView.alpha = 1.0
                        newVisibleTouchView.transform = .identity
                    }, completion: nil)
                    UIView.commitAnimations()
                }
            }

            // update position of visible touch view
            visibleTouchView?.center = touch.location(in: self)

            if touch.phase == .cancelled || touch.phase == .ended {
                let valueForUITouch = NSValue(nonretainedObject: touch)

                self.visibleTouchViews.removeValue(forKey: valueForUITouch)

                UIView.beginAnimations("show", context: nil)
                UIView.setAnimationDuration(0)
                visibleTouchView?.alpha = 1.0
                UIView.commitAnimations()

                UIView.beginAnimations("removal", context: nil)
                UIView.setAnimationDuration(0.25)
                UIView.animate(withDuration: 0.25, animations: {
                    visibleTouchView?.alpha = 0.0
                    visibleTouchView?.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
                }) { (_) in
                    visibleTouchView?.removeFromSuperview()
                }
                UIView.commitAnimations()
            }
        }
    }
}

class DebugWindow: UIWindow {

    fileprivate let tweakStore: TweakStore
    private var tweaksViewController: TweaksViewController!

    var debugTouchesView: DebugTouchesView? = nil
    var debugTouchesTweakBindingIdentifier: TweakBindingIdentifier? = nil

    init(frame: CGRect = .zero, tweakStore: TweakStore) {
        self.tweakStore = tweakStore
        super.init(frame: frame)

        debugTouchesTweakBindingIdentifier = TweakParameters.bind(TweakParameters.debugTouchesEnabled) {showDebugTouches in
            if (showDebugTouches) {
                self.debugTouchesView = DebugTouchesView(frame: frame)
                self.debugTouchesView?.isUserInteractionEnabled = false
                self.debugTouchesView?.isMultipleTouchEnabled = true
                self.debugTouchesView?.backgroundColor = UIColor.clear
                self.addSubview(self.debugTouchesView!)
            } else {
                self.debugTouchesView?.removeFromSuperview()
            }
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func sendEvent(_ event: UIEvent) {
        super.sendEvent(event)

        if event.type == .touches, let debugTouchesView = self.debugTouchesView, let touches = event.allTouches {
            UIView.animate(withDuration: 0) {
                self.bringSubviewToFront(debugTouchesView)
                debugTouchesView.update(with: touches)
            }
        }
    }
}
