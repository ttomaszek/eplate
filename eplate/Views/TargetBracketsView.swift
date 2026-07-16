import UIKit

// A custom view that draws the target bracket animations
class TargetBracketsView: UIView {
    // MARK: - Properties
    private var isLocked: Bool = false
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        startPulseAnimation()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - View Lifecycle & Drawing
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        // Define colors based on lock state (Green when locking on, Blue otherwise)
        let strokeColor = isLocked ?
            UIColor(red: 52/255, green: 199/255, blue: 89/255, alpha: 0.95).cgColor :
            UIColor(red: 0.0, green: 0.45, blue: 0.95, alpha: 0.95).cgColor
            
        context.setStrokeColor(strokeColor)
        context.setLineWidth(isLocked ? 3.5 : 3.0) // Slightly thicker stroke when locked
        context.setLineCap(.round)
        
        let length: CGFloat = 24
        let radius: CGFloat = 16
        
        let minX = rect.minX + 1.5
        let maxX = rect.maxX - 1.5
        let minY = rect.minY + 1.5
        let maxY = rect.maxY - 1.5
        
        // Top-Left corner
        context.move(to: CGPoint(x: minX, y: minY + length))
        context.addArc(tangent1End: CGPoint(x: minX, y: minY), tangent2End: CGPoint(x: minX + length, y: minY), radius: radius)
        context.addLine(to: CGPoint(x: minX + length, y: minY))
        
        // Top-Right corner
        context.move(to: CGPoint(x: maxX - length, y: minY))
        context.addArc(tangent1End: CGPoint(x: maxX, y: minY), tangent2End: CGPoint(x: maxX, y: minY + length), radius: radius)
        context.addLine(to: CGPoint(x: maxX, y: minY + length))
        
        // Bottom-Right corner
        context.move(to: CGPoint(x: maxX, y: maxY - length))
        context.addArc(tangent1End: CGPoint(x: maxX, y: maxY), tangent2End: CGPoint(x: maxX - length, y: maxY), radius: radius)
        context.addLine(to: CGPoint(x: maxX - length, y: maxY))
        
        // Bottom-Left corner
        context.move(to: CGPoint(x: minX + length, y: maxY))
        context.addArc(tangent1End: CGPoint(x: minX, y: maxY), tangent2End: CGPoint(x: minX, y: maxY - length), radius: radius)
        context.addLine(to: CGPoint(x: minX, y: maxY - length))
        
        context.strokePath()
    }
    
    // MARK: - Actions / Helper Methods
    
    func setLockState(isLocked: Bool, animated: Bool = true) {
        guard self.isLocked != isLocked else { return }
        self.isLocked = isLocked
        
        // Redraw corner strokes with the correct color
        setNeedsDisplay()
        
        // Inset/Contract corners slightly when locked to indicate target compression
        let targetTransform = isLocked ? CGAffineTransform(scaleX: 0.92, y: 0.90) : CGAffineTransform(scaleX: 1.0, y: 1.0)
        
        if animated {
            layer.removeAllAnimations()
            UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseInOut, .beginFromCurrentState], animations: {
                self.transform = targetTransform
            }) { _ in
                if !isLocked {
                    self.startPulseAnimation()
                }
            }
        } else {
            layer.removeAllAnimations()
            self.transform = targetTransform
            if !isLocked {
                startPulseAnimation()
            }
        }
    }
    
    private func startPulseAnimation() {
        transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
        UIView.animate(withDuration: 1.2, delay: 0, options: [.repeat, .autoreverse, .allowUserInteraction], animations: {
            self.transform = CGAffineTransform(scaleX: 1.02, y: 1.04)
        }, completion: nil)
    }
}
