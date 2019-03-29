import SpriteKit
import UIKit
import ARKit
import CoreImage
import PlaygroundSupport
import AVFoundation

/*:
 # By Ferdinand Loesch
 ## Face Breakout
 Face breakout makes use of ` SpriteKit`, `CIDetector`, `UIKit` and `ARKit`  to create an accessible game for everyone.  By leveraging CIDetector Face Tracking for gameplay, that does not require physical actions to play it. My source of inspiration comes from the desire to create apps that improve peoples lives.
 Playing dynamic games, such as Breakout is not particularly easy for people who are paraplegic.
 Therefore, I got inspired to solve this problem by using Face Tracking to dynamically track the direction in which the user looks at for   pedal control.
 
 ----
 # How to play!
 #### Important hold the device landscape to ensure face tracking works correctly.
 Use your head motion such as looking left or right to control the pedal on the screen. With the goal being to remove as many blocks as possible! Try cracking your High Score and most importantly, have fun playing!

 
 ### Setup The Game Scene🔧
 
 */


class GameScene: SKScene {
    
    // computed property to set up game state
    var gameState: GameState = .new {
        didSet {
            switch gameState {
            case .new:
                resetGame()
            case .running:
                blocksNeedToBeDisplayed.forEach { self.addChild($0) }
                blocksNeedToBeDisplayed.removeAll()
            default:
                break
            }
        }
    }

    // default Ball  impulse and Radius
    private var kBallImpulse    : CGFloat = 30.0
    private var kBallRadius     : CGFloat = 12.0
    
    // setup note names
    private let kBallNodeName   = "Ball"
    private let kPaddleNodeName = "Paddle"
    private let kBlockNodeName  = "Block"
    private let kScoreNodeName  = "ScoreLabel"
    private let kBestNodeName   = "BestLabel"
    
    // assigning properties with category bit mask values which we use to dentify which node has collided with which
    private let kBallCategory   : UInt32 = 0x1 << 0
    private let kBottomCategory : UInt32 = 0x1 << 1
    private let kBlockCategory  : UInt32 = 0x1 << 2
    private let kPaddleCategory : UInt32 = 0x1 << 3
    private let kBorderCategory : UInt32 = 0x1 << 4
    private let kHiddenCategory : UInt32 = 0x1 << 5
    

/*:

    change the values to change their appearances of the bricks such as their size and the number of rows and columns
     */
    private let kBlockWidth             : CGFloat = 90.0
    private let kBlockHeight            : CGFloat = 25.0
    private let kBlockRows              : Int = 8
    private let kBlockColumns           : Int = 8
    private var kBlockRecoverTime = 10.0
    
    
    private var velocityDx              : CGFloat = 0.0
    private var velocityDy              : CGFloat = 0.0
    private var initialVelocityLength   : CGFloat = 0.0
    private var velocityRatio           : CGFloat {
        return (ball.physicsBody?.velocity.length)! / initialVelocityLength
    }
    
    // containing all Collider kBricks
    private var blocksNeedToBeDisplayed: [SKSpriteNode] = []
    
    fileprivate var paddle      : SKSpriteNode!
    fileprivate var ball        : SKSpriteNode!
    fileprivate var bestLabel   : SKLabelNode!
    fileprivate var scoreLabel  : SKLabelNode!
    fileprivate var currentScore: Int = 0 {
        didSet {
            scoreLabel.text = "\(currentScore)"
            if currentScore > GameHelper.shared.loadBestScore() {
                GameHelper.shared.setBestScore(score: currentScore)
                bestLabel.text = "Best: \(currentScore)"
            }
            
            // increase velocity with score
            if currentScore > 0 {
                let currentVelocity = ball.physicsBody?.velocity.length ?? initialVelocityLength
                let velocityRatio: CGFloat = 1.0 + 5.0 / currentVelocity
                ball.physicsBody?.velocity.extend(by: velocityRatio)
            }
        }
    }
    
    fileprivate var halfScreenWidth: CGFloat {
        return (scene?.size.width)! / 2
    }
    fileprivate var halfPaddleWidth: CGFloat {
        return (paddle?.size.width)! / 2
    }

    
    private var removedBlocks = Set<SKSpriteNode>()
    
    
    // function to reset game
    private func resetGame() {
        scoreLabel.text = "Press the screen to start"
        scoreLabel.fontSize = 60.0
        ball.run(SKAction.move(to: CGPoint(x: 0.0, y: -150.0), duration: 0.0))
        ball.physicsBody?.velocity = .zero
        velocityDx = 0.0
        velocityDy = 0.0
        removedBlocks.forEach { self.addChild($0) }
        removedBlocks.removeAll()
    }
    // function to start gameplay
    func startGame(){
        currentScore = 0
        scoreLabel.fontSize = 150.0
        ball.physicsBody!.applyImpulse(CGVector(dx: kBallImpulse, dy: kBallImpulse))
        initialVelocityLength = (ball.physicsBody?.velocity.length)!
    }
    

/*:
     this method is called when the view did move to view  we do our initial game set up here:
     */
    
