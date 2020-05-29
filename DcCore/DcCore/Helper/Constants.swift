import UIKit

public struct Constants {

    public struct Keys {
        static let deltachatUserProvidedCredentialsKey = "__DELTACHAT_USER_PROVIDED_CREDENTIALS_KEY__"
        static let deltachatImapEmailKey = "__DELTACHAT_IMAP_EMAIL_KEY__"
        static let deltachatImapPasswordKey = "__DELTACHAT_IMAP_PASSWORD_KEY__"
    }
    public static let notificationIdentifier = "deltachat-ios-local-notifications"

    public static let sharedUserDefaults = "deltachat-ios-shared-user-defaults"
    public static let hasExtensionAttemptedToSend = "hasExtensionAttemptedToSend"
}
