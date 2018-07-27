import UIKit
import MetalKit

var histogram = Histogram()
var control = Control()
var undoControl1 = Control()
var undoControl2 = Control()
var showAxesFlag = true
var paceRotate = CGPoint()
var hv:HistogramView! = nil
var gDevice: MTLDevice!
let bulb = Bulb()
var camera:float3 = float3(0,0,170)
var vc:ViewController! = nil

let JULIA_FORMULA = 5
let BOX_FORMULA = 6

class ViewController: UIViewController, WGDelegate {
    @IBOutlet var mtkViewL: MTKView!
    @IBOutlet var mtkViewR: MTKView!
    @IBOutlet var wg: WidgetGroup!
    @IBOutlet var histogramView: HistogramView!
    
    var rendererL: Renderer!
    var rendererR: Renderer!
    
    var pointSizeIndex:Int = 1
    var cloudCountIndex:Int = 0
    var controlColorRange = Float()
    var controlColorOffset = Float()
    var controlCenter = Float()
    var controlSpread = Float()
    var stereoFlag:Bool = false

    //MARK:-

    override func viewDidLoad() {
        super.viewDidLoad()
        vc = self

        gDevice = MTLCreateSystemDefaultDevice()
        mtkViewL.device = gDevice
        mtkViewR.device = gDevice
        
        guard let newRenderer = Renderer(metalKitView: mtkViewL, 0) else { fatalError("Renderer cannot be initialized") }
        rendererL = newRenderer
        rendererL.mtkView(mtkViewL, drawableSizeWillChange: mtkViewL.drawableSize)
        mtkViewL.delegate = rendererL

        guard let newRenderer2 = Renderer(metalKitView: mtkViewR, 1) else { fatalError("Renderer cannot be initialized") }
        rendererR = newRenderer2
        rendererR.mtkView(mtkViewR, drawableSizeWillChange: mtkViewR.drawableSize)
        mtkViewR.delegate = rendererR

        hv = histogramView
        layoutViews()

        Timer.scheduledTimer(withTimeInterval:0.01, repeats:true) { timer in self.paceTimerHandler() }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        vc = self
        wg.delegate = self
        wg.initialize()
        initializeWidgetGroup()
        reset()
        bulb.newBusy(.calc)
    }
    
    //MARK: -
    
    let eOptions:[String] = [ "Bulb 1","Bulb 2","Bulb 3","Bulb 4","Bulb 5","Julia","Box" ]
    let pOptions:[String] = [ "PtSz 1","PtSz 2","PtSz 4","PtSz 8" ]
    let cOptions:[String] = [ "#Clouds 1","#Clouds 2","#Clouds 4" ]
    var chgScale:Float = 1