    override func didMove(to view: SKView) {
        // background
        self.backgroundColor = #colorLiteral(red: 0.06881620735, green: 0.09872398525, blue: 0.1908445656, alpha: 1)
        // Label
        scoreLabel = childNode(withName: kScoreNodeName) as! SKLabelNode
        bestLabel = childNode(withName: kBestNodeName) as! SKLabelNode
        bestLabel.text = "Best: \(GameHelper.shared.loadBestScore())"
        // Border
        let rectPath = CGPath(rect: self.frame, transform: nil)
        let borderBody = SKPhysicsBody(edgeLoopFrom: rectPath)
        view.frame = rectPath.boundingBoxOfPath
        borderBody.friction = 0
        borderBody.restitution = 1
        borderBody.usesPreciseCollisionDetection = true
        self.physicsBody = borderBody
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self
        // Ball
        ball = childNode(withName: kBallNodeName) as! SKSpriteNode
        ball.physicsBody?.usesPreciseCollisionDetection = true
        let trailNode = SKNode()
        trailNode.zPosition = 1
        addChild(trailNode)
        let trail = SKEmitterNode(fileNamed: "BallTrail")!
        trail.targetNode = trailNode
        ball.addChild(trail)
        // Bottom
        let bottomRect = CGRect(x: frame.origin.x, y: frame.origin.y, width: frame.size.width, height: kBallRadius)
        let bottom = SKNode()
        bottom.physicsBody = SKPhysicsBody(edgeLoopFrom: bottomRect)
        addChild(bottom)
        // Paddle
        paddle = childNode(withName: kPaddleNodeName) as! SKSpriteNode
        
        // Blocks
        let totalBlocksWidth = kBlockWidth * CGFloat(kBlockColumns)
        let xOffset = -totalBlocksWidth / 2
        let yOffset = frame.height * 0.1
        for i in 0..<kBlockRows {
            for j in 0..<kBlockColumns {
                let block = SKSpriteNode(color: UIColor.blockColors()[(i + j + 1) % kBlockColumns],
                                         size: CGSize(width: kBlockWidth, height: kBlockHeight))
                block.position = CGPoint(x: xOffset + CGFloat(CGFloat(j) + 0.5) * kBlockWidth,
                                         y: yOffset + CGFloat(CGFloat(i) + 0.5) * kBlockHeight)
                block.physicsBody = SKPhysicsBody(rectangleOf: block.frame.size)
                block.physicsBody!.allowsRotation = false
                block.physicsBody!.friction = 0.0
                block.physicsBody!.affectedByGravity = false
                block.physicsBody!.isDynamic = false
                block.name = kBlockNodeName
                block.physicsBody!.categoryBitMask = kBlockCategory
                block.zPosition = 2
                addChild(block)
            }
        }
        
        // BitMasks
        bottom.physicsBody!.categoryBitMask = kBottomCategory
        ball.physicsBody!.categoryBitMask   = kBallCategory
        paddle.physicsBody!.categoryBitMask = kPaddleCategory
        borderBody.categoryBitMask          = kBorderCategory
        ball.physicsBody!.contactTestBitMask = kBottomCategory | kBlockCategory
        
        childNode(withName: "Corners")?.children.forEach {
            $0.physicsBody?.categoryBitMask = kBorderCategory
        }
        
        resetGame()
    }
    

/*:
     function called every frame  we check  if the game is still running and  ensure that the ball is not moving to slow or is just moving horizontally left and right as both of the scenarios could disturb gameplay
     */
    override func update(_ currentTime: TimeInterval) {
        // handle keyboard events
        if gameState == .running {
            
            // if too slow...
            if velocityRatio < 1.0 {
                ball.physicsBody?.velocity.extend(by: 1 / velocityRatio)
            }
            
            // if too horizontal...
            if fabs(Double((ball.physicsBody?.velocity.dy)!)) < 20 {
                ball.physicsBody?.applyImpulse(CGVector(dx: 0, dy: 1))
            }
        }
    }
/*:
     here we play the breaking animation/particle emission when we destroyed a brick
 */
    
