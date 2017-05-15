/* This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Shared

let TabsBarHeight = CGFloat(29)

extension UILabel {
    func boldRange(_ range: Range<String.Index>) {
        if let text = self.attributedText {
            let attr = NSMutableAttributedString(attributedString: text)
            let start = text.string.characters.distance(from: text.string.startIndex, to: range.lowerBound)
            let length = <#T##String.CharacterView corresponding to your index##String.CharacterView#>.distance(from: range.lowerBound, to: range.upperBound)
            attr.addAttributes([NSFontAttributeName: UIFont.boldSystemFont(ofSize: self.font.pointSize)], range: NSMakeRange(start, length))
            self.attributedText = attr
        }
    }

    func boldSubstring(_ substr: String) {
        let range = self.text?.range(of: substr)
        if let r = range {
            boldRange(r)
        }
    }
}

class ButtonWithUnderlayView : UIButton {
    lazy var starView: UIImageView = {
        let v = UIImageView()
        v.contentMode = .center
        self.addSubview(v)
        v.isUserInteractionEnabled = false

        v.snp_makeConstraints {
            make in
            make.center.equalTo(self.snp_center)
        }
        return v
    }()

    // Visible when button is selected
    lazy var underlay: UIView = {
        let v = UIView()
        if UIDevice.current.userInterfaceIdiom == .pad {
            v.backgroundColor = BraveUX.ProgressBarColor
            v.layer.cornerRadius = 4
            v.layer.borderWidth = 0
            v.layer.masksToBounds = true
        }
        v.isUserInteractionEnabled = false
        v.isHidden = true

        return v
    }()

    func hideUnderlay(_ hide: Bool) {
        underlay.isHidden = hide
        starView.isHidden = !hide
    }

    func setStarImageBookmarked(_ on: Bool) {
        let starName = on ? "listpanel_bookmarked_star" : "listpanel_notbookmarked_star"
        let templateMode: UIImageRenderingMode = on ? .alwaysOriginal : .alwaysTemplate
        starView.image = UIImage(named: starName)!.withRenderingMode(templateMode)
    }
}

class BraveURLBarView : URLBarView {

    static var CurrentHeight = UIConstants.ToolbarHeight

    fileprivate static weak var currentInstance: BraveURLBarView?
    lazy var leftSidePanelButton: ButtonWithUnderlayView = { return ButtonWithUnderlayView() }()
    lazy var braveButton = { return UIButton() }()

    let tabsBarController = TabsBarViewController()
    var readerModeToolbar: ReaderModeBarView?

    override func commonInit() {
        BraveURLBarView.currentInstance = self
        locationContainer.layer.cornerRadius = BraveUX.TextFieldCornerRadius

        addSubview(leftSidePanelButton.underlay)
        addSubview(leftSidePanelButton)
        addSubview(braveButton)
        super.commonInit()

        leftSidePanelButton.addTarget(self, action: #selector(onClickLeftSlideOut), for: UIControlEvents.touchUpInside)
        leftSidePanelButton.setImage(UIImage(named: "listpanel")?.withRenderingMode(.alwaysTemplate), for: UIControlState())
        leftSidePanelButton.setImage(UIImage(named: "listpanel_down")?.withRenderingMode(.alwaysTemplate), for: .selected)
        leftSidePanelButton.accessibilityLabel = Strings.Bookmarks_and_History_Panel
        leftSidePanelButton.setStarImageBookmarked(false)

        braveButton.addTarget(self, action: #selector(onClickBraveButton) , for: UIControlEvents.touchUpInside)
        braveButton.setImage(UIImage(named: "bravePanelButton"), for: UIControlState())
        braveButton.setImage(UIImage(named: "bravePanelButtonOff"), for: .selected)
        braveButton.accessibilityLabel = Strings.Brave_Panel
        braveButton.tintColor = BraveUX.ActionButtonTintColor

        tabsBarController.view.alpha = 0.0
        addSubview(tabsBarController.view)
        getApp().browserViewController.addChildViewController(tabsBarController)
        tabsBarController.didMove(toParentViewController: getApp().browserViewController)
    }

    func showReaderModeBar() {
        if readerModeToolbar != nil {
            return
        }
        readerModeToolbar = ReaderModeBarView(frame: CGRect.zero)
        readerModeToolbar!.delegate = getApp().browserViewController
        addSubview(readerModeToolbar!)
        self.setNeedsLayout()
    }

    func hideReaderModeBar() {
        if let readerModeBar = readerModeToolbar {
            readerModeBar.removeFromSuperview()
            readerModeToolbar = nil
            self.setNeedsLayout()
        }
    }


    override func updateTabsBarShowing() {
        var tabCount = getApp().tabManager.tabs.displayedTabsForCurrentPrivateMode.count

        let showingPolicy = TabsBarShowPolicy(rawValue: Int(BraveApp.getPrefs()?.intForKey(kPrefKeyTabsBarShowPolicy) ?? Int32(kPrefKeyTabsBarOnDefaultValue.rawValue))) ?? kPrefKeyTabsBarOnDefaultValue

        let bvc = getApp().browserViewController
        let noShowDueToPortrait =  UIDevice.currentDevice().userInterfaceIdiom == .Phone &&
            bvc.shouldShowFooterForTraitCollection(bvc.traitCollection) &&
            showingPolicy == TabsBarShowPolicy.LandscapeOnly

        let isShowing = tabsBarController.view.alpha > 0

        let shouldShow = showingPolicy != TabsBarShowPolicy.Never && tabCount > 1 && !noShowDueToPortrait

        func updateOffsets() {
            bvc.headerHeightConstraint?.updateOffset(BraveURLBarView.CurrentHeight)
            bvc.webViewContainerTopOffset?.updateOffset(BraveURLBarView.CurrentHeight)
        }

        if !isShowing && shouldShow {
            self.tabsBarController.view.alpha = 1
            BraveURLBarView.CurrentHeight = TabsBarHeight + UIConstants.ToolbarHeight
            updateOffsets()
        } else if isShowing && !shouldShow  {
            UIView.animate(withDuration: 0.1, animations: {
                self.tabsBarController.view.alpha = 0
                }, completion: { _ in
                    BraveURLBarView.CurrentHeight = UIConstants.ToolbarHeight
                    UIView.animate(withDuration: 0.2, animations: {
                        updateOffsets()
                        bvc?.view.layoutIfNeeded()
                    }) 
            })
        }
    }

    override func applyTheme(_ themeName: String) {
        super.applyTheme(themeName)
        
        guard let theme = URLBarViewUX.Themes[themeName] else { return }
        
        leftSidePanelButton.tintColor = theme.buttonTintColor
        
        switch(themeName) {
        case Theme.NormalMode:
            backgroundColor = BraveUX.ToolbarsBackgroundSolidColor
        case Theme.PrivateMode:
            backgroundColor = BraveUX.DarkToolbarsBackgroundSolidColor
        default:
            break
        }
    }

    override func updateAlphaForSubviews(_ alpha: CGFloat) {
        super.updateAlphaForSubviews(alpha)
        // TODO tabsBarController use view.alpha to determine if it is shown or hidden, ideally this could be refactored to that
        // any callers can do tabsBarController.view.alpha == xx, without knowing that it has a side-effect
        tabsBarController.view.subviews.forEach { $0.alpha = alpha }

        readerModeToolbar?.alpha = alpha
        leftSidePanelButton.alpha = alpha
        braveButton.alpha = alpha
    }

    @objc func onClickLeftSlideOut() {
        leftSidePanelButton.isSelected = !leftSidePanelButton.isSelected
        NotificationCenter.default.post(name: Notification.Name(rawValue: kNotificationLeftSlideOutClicked), object: leftSidePanelButton)
    }

    @objc func onClickBraveButton() {
        telemetry(action: "Show Brave Panel", props: nil)
        NotificationCenter.default.post(name: Notification.Name(rawValue: kNotificationBraveButtonClicked), object: braveButton)
    }

    override func updateTabCount(_ count: Int, animated: Bool = true) {
        super.updateTabCount(count, animated: bottomToolbarIsHidden)
        BraveBrowserBottomToolbar.updateTabCountDuplicatedButton(count, animated: animated)
    }

    class func tabButtonPressed() {
        guard let instance = BraveURLBarView.currentInstance else { return }
        instance.delegate?.urlBarDidPressTabs(instance)
    }

    override var accessibilityElements: [AnyObject]? {
        get {
            if inSearchMode {
                guard let locationTextField = locationTextField else { return nil }
                return [leftSidePanelButton, locationTextField, cancelButton]
            } else {
                if bottomToolbarIsHidden {
                    return [backButton, forwardButton, leftSidePanelButton, locationView, braveButton, shareButton, tabsButton]
                } else {
                    return [leftSidePanelButton, locationView, braveButton]
                }
            }
        }
        set {
            super.accessibilityElements = newValue
        }
    }

    override func updateViewsForSearchModeAndToolbarChanges() {
        super.updateViewsForSearchModeAndToolbarChanges()
        
        self.tabsButton.isHidden = !self.bottomToolbarIsHidden
    }

    override func prepareSearchAnimation() {
        super.prepareSearchAnimation()
        braveButton.isHidden = true
        readerModeToolbar?.isHidden = true
    }

    override func transitionToSearch(_ didCancel: Bool = false) {
        super.transitionToSearch(didCancel)
        locationView.alpha = 0.0
    }

    override func leaveSearchMode(didCancel cancel: Bool) {
        if !inSearchMode {
            return
        }

        super.leaveSearchMode(didCancel: cancel)
        locationView.alpha = 1.0

        // The orange brave button sliding in looks odd, lets fade it in in-place
        braveButton.alpha = 0
        braveButton.isHidden = false
        UIView.animate(withDuration: 0.3, animations: { self.braveButton.alpha = 1.0 })
        readerModeToolbar?.isHidden = false
    }

    override func updateConstraints() {
        super.updateConstraints()

        if tabsBarController.view.superview != nil {
            bringSubview(toFront: tabsBarController.view)
            tabsBarController.view.snp_makeConstraints { (make) in
                make.bottom.left.right.equalTo(self)
                make.height.equalTo(TabsBarHeight)
            }
        }

        clipsToBounds = false
        if let readerModeToolbar = readerModeToolbar {
            bringSubview(toFront: readerModeToolbar)
            readerModeToolbar.snp_makeConstraints {
                make in
                make.left.right.equalTo(self)
                make.top.equalTo(snp_bottom)
                make.height.equalTo(24)
            }
        }
        
        leftSidePanelButton.underlay.snp_makeConstraints {
            make in
            make.left.right.equalTo(leftSidePanelButton).inset(4)
            make.top.bottom.equalTo(leftSidePanelButton).inset(7)
        }

        func pinLeftPanelButtonToLeft() {
            leftSidePanelButton.snp_remakeConstraints { make in
                make.left.equalTo(self)
                make.centerY.equalTo(self.locationContainer)
                make.size.equalTo(UIConstants.ToolbarHeight)
            }
        }

        if inSearchMode {
            // In overlay mode, we always show the location view full width
            self.locationContainer.snp_remakeConstraints { make in
                make.left.equalTo(self.leftSidePanelButton.snp_right)//.offset(URLBarViewUX.LocationLeftPadding)
                make.right.equalTo(self.cancelButton.snp_left)
                make.height.equalTo(URLBarViewUX.LocationHeight)
                make.top.equalTo(self).inset(8)
            }
            pinLeftPanelButtonToLeft()
        } else {
            self.locationContainer.snp_remakeConstraints { make in
                if self.bottomToolbarIsHidden {
                    // Firefox is not referring to the bottom toolbar, it is asking is this class showing more tool buttons
                    make.leading.equalTo(self.leftSidePanelButton.snp_trailing)
                    make.trailing.equalTo(self).inset(UIConstants.ToolbarHeight * (3 + (pwdMgrButton.isHidden == false ? 1 : 0)))
                } else {
                    make.left.right.equalTo(self).inset(UIConstants.ToolbarHeight)
                }

                make.height.equalTo(URLBarViewUX.LocationHeight)
                make.top.equalTo(self).inset(8)
            }

            if self.bottomToolbarIsHidden {
                leftSidePanelButton.snp_remakeConstraints { make in
                    make.left.equalTo(self.forwardButton.snp_right)
                    make.centerY.equalTo(self.locationContainer)
                    make.size.equalTo(UIConstants.ToolbarHeight)
                }
            } else {
                pinLeftPanelButtonToLeft()
            }

            braveButton.snp_remakeConstraints { make in
                make.left.equalTo(self.locationContainer.snp_right)
                make.centerY.equalTo(self.locationContainer)
                make.size.equalTo(UIConstants.ToolbarHeight)
            }
            
            pwdMgrButton.snp_updateConstraints { make in
                make.width.equalTo(pwdMgrButton.isHidden ? 0 : UIConstants.ToolbarHeight)
            }
        }
    }

    override func setupConstraints() {
        backButton.snp_remakeConstraints { make in
            make.centerY.equalTo(self.locationContainer)
            make.left.equalTo(self)
            make.size.equalTo(UIConstants.ToolbarHeight)
        }

        forwardButton.snp_makeConstraints { make in
            make.left.equalTo(self.backButton.snp_right)
            make.centerY.equalTo(self.locationContainer)
            make.size.equalTo(backButton)
        }

        leftSidePanelButton.snp_makeConstraints { make in
            make.left.equalTo(self.forwardButton.snp_right)
            make.centerY.equalTo(self.locationContainer)
            make.size.equalTo(UIConstants.ToolbarHeight)
        }

        locationView.snp_makeConstraints { make in
            make.edges.equalTo(self.locationContainer)
        }

        cancelButton.snp_makeConstraints { make in
            make.centerY.equalTo(self.locationContainer)
            make.trailing.equalTo(self)
        }

        shareButton.snp_remakeConstraints { make in
            make.right.equalTo(self.pwdMgrButton.snp_left).offset(0)
            make.centerY.equalTo(self.locationContainer)
            make.width.equalTo(UIConstants.ToolbarHeight)
        }
        
        pwdMgrButton.snp_remakeConstraints { make in
            make.right.equalTo(self.tabsButton.snp_left).offset(0)
            make.centerY.equalTo(self.locationContainer)
            make.width.equalTo(0)
        }

        tabsButton.snp_makeConstraints { make in
            make.centerY.equalTo(self.locationContainer)
            make.trailing.equalTo(self)
            make.size.equalTo(UIConstants.ToolbarHeight)
        }
    }

    fileprivate var progressIsCompleting = false
    fileprivate var updateIsScheduled = false
    override func updateProgressBar(_ progress: Float, dueToTabChange: Bool = false) {
        struct staticProgress { static var val = Float(0) }
        let minProgress = locationView.frame.width / 3.0
        
        locationView.braveProgressView.backgroundColor = PrivateBrowsing.singleton.isOn ? BraveUX.ProgressBarDarkColor : BraveUX.ProgressBarColor

        func setWidth(_ width: CGFloat) {
            var frame = locationView.braveProgressView.frame
            frame.size.width = width
            locationView.braveProgressView.frame = frame
        }

        if dueToTabChange {
            if (progress == 1.0 || progress == 0.0) {
                locationView.braveProgressView.alpha = 0
            }
            else {
                locationView.braveProgressView.alpha = 1
                setWidth(minProgress + CGFloat(progress) * (self.locationView.frame.width - minProgress))
            }
            return
        }

        func performUpdate() {
            let progress = staticProgress.val

            if progress == 1.0 || progress == 0 {
                if progressIsCompleting {
                    return
                }
                progressIsCompleting = true

                UIView.animate(withDuration: 0.5, animations: {
                    setWidth(self.locationView.frame.width)
                    }, completion: { _ in
                        UIView.animate(withDuration: 0.5, animations: {
                            self.locationView.braveProgressView.alpha = 0.0
                            }, completion: { _ in
                                self.progressIsCompleting = false
                                setWidth(0)
                        })
                })
            } else {
                self.locationView.braveProgressView.alpha = 1.0
                progressIsCompleting = false
                let w = minProgress + CGFloat(progress) * (self.locationView.frame.width - minProgress)

                if w > locationView.braveProgressView.frame.size.width {
                    UIView.animate(withDuration: 0.5, animations: {
                        setWidth(w)
                        }, completion: { _ in
                            
                    })
                }
            }
        }

        staticProgress.val = progress

        if updateIsScheduled {
            return
        }
        updateIsScheduled = true

        postAsyncToMain(0.2) {
            self.updateIsScheduled = false
            performUpdate()
        }
    }

    override func updateBookmarkStatus(_ isBookmarked: Bool) {
        getApp().braveTopViewController.updateBookmarkStatus(isBookmarked)
        leftSidePanelButton.setStarImageBookmarked(isBookmarked)
    }

    func setBraveButtonState(shieldsUp: Bool, animated: Bool) {
        let selected = !shieldsUp
        if braveButton.isSelected == selected {
            return
        }
        
        braveButton.isSelected = selected

        if !animated {
            return
        }

        let v = InsetLabel(frame: CGRect(x: 0, y: 0, width: locationContainer.frame.width, height: locationContainer.frame.height))
        v.rightInset = CGFloat(40)
        v.text = braveButton.selected ? Strings.Shields_Up : Strings.Shields_Down
        if v.text!.endsWith(" Up") || v.text!.endsWith(" Down") {
            // english translation gets bolded text
            if var range = v.text!.range(of: " ", options:NSString.CompareOptions.backwards) {
                range.upperBound = v.text!.characters.endIndex
                v.boldRange(range)
            }
        }

        v.backgroundColor = braveButton.isSelected ? UIColor(white: 0.6, alpha: 1.0) : BraveUX.BraveButtonMessageInUrlBarColor
        v.textAlignment = .right
        locationContainer.addSubview(v)
        v.alpha = 0.0
        UIView.animate(withDuration: 0.25, animations: { v.alpha = 1.0 }, completion: {
            finished in
            UIView.animate(withDuration: BraveUX.BraveButtonMessageInUrlBarFadeTime, delay: BraveUX.BraveButtonMessageInUrlBarShowTime, options: [], animations: {
                v.alpha = 0
                }, completion: {
                    finished in
                    v.removeFromSuperview()
            })
        })
    }
}
