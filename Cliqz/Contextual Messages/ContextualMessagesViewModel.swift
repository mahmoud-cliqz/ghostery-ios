//
//  ContextualMessagesViewModel.swift
//  Client
//
//  Created by Mahmoud Adam on 2/22/19.
//  Copyright © 2019 Cliqz. All rights reserved.
//

import UIKit
enum ContextualMessageType {
    case expiredTrial
    case onboarding
    case adBlocking(Int)
    case antiTracking(String)
}

extension Notification.Name {
    static let ContextualMessageNotification = Notification.Name("ContextualMessageNotification")
}


class ContextualMessagesViewModel: NSObject {
    
    private static let LastShowMessageDateKey = "contextualMessage.any.show.date"
    private static let OnboardingMessageDismissedKey = "contextualMessage.onboarding.show"
    private static let OnboardingDataSyncedKey = "contextualMessage.onboarding.synced"
    private static let LastExpiredTrailsMessageDateKey = "contextualMessage.expiredTrial.show.date"
    private static let adBlockingMessageCountKey = "contextualMessage.adBlocking.show.count"
    private static let antiTrackingMessageCountKey = "contextualMessage.antiTracking.show.count"
    
    static let shared = ContextualMessagesViewModel()
    
    func getContextualMessageType(blockedAds: Int = 0, trackerCompanies: [String] = [String]()) -> ContextualMessageType? {
        if shouldShowOnboardingMesage() {
            return .onboarding
        }
        
        guard shouldShowContextualMessage() else {
            return nil
        }
        
        var type: ContextualMessageType?
        // NotYetImplemented
//        if shouldShowExpiredTrialMessage() {
//            type = .expiredTrial
//        } else
        if shouldShowAdBlockingMessage(blockedAds) {
            type = .adBlocking(blockedAds)
        } else if let trackingCompany = getFamousTrackingCompany(trackerCompanies) {
            type = .antiTracking(trackingCompany)
        }
        
        if type != nil {
            didShowContextualMessage()
        }
        return type
    }
    
    func contextualMessageShown(_ type: ContextualMessageType) {
        switch type {
        case .onboarding:
            UserDefaults.standard.set(true, forKey: ContextualMessagesViewModel.OnboardingMessageDismissedKey)
            LegacyTelemetryHelper.logMessage(action: "show", topic: "onboarding_dashboard", style: "notification", view: "web")
        
        case .expiredTrial:
            UserDefaults.standard.set(Date(), forKey: ContextualMessagesViewModel.LastExpiredTrailsMessageDateKey)
            LegacyTelemetryHelper.logMessage(action: "show", topic: "upgrade", style: "notification", view: "web")
        
        case .adBlocking:
            let count = UserDefaults.standard.integer(forKey: ContextualMessagesViewModel.adBlockingMessageCountKey)
            UserDefaults.standard.set(count + 1, forKey: ContextualMessagesViewModel.adBlockingMessageCountKey)
            LegacyTelemetryHelper.logMessage(action: "show", topic: "onboarding_ad_blocking", style: "notification", view: "web")
            
        case .antiTracking:
            let count = UserDefaults.standard.integer(forKey: ContextualMessagesViewModel.antiTrackingMessageCountKey)
            UserDefaults.standard.set(count + 1, forKey: ContextualMessagesViewModel.antiTrackingMessageCountKey)
            LegacyTelemetryHelper.logMessage(action: "show", topic: "onboarding_anti_tracking", style: "notification", view: "web")
            
        }
    }
    
    func onboardingDataSynced() {
        UserDefaults.standard.set(true, forKey: ContextualMessagesViewModel.OnboardingDataSyncedKey)
    }
    
    //MARK:- private helper methods
    /*
     * Show on first page the user visits (right from beginning; don't wait until page is loaded)
     * Keep showing on all web pages, but not on start tab, VPN view, etc. until user has clicked on the dashboard icon, thus opening the dashboard for the first time
     */
    private func shouldShowOnboardingMesage() -> Bool {
        let onboardingDataSynced = UserDefaults.standard.bool(forKey: ContextualMessagesViewModel.OnboardingDataSyncedKey)
        let onboardingMessageDismissed = UserDefaults.standard.bool(forKey: ContextualMessagesViewModel.OnboardingMessageDismissedKey)
        return onboardingDataSynced && !onboardingMessageDismissed
    }
    
    /*
     * Show on first web page the user visits.
     * Keep showing until user dismisses or tab is closed.
     * Show every 3 days.
     */
    private func shouldShowExpiredTrialMessage() -> Bool {
        guard SubscriptionController.shared.getCurrentSubscription().isLimitedSubscription() else { return false }
        
        guard let lastShowDate = UserDefaults.standard.value(forKey: ContextualMessagesViewModel.LastExpiredTrailsMessageDateKey) as? Date,
            let daysCount = lastShowDate.daysUntil(Date()) else {
                return true
        }
        return daysCount > 2
        
    }
    /*
     * Current page has N > 3 ads blocked.
     * No other message (as defined in this ticket) was shown today (i.e., show only one message per day).
     * This message was shown < 2 times before on any day (i.e., show this message only 2 times in total).
     */
    private func shouldShowAdBlockingMessage(_ blockedAds: Int) -> Bool {
        let count = UserDefaults.standard.integer(forKey: ContextualMessagesViewModel.adBlockingMessageCountKey)
        guard count < 2 else {
            return false
        }

        return blockedAds > 3
    }
    
    /*
     * Current page has one of the following tracker companies C blocked: Google, Facebook, Twitter, LinkedIn.
     * No other message (as defined in this ticket) was shown today (i.e., show only one message per day).
     * This message was shown < 3 times before on any day (i.e., show this message only 3 times in total).
     */
    private func getFamousTrackingCompany(_ trackerCompanies: [String]) -> String? {
        let count = UserDefaults.standard.integer(forKey: ContextualMessagesViewModel.antiTrackingMessageCountKey)
        guard count < 3 else { return nil }
        let regex = try! NSRegularExpression(pattern: "facebook|google|twitter|linkedin")

        for tracker in trackerCompanies {
            let trakcerLowercased = tracker.lowercased()
            let range = NSRange(location: 0, length: trakcerLowercased.utf16.count)
            if regex.firstMatch(in: trakcerLowercased, options: [], range: range) != nil {
                return tracker
            }
        }

        return nil
    }
    
    private func didShowContextualMessage() {
        UserDefaults.standard.set(Date(), forKey: ContextualMessagesViewModel.LastShowMessageDateKey)
    }
    
    private func shouldShowContextualMessage() -> Bool {
        guard let lastShowDate = UserDefaults.standard.value(forKey: ContextualMessagesViewModel.LastShowMessageDateKey) as? Date,
            let daysCount = lastShowDate.daysUntil(Date()) else {
            return true
        }
        return daysCount > 0
    }
}