    private func breakBlock(node: SKNode) {
        let particles = SKEmitterNode(fileNamed: "BrokenPlatform.sks")!
        particles.position = node.position
        particles.zPosition = 3
        addChild(particles)
        particles.run(SKAction.sequence([SKAction.wait(forDuration: 1.0),
                                         SKAction.removeFromParent()]))
        let anotherNode: SKSpriteNode = node as! SKSpriteNode
        node.removeFromParent()
        removedBlocks.insert(anotherNode)
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + kBlockRecoverTime) {
            if self.gameState == .running {
                if self.removedBlocks.contains(anotherNode) {
                    self.removedBlocks.remove(anotherNode)
                    self.addChild(anotherNode)
                }
            } else if self.gameState == .paused {
                self.blocksNeedToBeDisplayed.append(contentsOf: self.removedBlocks)
                self.removedBlocks.removeAll()
            }
        }
    }
/*:
     
       function called when user touches screen  to start gameplay
     
     */
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if gameState == .new {
            startGame()
        }
    }
    /*:
        animate and smooth pebble movement
     */
    public func movePadel(x: CGFloat){
        paddle.run(SKAction.move(to: CGPoint(x: x, y: paddle.position.y), duration: 0.2))
    }
    
}

/*:

   here we do all the cool fun physics stuff 🤓 such as detecting collisions and acting accordingly on them
 */
extension GameScene: SKPhysicsContactDelegate {
    
    func didBegin(_ contact: SKPhysicsContact) {
        var firstBody: SKPhysicsBody
        var secondBody: SKPhysicsBody
        
        if contact.bodyA.categoryBitMask < contact.bodyB.categoryBitMask {
            firstBody = contact.bodyA
            secondBody = contact.bodyB
        } else {
            firstBody = contact.bodyB
            secondBody = contact.bodyA
        }
        
        if firstBody.categoryBitMask == kBallCategory && secondBody.categoryBitMask == kBottomCategory {
            gameState = .new
            return
        }
        
        if firstBody.categoryBitMask == kBallCategory && secondBody.categoryBitMask == kBlockCategory {
            breakBlock(node: secondBody.node!)
            currentScore += 1
        }
    }
    
}

/*:

 # And now For the final phase magic setup🎉🎉😊
 */





/*:

   This View controller will contain all the logic to display the game scene as well as handle the facial recognition
 */
class ViewController: UIViewController {
    //  setup a camera view
    var sceneView: ARSCNView!
    //  setup game Scene View
    let game = GameScene(fileNamed: "GameScene")
    
    /*:
      hear we said the  default view of the view controller to a SKView
     */
    override func loadView() {
        self.view = SKView()
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // initialise the ARSCNView
        sceneView = ARSCNView(frame: CGRect(x: 0, y: 0, width: self.view.bounds.width, height: self.view.bounds.height))
        //force casting or view to a SKView it  will always succeed as in the previous step we have declared  the view to a SKView so force unwrapping should not cause a crash
        let skView = view as! SKView
        if let scene = game {
            // Set the scale mode to aspectFit to fit the window
            scene.scaleMode = .aspectFit
            // Present the scene
            skView.presentScene(scene)
        }
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
/*:
    initialising are ARFaceTrackingConfiguration unfortunately true depth data is not available in Swift playgrounds.
    therefore I make use of the ICdetector rather than using ARkits face tracking methods
    only grab the video buffer from the AR session
         */
        let configuratio = ARFaceTrackingConfiguration()
        sceneView.session.run(configuratio)
        
        //  start the face detection 0.8 seconds after the View has appeared i do this to avoid race conditions
        _ = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false, block: { (_) in
            self.detect()
        })
    }
    
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }
    
/*:
    Now to the cool stuff here we grab the pixel buffer from the current AR session converted into a CIimage and run the face detection method.
     */
    func detect() {
        let pixbuff : CVPixelBuffer? = (self.sceneView.session.currentFrame?.capturedImage)
        if pixbuff == nil { return }
        let personciImage = CIImage(cvPixelBuffer: pixbuff!)
        let options: [String : Any] = [CIDetectorAccuracy: CIDetectorAccuracyHigh,CIDetectorImageOrientation: 1,     CIDetectorSmile: true, CIDetectorEyeBlink: true, CIDetectorTracking: true]
        let faceDetector = CIDetector(ofType: CIDetectorTypeFace, context: nil, options: options)
        let faces = faceDetector!.features(in: personciImage)
        
        for face in faces as! [CIFaceFeature] {
/*:
    grab the mouth position then we multiply to increase the sensitivity and finally at the offset so that the panel is in the centre of the screen.
             */
          
            self.game?.movePadel(x: (face.mouthPosition.x * 2.5) - 2500 )
        }
        
        // Recalling the function after 0.1 seconds to continuously update the pedal position
        _ = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false, block: { (_) in
            self.detect()
            
        })
    }
    
    
    
}


//  and are view to the playground
PlaygroundPage.current.liveView = ViewController()
// now all we have to do is set the execution mode of the  playground to indefinite
PlaygroundPage.current.needsIndefiniteExecution = true
/*:

 # Done! 🚀 🌍 🚀

 */