    func initializeWidgetGroup() {
        wg.reset()
        wg.addOptionSelect(1,"Equation","Select Equation Type",eOptions);
        
        if control.formula < JULIA_FORMULA { // bulbs
            wg.addSingleFloat(&control.power,2,12,1,"Power",.power)
        }
        
        wg.addLine()
        wg.addColor(1,Float(RowHT)); wg.addSingleFloat(&control.basex, -5,5,0.1, "Red",  .cageXYZ)
        wg.addColor(2,Float(RowHT)); wg.addSingleFloat(&control.basey, -5,5,0.1, "Green",.cageXYZ)
        
        if control.formula != JULIA_FORMULA {
            wg.addColor(3,Float(RowHT)); wg.addSingleFloat(&control.basez, -5,5,0.1, "Blue", .cageXYZ)
        }
        
        wg.addSingleFloat(&chgScale,0.99,1.01,0.05,"Scale", .cageScale)
        wg.addCommand("Show Axes",.showAxes)
        wg.addLine()
        wg.addOptionSelect(2,"Point Size","Select Point Size",pOptions);
        wg.addOptionSelect(3,"Cloud Count","Select # Overlapping Clouds",cOptions);
        
        wg.addLine()        
        histogramView.frame = CGRect(x:5, y:wg.nextYCoord()+2, width:wgWidth-10, height:44)
        view.bringSubview(toFront:histogramView)
        
        wg.addGap(30)
        wg.addSingleFloat(&controlCenter,0,40,2,"Center",.histo)
        wg.addSingleFloat(&controlSpread,0,10,2,"Spread",.histo)
        wg.addString("",1)
        
        wg.addLine()
        wg.addDualFloat(&controlColorRange,&controlColorOffset,0,256,50,"Color",.color)
        wg.addCommand("Palette",.palette)
        wg.addLine()
        
        if control.formula == JULIA_FORMULA {
            wg.addLegend("Julia")
            wg.addDualFloat(UnsafeMutableRawPointer(&control.re1),  UnsafeMutableRawPointer(&control.re2), -4,4,1,"Real", .juliaBox)
            wg.addDualFloat(UnsafeMutableRawPointer(&control.im1),  UnsafeMutableRawPointer(&control.im2), -4,4,1,"Imag", .juliaBox)
            wg.addDualFloat(UnsafeMutableRawPointer(&control.mult1),UnsafeMutableRawPointer(&control.mult2),-3,3, 0.25,"Mult", .juliaBox)
            wg.addDualFloat(UnsafeMutableRawPointer(&control.zoom1),UnsafeMutableRawPointer(&control.zoom2),20,500,100,"Zoom", .juliaBox)
            wg.addLine()
        }
        
        if control.formula == BOX_FORMULA {
            wg.addLegend("Box")
            wg.addDualFloat(UnsafeMutableRawPointer(&control.re1),UnsafeMutableRawPointer(&control.im1),0.1,4, 0.3,"B Fold", .juliaBox)
            wg.addDualFloat(UnsafeMutableRawPointer(&control.mult1),UnsafeMutableRawPointer(&control.zoom1),0.1,4, 0.3,"S Fold", .juliaBox)
            wg.addDualFloat(UnsafeMutableRawPointer(&control.re2),UnsafeMutableRawPointer(&control.im2),0.1,10, 1,"Scale", .juliaBox)
            wg.addLine()
        }

        wg.addCommand("Reset",.reset)
        wg.addCommand("Undo",.undo)
        wg.addCommand("Smooth 1",.smooth)
        wg.addCommand("Smooth 2",.smooth2)
        wg.addCommand("Quant  1",.quant)
        wg.addCommand("Quant  2",.quant2)
        wg.addCommand("Stereo",.stereo)
        wg.addCommand("Save/Load",.saveLoad)
        wg.addCommand("Help",.help)
        wg.addLine()
        wg.setNeedsDisplay()
    }

    //MARK: -
    
    func wgCommand(_ cmd:CmdIdent) {
        switch(cmd) {
        case .reset :
            reset()
            bulb.newBusy(.calc)
        case .undo :
            control = undoControl2
            control.hop = 1
            bulb.newBusy(.calc)
        case .cageXYZ  :
            showAxesFlag = true
            bulb.calcCages()
        case .changeEnd, .power :
            control.hop = 1
            bulb.newBusy(.calc)
        case .palette :
            bulb.loadNextColorMap()
            bulb.newBusy(.vertices)
        case .color :
            updateRenderColor()
            bulb.newBusy(.vertices)
        case .histo :
            updateControlCenter()
            bulb.newBusy(.vertices)
        case .juliaBox :
            bulb.fastCalc()
        case .smooth   : bulb.smoothData()
        case .smooth2  : bulb.smoothData2()
        case .quant    : bulb.quantizeData()
        case .quant2   : bulb.quantizeData2()
        case .showAxes : showAxesFlag = !showAxesFlag
        case .stereo   :
            stereoFlag = !stereoFlag
            layoutViews()
        case .cageScale: changeScale(control.scale * chgScale)
        case .saveLoad : performSegue(withIdentifier: "saveLoadSegue", sender: self)
        case .help     : performSegue(withIdentifier: "helpSegue", sender: self)
        default : break
        }
        
        wg.setNeedsDisplay()
    }
    
