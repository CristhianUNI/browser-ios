import Foundation
import Deferred
import Shared
import Storage

// These override the setting in the prefs
public struct BraveShieldState {

    public static func set(forDomain domain: String, state: (BraveShieldState.Shield, Bool?)) {
        BraveShieldState.setInMemoryforDomain(domain, setState: state)

        if PrivateBrowsing.singleton.isOn {
            return
        }

        let context = DataController.shared.workerContext()
        context.perform {
            Domain.setBraveShield(forDomain: domain, state: state, context: context)
        }
    }

    public enum Shield : String {
        case AllOff = "all_off"
        case AdblockAndTp = "adblock_and_tp"
        case HTTPSE = "httpse"
        case SafeBrowsing = "safebrowsing"
        case FpProtection = "fp_protection"
        case NoScript = "noscript"
    }

    fileprivate var state = [Shield:Bool]()

    typealias DomainKey = String
    static var perNormalizedDomain = [DomainKey: BraveShieldState]()

    public static func setInMemoryforDomain(_ domain: String, setState state:(BraveShieldState.Shield, Bool?)) {
        var shields = perNormalizedDomain[domain]
        if shields == nil {
            if state.1 == nil {
                return
            }
            shields = BraveShieldState()
        }

        shields!.setState(state.0, on: state.1)
        perNormalizedDomain[domain] = shields!
    }

    static func getStateForDomain(_ domain: String) -> BraveShieldState? {
        return perNormalizedDomain[domain]
    }

    public init(jsonStateFromDbRow: String) {
        let js = JSON(string: jsonStateFromDbRow)
        for (k,v) in (js.asDictionary ?? [:]) {
            if let key = Shield(rawValue: k) {
                setState(key, on: v.asBool)
            } else {
                assert(false, "db has bad brave shield state")
            }
        }
    }

    public init() {
    }

    public init(orig: BraveShieldState) {
        self.state = orig.state // Dict value type is copied
    }

    func toJsonString() -> String? {
        var _state = [String: Bool]()
        for (k, v) in state {
            _state[k.rawValue] = v
        }
        return JSON(_state).toString()
    }

    mutating func setState(_ key: Shield, on: Bool?) {
        if let on = on {
            state[key] = on
        } else {
            state.removeValue(forKey: key)
        }
    }

    func isAllOff() -> Bool {
        return state[.AllOff] ?? false
    }

    func isNotSet() -> Bool {
        return state.count < 1
    }

    func isOnAdBlockAndTp() -> Bool? {
        return state[.AdblockAndTp] ?? nil
    }

    func isOnHTTPSE() -> Bool? {
        return state[.HTTPSE] ?? nil
    }

    func isOnSafeBrowsing() -> Bool? {
        return state[.SafeBrowsing] ?? nil
    }

    func isOnScriptBlocking() -> Bool? {
        return state[.NoScript] ?? nil
    }

    func isOnFingerprintProtection() -> Bool? {
        return state[.FpProtection] ?? nil
    }

    mutating func setStateFromPerPageShield(_ pageState: BraveShieldState?) {
        setState(.NoScript, on: pageState?.isOnScriptBlocking() ?? (BraveApp.getPrefs()?.boolForKey(kPrefKeyNoScriptOn) ?? false))
        setState(.AdblockAndTp, on: pageState?.isOnAdBlockAndTp() ?? AdBlocker.singleton.isNSPrefEnabled)
        setState(.SafeBrowsing, on: pageState?.isOnSafeBrowsing() ?? SafeBrowsing.singleton.isNSPrefEnabled)
        setState(.HTTPSE, on: pageState?.isOnHTTPSE() ?? HttpsEverywhere.singleton.isNSPrefEnabled)
        setState(.FpProtection, on: pageState?.isOnFingerprintProtection() ?? (BraveApp.getPrefs()?.boolForKey(kPrefKeyFingerprintProtection) ?? false))
    }
}

open class BraveGlobalShieldStats {
    static let singleton = BraveGlobalShieldStats()
    static let DidUpdateNotification = "BraveGlobalShieldStatsDidUpdate"
    
    fileprivate let prefs = UserDefaults.standard
    
    var adblock: Int = 0 {
        didSet {
            NotificationCenter.default.post(name: Notification.Name(rawValue: BraveGlobalShieldStats.DidUpdateNotification), object: nil)
        }
    }

    var trackingProtection: Int = 0 {
        didSet {
            NotificationCenter.default.post(name: Notification.Name(rawValue: BraveGlobalShieldStats.DidUpdateNotification), object: nil)
        }
    }

    var httpse: Int = 0 {
        didSet {
            NotificationCenter.default.post(name: Notification.Name(rawValue: BraveGlobalShieldStats.DidUpdateNotification), object: nil)
        }
    }
    
    var safeBrowsing: Int = 0 {
        didSet {
            NotificationCenter.default.post(name: Notification.Name(rawValue: BraveGlobalShieldStats.DidUpdateNotification), object: nil)
        }
    }
    
    var fpProtection: Int = 0 {
        didSet {
            NotificationCenter.default.post(name: Notification.Name(rawValue: BraveGlobalShieldStats.DidUpdateNotification), object: nil)
        }
    }
    

    enum Shield: String {
        case Adblock = "adblock"
        case TrackingProtection = "tracking_protection"
        case HTTPSE = "httpse"
        case SafeBrowsing = "safebrowsing"
        case FpProtection = "fp_protection"
    }
    
    fileprivate init() {
        adblock += prefs.integer(forKey: Shield.Adblock.rawValue)
        trackingProtection += prefs.integer(forKey: Shield.TrackingProtection.rawValue)
        httpse += prefs.integer(forKey: Shield.HTTPSE.rawValue)
        safeBrowsing += prefs.integer(forKey: Shield.SafeBrowsing.rawValue)
        fpProtection += prefs.integer(forKey: Shield.FpProtection.rawValue)
    }

    var bgSaveTask: UIBackgroundTaskIdentifier?

    open func save() {
        if let t = bgSaveTask, t != UIBackgroundTaskInvalid {
            return
        }
        
        bgSaveTask = UIApplication.shared.beginBackgroundTask(withName: "brave-global-stats-save", expirationHandler: {
            if let task = self.bgSaveTask {
                UIApplication.shared.endBackgroundTask(task)
            }
            self.bgSaveTask = UIBackgroundTaskInvalid
        })
        
        DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default).async { () -> Void in
            self.prefs.set(self.adblock, forKey: Shield.Adblock.rawValue)
            self.prefs.set(self.trackingProtection, forKey: Shield.TrackingProtection.rawValue)
            self.prefs.set(self.httpse, forKey: Shield.HTTPSE.rawValue)
            self.prefs.set(self.safeBrowsing, forKey: Shield.SafeBrowsing.rawValue)
            self.prefs.set(self.fpProtection, forKey: Shield.FpProtection.rawValue)
            self.prefs.synchronize()

            if let task = self.bgSaveTask {
                UIApplication.shared.endBackgroundTask(task)
            }
            self.bgSaveTask = UIBackgroundTaskInvalid
        }
    }
}
