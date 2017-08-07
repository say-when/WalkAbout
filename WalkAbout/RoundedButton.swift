//
//  RoundedButton.swift
//  BoundsTest
//
//
// Taken from an example on stackoverflow.com: https://stackoverflow.com/a/38154358
// I modified the code to work with Swift 3 and to improve the way some of the 
// optionals stuff was being done, etc.
//
import UIKit

@IBDesignable
class RoundedButton:UIButton {
    
    @IBInspectable var borderWidth: CGFloat = 0 {
        didSet {
            layer.borderWidth = borderWidth
        }
    }
    //Normal state bg and border
    @IBInspectable var normalBorderColor: UIColor? {
        didSet {
            layer.borderColor = normalBorderColor?.cgColor
        }
    }
    
    @IBInspectable var normalBackgroundColor: UIColor? {
        didSet {
            setBgColorForState(color: normalBackgroundColor, forState: .normal)
        }
    }
    
    
    //Highlighted state bg and border
    @IBInspectable var highlightedBorderColor: UIColor?
    
    @IBInspectable var highlightedBackgroundColor: UIColor? {
        didSet {
            setBgColorForState(color: highlightedBackgroundColor, forState: .highlighted)
        }
    }
    
    
    private func setBgColorForState(color: UIColor?, forState: UIControlState){
        if let tmpColor = color {
            setBackgroundImage(UIImage.imageWithColor(color: tmpColor), for: forState)
            
        } else {
            setBackgroundImage(nil, for: forState)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        layer.cornerRadius = layer.frame.height / 2
        clipsToBounds = true
        
        if borderWidth > 0 {
            if let nColor = normalBorderColor, state == .normal, layer.borderColor != nColor.cgColor {
                layer.borderColor = nColor.cgColor
            } else if let hColor = highlightedBorderColor, state == .highlighted {
                layer.borderColor = hColor.cgColor
            }
        }
    }
    
}

//Extension Required by RoundedButton to create UIImage from UIColor
extension UIImage {
    class func imageWithColor(color: UIColor) -> UIImage? {
        let rect: CGRect = CGRect(x:0, y:0, width:1, height:1)
        UIGraphicsBeginImageContextWithOptions(CGSize(width:1, height:1), false, 1.0)
        color.setFill()
        UIRectFill(rect)
        let image: UIImage? = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
}
