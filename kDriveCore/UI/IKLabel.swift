/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2021 Infomaniak Network SA

 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import kDriveResources
import UIKit

public struct TextStyle: RawRepresentable {
    public var font: UIFont
    public var color: UIColor

    public static let header1 = TextStyle(font: UIFont.systemFont(ofSize: UIFontMetrics.default.scaledValue(for: 28), weight: .bold), color: KDriveResourcesAsset.titleColor.color, rawValue: "header1")
    public static let header2 = TextStyle(font: UIFont.systemFont(ofSize: UIFontMetrics.default.scaledValue(for: 18), weight: .semibold), color: KDriveResourcesAsset.titleColor.color, rawValue: "header2")
    public static let header3 = TextStyle(font: UIFont.systemFont(ofSize: UIFontMetrics.default.scaledValue(for: 16), weight: .semibold), color: KDriveResourcesAsset.titleColor.color, rawValue: "header3")
    public static let subtitle1 = TextStyle(font: UIFont.systemFont(ofSize: UIFontMetrics.default.scaledValue(for: 16), weight: .regular), color: KDriveResourcesAsset.titleColor.color, rawValue: "subtitle1")
    public static let subtitle2 = TextStyle(font: UIFont.systemFont(ofSize: UIFontMetrics.default.scaledValue(for: 14), weight: .medium), color: KDriveResourcesAsset.titleColor.color, rawValue: "subtitle2")
    public static let body1 = TextStyle(font: UIFont.systemFont(ofSize: UIFontMetrics.default.scaledValue(for: 14), weight: .regular), color: KDriveResourcesAsset.titleColor.color, rawValue: "body1")
    public static let body2 = TextStyle(font: UIFont.systemFont(ofSize: UIFontMetrics.default.scaledValue(for: 14), weight: .regular), color: KDriveResourcesAsset.primaryTextColor.color, rawValue: "body2")
    public static let caption = TextStyle(font: UIFont.systemFont(ofSize: UIFontMetrics.default.scaledValue(for: 12), weight: .regular), color: KDriveResourcesAsset.primaryTextColor.color, rawValue: "caption")
    public static let header1Light = TextStyle(font: UIFont.systemFont(ofSize: UIFontMetrics.default.scaledValue(for: 28), weight: .bold), color: .white, rawValue: "header1Light")
    public static let captionLight = TextStyle(font: UIFont.systemFont(ofSize: UIFontMetrics.default.scaledValue(for: 12), weight: .regular), color: .white, rawValue: "captionLight")
    public static let body1Light = TextStyle(font: UIFont.systemFont(ofSize: UIFontMetrics.default.scaledValue(for: 14), weight: .regular), color: .white, rawValue: "body1Light")
    public static let action = TextStyle(font: UIFont.systemFont(ofSize: UIFontMetrics.default.scaledValue(for: 14), weight: .regular), color: KDriveResourcesAsset.infomaniakColor.color, rawValue: "action")

    static let allValues = [header1, header2, header3, subtitle1, subtitle2, body1, body2, caption, header1Light, captionLight, body1Light, action]

    public typealias RawValue = String
    public var rawValue: String

    internal init(font: UIFont, color: UIColor, rawValue: RawValue) {
        self.font = font
        self.color = color
        self.rawValue = rawValue
    }

    public init?(rawValue: String) {
        if let style = TextStyle.allValues.first(where: { $0.rawValue == rawValue }) {
            self = style
        } else {
            return nil
        }
    }
}

@IBDesignable public class IKLabel: UILabel {
    /// Set label style.
    @IBInspectable public var styleName: String = TextStyle.body1.rawValue {
        didSet { setUpLabel() }
    }

    /// Set label style.
    public var style: TextStyle {
        get {
            return TextStyle(rawValue: styleName) ?? .body1
        }
        set {
            styleName = newValue.rawValue
        }
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        setUpLabel()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUpLabel()
    }

    override public func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        setUpLabel()
    }

    func setUpLabel() {
        font = style.font
        textColor = style.color
    }
}
