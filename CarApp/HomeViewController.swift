//
//  SearchCarViewController.swift
//  CarApp
//
//  Created by Marc Brown on 10/13/17.
//  Copyright © 2017 HackGT. All rights reserved.
//
import UIKit
import SceneKit
import ARKit
import Vision
import MapKit

class HomeViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet weak var learn_more_button: UIButton!
    
    
    // SCENE
    @IBOutlet var sceneView: ARSCNView!
    let bubbleDepth : Float = 0.01 // the 'depth' of 3D text
    var latestPrediction : String = "…" // a variable containing the latest CoreML prediction

    // COREML
    var visionRequests = [VNRequest]()
    let dispatchQueueML = DispatchQueue(label: "com.hw.dispatchqueueml") // A Serial Queue
    var carsScene = [String]()
    
    @IBOutlet weak var debugTextView: UITextView!

    
    @IBAction func viewCarDetails(_ sender: UIButton) {
//        self.performSegue(withIdentifier: "detailCarView", sender: nil)
      
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        print(self.latestPrediction)
        if segue.identifier == "detailCarView"{
            if let destinationViewController = segue.destination as? CarDetailViewController {
                destinationViewController.carName = self.latestPrediction
            }
        }
        
    }
    
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        learn_more_button.isHidden = true
        learn_more_button.layer.cornerRadius = 0.5 * learn_more_button.bounds.size.width
        learn_more_button.clipsToBounds = true
        
        // Set the view's delegate
        sceneView.delegate = self

        // Create a new scene
        let scene = SCNScene()

        // Set the scene to the view
        sceneView.scene = scene

        // Enable Default Lighting - makes the 3D text a bit poppier.
        sceneView.autoenablesDefaultLighting = true

        //////////////////////////////////////////////////
        // Tap Gesture Recognizer
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.handleTap(gestureRecognize:)))
        sceneView.addGestureRecognizer(tapGesture)
 
