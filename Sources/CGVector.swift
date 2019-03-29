
import SpriteKit

public extension CGVector {
    
    var length: CGFloat {
        return sqrt(dx * dx + dy * dy)
    }
    
    mutating func extend(by ratio: CGFloat) {
        self.dx *= ratio
        self.dy *= ratio
    }
    
}
