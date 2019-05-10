//
//  OdometerView.swift
//
//  Copyright (c) 2018 RbBtSn0w
//
//  Forked from RbBtSn0w's RBSOdometerView, rewritten in Swift and modified by Jose Reyes on 5/8/19.
//

import UIKit
import CoreGraphics

class OdometerView: UIView {
    private let reuseKey = "ReuseTextLabelKey"
    private let kAnimationKey = "OdometerAnimationKey"

    var font = UIFont.systemFont(ofSize: 13, weight: .bold) {
        didSet {
            staticLabel.font = font
            attributes[NSAttributedString.Key.font] = font
        }
    }
    var textColor: UIColor = .white {
        didSet {
            staticLabel.textColor = .white
        }
    }
    lazy var formatter = NumberFormatter()

    private lazy var animationDuration: TimeInterval = 1.5
    private lazy var durationOffset: TimeInterval = 0.2
    private lazy var density: Int = 9

    private lazy var numbersText = [String]()
    private lazy var scrollLayers = [CAScrollLayer]()
    private lazy var scrollLabels = [ReuseTextLayer]()
    private lazy var fontSizeCache = NSCache<NSString, NSValue>()
    private lazy var attributes = [NSAttributedString.Key: Any]()
    private lazy var value = ""
    private lazy var mainScreenScale: CGFloat = 0

    var currentNumber: Int = 0 {
        didSet {
            staticLabel.text = formatter.string(from: NSNumber(value: currentNumber))
        }

    }

    private lazy var lastNumber = 0

    private var animatingCount = 0
    private lazy var reuseCache = TextLayerCache()
    private lazy var staticLabel = UILabel()
    private lazy var animationView = UIView()

    private var animationsFinished: Bool {
        return animatingCount == 0
    }

    private var needsInvalidateIntrinsicContentSize: Bool {
        return "\(currentNumber)".count != "\(lastNumber)".count
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setup()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        setup()
    }

    override var intrinsicContentSize: CGSize {
        var superSize = super.intrinsicContentSize

        var height: CGFloat = 0
        var width: CGFloat = 0

        for index in 0..<value.count {
            let nsRange = NSRange(location: index, length: 1)

            guard let startNumberStringRange = Range(nsRange, in: value) else { continue }

            let substring = value[startNumberStringRange]
            let stringSize = size(for: String(substring))
            height = max(height, stringSize.height)
            width += stringSize.width
        }

        superSize.width = width
        superSize.height = height
        return superSize
    }

    func setup() {
        formatter.numberStyle = .decimal
        mainScreenScale = UIScreen.main.scale

        [staticLabel, animationView].forEach { view in
            addSubview(view)

            view.translatesAutoresizingMaskIntoConstraints = false
            view.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
            view.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
            view.topAnchor.constraint(equalTo: topAnchor).isActive = true
            view.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        }

        staticLabel.alpha = 0
    }

    func stopAnimation() {
        for layer in scrollLayers {
            layer.removeAnimation(forKey: kAnimationKey)
        }
    }

    func setFont(font: UIFont) {
        self.font = font
        attributes[NSAttributedString.Key.font] = font
        fontSizeCache.removeAllObjects()
    }

    func setNumber(to number: Int, animated: Bool = true) {
        if animated {
            currentNumber = number
            animationView.alpha = 1
            staticLabel.alpha = 0

            guard animationsFinished else { return }

            prepareAnimations()

            print(String(format: "[Odometer] %tu", number))

            if needsInvalidateIntrinsicContentSize {
                invalidateIntrinsicContentSize()
            }

            createAnimations()
        } else {
            currentNumber = number
            value = formattedString(for: number)!
            animationView.alpha = 0
            staticLabel.alpha = 1

            if needsInvalidateIntrinsicContentSize {
                invalidateIntrinsicContentSize()
            }
        }
    }
}

// MARK: - Private Implementation
private extension OdometerView {
    func prepareAnimations() {
        for layer in scrollLayers {
            layer.removeFromSuperlayer()
        }

        numbersText.removeAll()
        scrollLayers.removeAll()

        scrollLabels.forEach { textLayer in
            if let index = scrollLabels.firstIndex(of: textLayer) {
                scrollLabels.remove(at: index)
            }

            reuseCache.enqueueReusableObject(textLayer)
        }

        let endingNumberString = formattedString(for: currentNumber)
        var startNumberString = formattedString(for: lastNumber)

        guard endingNumberString != nil, startNumberString != nil else { return }
        value = endingNumberString!

        let fillZeroLength = endingNumberString!.count - startNumberString!.count

        if fillZeroLength > 0 {
            for _ in 0...fillZeroLength {
                startNumberString = "0\(startNumberString!)"
            }
        }

        print("[Odometer] startNumberString: \(startNumberString!), endingNumberString: \(endingNumberString!)")

        var lastFrame = CGRect.zero

        for index in 0...endingNumberString!.count {
            let nsRange = NSRange(location: index, length: 1)

            guard
                let startNumberStringRange = Range(nsRange, in: startNumberString!),
                let endingNumberStringRange = Range(nsRange, in: endingNumberString!)
                else { return }

            let startDigitsString = startNumberString![startNumberStringRange]
            let endingDigitsString = endingNumberString![endingNumberStringRange]

            let stringSize = size(for: String(endingDigitsString))

            let width = stringSize.width
            let height = stringSize.height
            let layer = CAScrollLayer()
            layer.frame = CGRect(x: lastFrame.maxX, y: lastFrame.minY, width: width, height: height)
            lastFrame = layer.frame
            scrollLayers.append(layer)
            animationView.layer.addSublayer(layer)

            createContent(for: layer,
                          startingDigits: String(startDigitsString),
                          endingDigits: String(endingDigitsString))
            numbersText.append(String(endingDigitsString))
        }
    }

