
import Foundation
import UIKit

public class GameHelper: NSObject {
    
    public static let shared: GameHelper = GameHelper()
    
    private override init() {
        
    }

    private let kUserDefaultScoreKey = "best_score_breakout"
    
    public func loadBestScore() -> Int {
        return UserDefaults.standard.integer(forKey: kUserDefaultScoreKey)
    }
    
    public func setBestScore(score: Int) {
        UserDefaults.standard.set(score, forKey: kUserDefaultScoreKey)
        UserDefaults.standard.synchronize()
    }
    
}