//         Set up Vision Model
                guard let selectedModel = try? VNCoreMLModel(for: CarRecognition().model) else { // (Optional) This can be replaced with other models on https://developer.apple.com/machine-learning/
                    fatalError("Could not load model. Ensure model has been drag and dropped (copied) to XCode Project from https://developer.apple.com/machine-learning/ . Also ensure the model is part of a target (see: https://stackoverflow.com/questions/45884085/model-is-not-part-of-any-target-add-the-model-to-a-target-to-enable-generation ")
                }
        
                // Set up Vision-CoreML Request
                let classificationRequest = VNCoreMLRequest(model: selectedModel, completionHandler: classificationCompleteHandler)
                classificationRequest.imageCropAndScaleOption = VNImageCropAndScaleOption.centerCrop // Crop from centre of images and scale to appropriate size.
                visionRequests = [classificationRequest]
        
                // Begin Loop to Update CoreML
                loopCoreMLUpdate()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        // Enable plane detection
        configuration.planeDetection = .horizontal

        // Run the view's session
        sceneView.session.run(configuration)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }

  

    // MARK: - ARSCNViewDelegate

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        DispatchQueue.main.async {
            // Do any desired updates to SceneKit here.
        }
    }
    

    // MARK: - Interaction
    @objc func handleTap(gestureRecognize: UITapGestureRecognizer) {
        // HIT TEST : REAL WORLD
        // Get Screen Centre
        let screenCentre : CGPoint = CGPoint(x: self.sceneView.bounds.midX, y: self.sceneView.bounds.midY)

        let arHitTestResults : [ARHitTestResult] = sceneView.hitTest(screenCentre, types: [.featurePoint]) // Alternatively, we could use '.existingPlaneUsingExtent' for more grounded hit-test-points.

        if let closestResult = arHitTestResults.first {
            // Get Coordinates of HitTest
            
            
            let transform : matrix_float4x4 = closestResult.worldTransform
            let worldCoord : SCNVector3 = SCNVector3Make(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)

            
            self.clearView()
            
            // Create 3D Text
            if latestPrediction.count > 0{
                self.learn_more_button.isHidden = false
                let node : SCNNode = createNewBubbleParentNode(latestPrediction)
                sceneView.scene.rootNode.addChildNode(node)
                
                
                node.position = worldCoord
            }
        }
        
        
        
    }
    
    
    
    func clearView(){
        sceneView.scene.rootNode.enumerateChildNodes { (node, stop) -> Void in
            node.removeFromParentNode()
        }
    }

    func createNewBubbleParentNode(_ text : String) -> SCNNode {
        // Warning: Creating 3D Text is susceptible to crashing. To reduce chances of crashing; reduce number of polygons, letters, smoothness, etc.
        
        // TEXT BILLBOARD CONSTRAINT
        let billboardConstraint = SCNBillboardConstraint()
        billboardConstraint.freeAxes = SCNBillboardAxis.Y

        // BUBBLE-TEXT
        let bubble = SCNText(string: text, extrusionDepth: CGFloat(bubbleDepth))
        var font = UIFont(name: "Futura", size: 0.15)
        font = font?.withTraits(traits: .traitBold)
        bubble.font = font
        bubble.alignmentMode = kCAAlignmentCenter
        bubble.firstMaterial?.diffuse.contents = UIColor.orange
        bubble.firstMaterial?.specular.contents = UIColor.white
        bubble.firstMaterial?.isDoubleSided = true
        // bubble.flatness // setting this too low can cause crashes.
        bubble.chamferRadius = CGFloat(bubbleDepth)

        // BUBBLE NODE
        let (minBound, maxBound) = bubble.boundingBox
        let bubbleNode = SCNNode(geometry: bubble)
        // Centre Node - to Centre-Bottom point
        bubbleNode.pivot = SCNMatrix4MakeTranslation( (maxBound.x - minBound.x)/2, minBound.y, bubbleDepth/2)
        // Reduce default text size
        bubbleNode.scale = SCNVector3Make(0.2, 0.2, 0.2)
        
        // CENTRE POINT NODE
        let sphere = SCNSphere(radius: 0.005)
        sphere.firstMaterial?.diffuse.contents = UIColor.cyan
        let sphereNode = SCNNode(geometry: sphere)
        
        // BUBBLE PARENT NODE
        let bubbleNodeParent = SCNNode()
        bubbleNodeParent.addChildNode(bubbleNode)
        bubbleNodeParent.addChildNode(sphereNode)
        bubbleNodeParent.constraints = [billboardConstraint]
        

        return bubbleNodeParent
    }

    // MARK: - CoreML Vision Handling
    
    func loopCoreMLUpdate() {
        // Continuously run CoreML whenever it's ready. (Preventing 'hiccups' in Frame Rate)

        dispatchQueueML.async {
            // 1. Run Update.
            self.updateCoreML()

            // 2. Loop this function.
            self.loopCoreMLUpdate()
        }

    }

    func classificationCompleteHandler(request: VNRequest, error: Error?) {
        // Catch Errors
        if error != nil {
            print("Error: " + (error?.localizedDescription)!)
            return
        }
        guard let observations = request.results else {
            print("No results")
            return
        }

        // Get Classifications
        let classifications = observations[0...1] // top 2 results
            .flatMap({ $0 as? VNClassificationObservation })
            .map({ "\($0.identifier) \(String(format:"- %.2f", $0.confidence))" })
            .joined(separator: "\n")

        
        DispatchQueue.main.async {
            // Print Classifications
        
            // Display Debug Text on screen
            var debugText:String = ""
            debugText += classifications
            self.debugTextView.text = debugText

            // Store the latest prediction
            var objectName:String = "…"
            objectName = classifications.components(separatedBy: "-")[0]
            let confidence  = classifications.components(separatedBy: "-")[1].components(separatedBy: "\n")[0]
            objectName = objectName.components(separatedBy: ",")[0]
            
           
            
            if let confidenceValue = Double(confidence.trimmingCharacters(in: CharacterSet.whitespaces)) {
                    self.latestPrediction = (confidenceValue > 0.6)  ? objectName : ""

            }
           
        
        }
    }
    
    func updateCoreML() {
        ///////////////////////////
        // Get Camera Image as RGB
        let pixbuff : CVPixelBuffer? = (sceneView.session.currentFrame?.capturedImage)
        if pixbuff == nil { return }
        let ciImage = CIImage(cvPixelBuffer: pixbuff!)
      

        ///////////////////////////
        // Prepare CoreML/Vision Request
        let imageRequestHandler = VNImageRequestHandler(ciImage: ciImage, options: [:])
  
 
        do {
            try imageRequestHandler.perform(self.visionRequests)
        } catch {
            print(error)
        }

    }
    
//    private func objectInteracting(with gesture: UIGestureRecognizer, in view: ARSCNView) -> VirtualObject? {
//        for index in 0..<gesture.numberOfTouches {
//            let touchLocation = gesture.location(ofTouch: index, in: view)
//
//            // Look for an object directly under the `touchLocation`.
//            if let object = sceneView.virtualObject(at: touchLocation) {
//                return object
//            }
//        }
//
//        // As a last resort look for an object under the center of the touches.
//        return sceneView.virtualObject(at: gesture.center(in: view))
//    }
}

extension UIFont {
    // Based on: https://stackoverflow.com/questions/4713236/how-do-i-set-bold-and-italic-on-uilabel-of-iphone-ipad
    func withTraits(traits:UIFontDescriptorSymbolicTraits...) -> UIFont {
        let descriptor = self.fontDescriptor.withSymbolicTraits(UIFontDescriptorSymbolicTraits(traits))
        return UIFont(descriptor: descriptor!, size: 0)
    }
}