    func wgGetString(_ index:Int) -> String {
        switch(index) {
        case 1  :
            let numberFormatter = NumberFormatter()
            numberFormatter.numberStyle = NumberFormatter.Style.decimal
            return numberFormatter.string(from: NSNumber(value:vCount))!
        default : return "unused"
        }
    }
    
    func wgGetColor(_ index:Int) -> UIColor {
        switch(index) {
        case 1  : return UIColor(red:0.4, green:0.2, blue:0.2, alpha: 1)
        case 2  : return UIColor(red:0.2, green:0.4, blue:0.2, alpha: 1)
        case 3  : return UIColor(red:0.2, green:0.2, blue:0.4, alpha: 1)
        default : return .black
        }
    }
    
    func wgGetOptionString(_ ident:Int) -> String {
        switch(ident) {
        case 1 : return eOptions[Int(control.formula)]
        case 2 : return pOptions[pointSizeIndex]
        case 3 : return cOptions[cloudCountIndex]
        default : return "noOption"
        }
    }
        
    func wgOptionSelected(_ ident:Int, _ index:Int) { // callback from popup
        switch(ident) {
        case 1 :    // formula
            control.formula = Int32(index)
            initializeWidgetGroup()
            
            switch(index) {
            case JULIA_FORMULA :
                control.re1 = -2.17020011
                control.re2 = -0.0822001174
                control.im1 = 0.534700274
                control.im2 = -1.15230012
                control.mult1 = 1.42700005
                control.mult2 = 1.3253746
                control.zoom1 = 189.199997
                control.zoom2 = 211.949921
            case BOX_FORMULA :
                control.re1 = 1.671
                control.im1 = 0.7316
                control.mult1 = 1.6804
                control.zoom1 = 1.266
                control.re2 = 2.4677
                control.im2 = 2.52
            default : break
            }

            bulb.newBusy(.calc)
            
        case 2 :    // pointsize
            pointSizeIndex = index
            updateRenderPointSize()
        case 3 :    // cloud count
            cloudCountIndex = index
            updateRenderCloudCount()
            bulb.newBusy(.calc)
        default : break
        }
    }
    
    func changeScale(_ ns:Float) {
        let sMin:Float = 0.00001
        let sMax:Float = 0.07
        let cc = Float(WIDTH)/2
        let q1 = control.scale * cc
        
        var centerx = control.basex
        var centery = control.basey
        var centerz = control.basez
        centerx += q1
        centery += q1
        centerz += q1
        
        control.scale = ns
        if control.scale < sMin { control.scale = sMin } else if control.scale > sMax { control.scale = sMax }
        
        let q2 = control.scale * cc
        control.basex = centerx - q2
        control.basey = centery - q2
        control.basez = centerz - q2
        
        bulb.calcCages()
    }

    //MARK: -
    
    var wgWidth:CGFloat = 0
    
    @objc func layoutViews() {
        let xs:CGFloat = view.bounds.width
        let ys:CGFloat = view.bounds.height

        wgWidth = wg.isHidden ? 0 : 120
        let vxs = xs - wgWidth

        if !wg.isHidden { wg.frame = CGRect(x:0, y:0, width:wgWidth, height:view.bounds.height) }
        
        histogramView.isHidden = wg.isHidden
        
        if stereoFlag {
            mtkViewR.isHidden = false
            mtkViewL.frame = CGRect(x:wgWidth, y:0, width:vxs/2, height:ys)
            mtkViewR.frame = CGRect(x:wgWidth + vxs/2, y:0, width:vxs/2, height:ys)
        }
        else {
            mtkViewR.isHidden = true
            mtkViewL.frame = CGRect(x:wgWidth, y:0, width:vxs, height:ys)
        }

        viewCenter.x = mtkViewL.frame.width/2
        viewCenter.y = mtkViewL.frame.height/2
        arcBall.initialize(Float(mtkViewL.frame.width),Float(mtkViewL.frame.height))
    }
    
    //MARK:-

    var viewCenter = CGPoint()