    func isNumberOf(string: String) -> Bool {
        var intNumber: Int32 = 0
        let scanNumber = Scanner(string: string)
        return scanNumber.scanInt32(&intNumber) && scanNumber.isAtEnd
    }

    func createContent(for scrollLayer: CALayer, startingDigits: String?, endingDigits: String) {
        var textForScroll = [String]()

        func createRandByDensity(digitsString: String) {
            let isNumber = isNumberOf(string: digitsString)

            if !isNumber { return }

            let number = Int(digitsString)!
            let maxDensity = self.density + 1

            for index in 0..<maxDensity {
                textForScroll.append(String(format: "%tu", (number + index) % 10))
            }
        }

        var needsAdditionalScrollDigits = true
        let endingDigitIsNumber = isNumberOf(string: endingDigits)

        if let startingDigits = startingDigits {
            let startDigitIsNumber = isNumberOf(string: startingDigits)
            if startDigitIsNumber && endingDigitIsNumber {
                if startingDigits == endingDigits {
                    textForScroll.append(endingDigits)
                    needsAdditionalScrollDigits = false
                } else {
                    for index in 0..<density + 1 {
                        if let intValue = Int(startingDigits) {
                            let currentValue = (intValue + index) % 10
                            textForScroll.append(String(format: "%d", currentValue))

                            if currentValue == Int(endingDigits) {
                                break
                            }
                        }
                    }
                    needsAdditionalScrollDigits = false
                }
            }
        }

        if needsAdditionalScrollDigits {
            createRandByDensity(digitsString: endingDigits)
            textForScroll.append(endingDigits)
        }

        var offsetY: CGFloat = 0

        for text in textForScroll {
            let frame = CGRect(x: 0,
                               y: offsetY,
                               width: scrollLayer.frame.width,
                               height: scrollLayer.frame.height)
            let layer = reuseTextLayer(for: text)
            layer.contentsScale = mainScreenScale
            layer.frame = frame
            scrollLayer.addSublayer(layer)
            scrollLabels.append(layer)
            offsetY = frame.maxY
        }
    }

    func size(for text: String) -> CGSize {
        var nsText = NSString(string: text)

        if isNumberOf(string: text) {
            nsText = "8"
        }

        if let value = fontSizeCache.object(forKey: nsText) {
            return value.cgSizeValue
        } else {
            var size = nsText.size(withAttributes: attributes)

            let factor = Float(10)
            let width = ceilf(Float(size.width) * factor) / factor
            let height = ceilf(Float(size.height) * factor) / factor
            size.width = CGFloat(width)
            size.height = CGFloat(height)
            fontSizeCache.setObject(NSValue(cgSize: size), forKey: nsText)
            return size
        }
    }

    func createAnimations() {
        let duration: TimeInterval = animationDuration - (Double(numbersText.count) * durationOffset)
        var offset: TimeInterval = 0

        for scrollLayer in scrollLayers {
            guard let maxY = scrollLayer.sublayers?.last?.frame.origin.y else { return }
            scrollLayer.sublayerTransform = CATransform3DTranslate(CATransform3DIdentity, 0, -maxY, 0)

            let animation = CABasicAnimation(keyPath: "sublayerTransform.translation.y")
            animation.duration = duration + offset
            animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animation.isRemovedOnCompletion = false
            animation.fillMode = .forwards

            animation.fromValue = 0
            animation.toValue = -maxY

            scrollLayer.add(animation, forKey: kAnimationKey)
            offset += durationOffset

            beginAnimation()
            perform(#selector(finishAnimation), with: nil, afterDelay: animation.duration)
        }
    }

    func beginAnimation() {
        animatingCount += 1
    }

    @objc func finishAnimation() {
        animatingCount -= 1
        if animationsFinished {
            completeUpdate()
        }
    }

    func completeUpdate() {
        lastNumber = currentNumber
    }

    func formattedString(for number: Int) -> String? {
        guard let formattedString = formatter.string(from: NSNumber(value: number)) else {
            return nil
        }

        return formattedString
    }

    func reuseTextLayer(for text: String) -> ReuseTextLayer {
        let textLayer = reuseCache.dequeueReusableObject(with: reuseKey)
        textLayer.foregroundColor = self.textColor.cgColor

        let fontRef = CGFont(font.fontName as CFString)

        if let fontRef = fontRef {
            textLayer.font = fontRef
        }

        textLayer.fontSize = font.pointSize
        textLayer.alignmentMode = .center
        textLayer.string = text
        return textLayer
    }
}