    func rotate(_ pt:CGPoint) {
        arcBall.mouseDown(viewCenter)
        arcBall.mouseMove(CGPoint(x:viewCenter.x + pt.x, y:viewCenter.y + pt.y))
    }

    @objc func paceTimerHandler() {
        _ = wg.update()
        rotate(paceRotate)
    }
    
    //MARK:-

    func controlLoaded() {      // just loaded a saved Control file
        initializeWidgetGroup()
        bulb.newBusy(.calc)
    }
    
    func updateRenderPointSize() {
        let pList:[Float] = [ 1,2,4,8 ]
        pointSize = pList[pointSizeIndex]
    }

    func updateRenderCloudCount() {
        let cList:[Int] = [ 1,2,4 ]
        cloudCount = cList[cloudCountIndex]
    }

    func updateRenderColor() {
        control.range = Int32(controlColorRange)
        control.offset = Int32(controlColorOffset)
    }
    
    func updateControlCenter() {
        control.center = Int32(controlCenter)
        control.spread = Int32(controlSpread)
    }
    
    func reset() {
        control.basex = 0
        control.basey = 0
        control.basez = 0
        control.scale = 0.01
        control.power = 8
        control.re1 = 1
        control.im1 = 1
        control.mult1 = 1.9
        control.zoom1 = 740
        control.re2 = 0
        control.im2 = 0
        control.mult2 = 0
        control.zoom2 = 0
        
        control.formula = 0
        control.hop = 1
        control.center = 5
        control.spread = 2
        control.offset = 64
        control.range = 128
        control.cloudIndex = 0

        bulb.reset();
        undoControl1 = control
        undoControl2 = control

        pointSizeIndex = 1
        updateRenderPointSize()
        
        cloudCountIndex = 0
        updateRenderCloudCount()
        
        controlColorRange = 128
        controlColorOffset = 128
        updateRenderColor()

        controlCenter = 10
        controlSpread = 2
        updateControlCenter()
        
        camera = float3(0,0,170)
    }
    
    //MARK:-

    let xRange = float2(-100,100)
    let yRange = float2(-100,100)
    let zRange = float2(50,2000)
    let rRange = float2(-3,3)
    
    var oldPt = CGPoint()
    
    @IBAction func panGesture(_ sender: UIPanGestureRecognizer) {
        var pt = sender.translation(in: self.view)
        
        switch sender.state {
        case .began :
            oldPt = pt
        case .changed :
            pt.x -= oldPt.x
            pt.y -= oldPt.y
            wg.focusMovement(pt)
        case .ended :
            wg.focusMovement(CGPoint()) // 0,0 == stop auto change
        default : break
        }
    }

    @IBAction func pan2Gesture(_ sender: UIPanGestureRecognizer) {
        let pt = sender.translation(in: self.view)
        let scale:Float = 0.01
        paceRotate.x = CGFloat(fClamp(Float(pt.x) * scale, rRange))
        paceRotate.y = CGFloat(fClamp(Float(pt.y) * scale, rRange))
    }

    @IBAction func pan3Gesture(_ sender: UIPanGestureRecognizer) {
        let pt = sender.translation(in: self.view)
        let den = 30 * control.scale / 0.008
        camera.x = fClamp(camera.x + Float(pt.x) / den, xRange)
        camera.y = fClamp(camera.y - Float(pt.y) / den, xRange)
    }

    @IBAction func pinchGesture(_ sender: UIPinchGestureRecognizer) {
        let scale = Float(1 + (1-sender.scale) / 10 )
        camera.z = fClamp(camera.z * scale,zRange)
    }

    @IBAction func tapGesture(_ sender: UITapGestureRecognizer) { paceRotate.x = 0; paceRotate.y = 0 }
    
    @IBAction func tap2Gesture(_ sender: UITapGestureRecognizer) {
        wg.isHidden = !wg.isHidden
        layoutViews()
    }
    
    override var prefersStatusBarHidden: Bool { return true }
}

func fClamp(_ v:Float, _ range:float2) -> Float {
    if v < range.x { return range.x }
    if v > range.y { return range.y }
    return v
}


