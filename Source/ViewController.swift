import UIKit
import MetalKit

var histogram = Histogram()
var control = Control()
var undoControl1 = Control()
var undoControl2 = Control()
var showAxesFlag = true
var paceRotate = CGPoint()
var gDevice: MTLDevice!
let bulb = Bulb()
var camera:float3 = float3(0,0,170)
var vc:ViewController! = nil

let oeOptions:[String] = [ "Half Tet1","Half Tet2","Full Tet","Cubic","half Octa","Full Octa","Kaleido" ]

class ViewController: UIViewController, WGDelegate {
    @IBOutlet var mtkViewL: MTKView!
    @IBOutlet var mtkViewR: MTKView!
    
    var wg:WidgetGroup! = nil
    var hv:HistogramView! = nil
    var pm:PColorView! = nil
    var tv:UITextView! = nil
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
        setControlPointer(&control)
        
        vc = self
        wg = WidgetGroup();     view.addSubview(wg)
        pm = PColorView();      view.addSubview(pm)
        hv = HistogramView();   view.addSubview(hv)
        tv = UITextView();      view.addSubview(tv)
        
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
        
        Timer.scheduledTimer(withTimeInterval:0.01, repeats:true) { timer in self.paceTimerHandler() }
        
        let swipeUp = UISwipeGestureRecognizer(target: self, action: #selector(self.handleGesture(gesture:)))
        swipeUp.direction = .up
        self.view.addGestureRecognizer(swipeUp)
        
        let swipeDown = UISwipeGestureRecognizer(target: self, action: #selector(self.handleGesture(gesture:)))
        swipeDown.direction = .down
        self.view.addGestureRecognizer(swipeDown)
        
        view.bringSubviewToFront(tv)
        tv.backgroundColor = .clear
        tv.textColor = .white
        tv.text = ""
        tv.isHidden = true
        tv.isEditable = false
        tv.isSelectable = false
        tv.isUserInteractionEnabled = false
        
        pm.initialize()
        layoutViews()
    }
    
    @objc func handleGesture(gesture: UISwipeGestureRecognizer) -> Void {
        switch gesture.direction {
        case .up : wg.moveFocus(-1)
        case .down : wg.moveFocus(+1)
        default : break
        }
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
    
    let eOptions:[String] = [ "Bulb 1","Bulb 2","Bulb 3","Bulb 4","Bulb 5","Julia","Box","Q Julia","IFS","Apollonian" ]
    let pOptions:[String] = [ "PtSz 1","PtSz 2","PtSz 4","PtSz 8" ]
    let cOptions:[String] = [ "#Clouds 1","#Clouds 2","#Clouds 4" ]
    var chgScale:Float = 1
    
    func initializeWidgetGroup() {
        wg.reset()
        wg.addOptionSelect(1,"Equation","Select Equation Type",eOptions);
        
        if control.formula < JULIA { // bulbs
            wg.addSingleFloat(&control.power,2,12,1,"Power",.power)
        }
        
        wg.addLine()
        let v1:Float = -8, v2:Float = 8, v3:Float = 0.3
        wg.addColor(1,Float(RowHT)); wg.addSingleFloat(&control.basex,v1,v2,v3, "Red",  .cageXYZ)
        wg.addColor(2,Float(RowHT)); wg.addSingleFloat(&control.basey,v1,v2,v3, "Green",.cageXYZ)
        
        if control.formula != JULIA {
            wg.addColor(3,Float(RowHT)); wg.addSingleFloat(&control.basez,v1,v2,v3, "Blue", .cageXYZ)
        }
        
        wg.addSingleFloat(&chgScale,0.99,1.01,0.05,"Scale", .cageScale)
        wg.addCommand("Show Axes",.showAxes)
        wg.addLine()
        wg.addOptionSelect(2,"Point Size","Select Point Size",pOptions);
        wg.addOptionSelect(3,"Cloud Count","Select # Overlapping Clouds",cOptions);
        
        wg.addLine()
        hv.frame = CGRect(x:5, y:wg.nextYCoord()+2, width:WGWIDTH-10, height:44)
        view.bringSubviewToFront(hv)
        
        wg.addGap(30)
        wg.addSingleFloat(&controlCenter,0,40,2,"Center",.histo)
        wg.addSingleFloat(&controlSpread,0,10,2,"Spread",.histo)
        wg.addString("",1)
        
        wg.addLine()
        wg.addCommand("ColorEdit",.colorEdit)
        wg.addCommand("Palette",.palette)
        wg.addLine()
        
        switch Int(control.formula) {
        case JULIA :
            wg.addLegend("Julia")
            wg.addDualFloat(UnsafeMutableRawPointer(&control.re1),  UnsafeMutableRawPointer(&control.re2), -4,4,1,"Real")
            wg.addDualFloat(UnsafeMutableRawPointer(&control.im1),  UnsafeMutableRawPointer(&control.im2), -4,4,1,"Imag")
            wg.addDualFloat(UnsafeMutableRawPointer(&control.mult1),UnsafeMutableRawPointer(&control.mult2),-3,3, 0.25,"Mult")
            wg.addDualFloat(UnsafeMutableRawPointer(&control.zoom1),UnsafeMutableRawPointer(&control.zoom2),20,500,100,"Zoom")
            wg.addLine()
        case QJULIA :
            wg.addLegend("Q Julia")
            wg.addDualFloat(UnsafeMutableRawPointer(&control.re1),  UnsafeMutableRawPointer(&control.re2), -1,1,0.5,"P 1,2")
            wg.addDualFloat(UnsafeMutableRawPointer(&control.im1),  UnsafeMutableRawPointer(&control.im2), -1,1,0.5,"P 3,4")
            wg.addSingleFloat(UnsafeMutableRawPointer(&control.mult1),-1,1,0.5,"P 5")
            wg.addSingleFloat(UnsafeMutableRawPointer(&control.mult2),-3,3,1,"P 6")
            wg.addLine()
        case BOX :
            wg.addLegend("Box")
            wg.addDualFloat(UnsafeMutableRawPointer(&control.re1),UnsafeMutableRawPointer(&control.im1),0.1,4, 0.3,"B Fold")
            wg.addDualFloat(UnsafeMutableRawPointer(&control.mult1),UnsafeMutableRawPointer(&control.zoom1),0.1,4, 0.3,"S Fold")
            wg.addDualFloat(UnsafeMutableRawPointer(&control.re2),UnsafeMutableRawPointer(&control.im2),0.1,10, 1,"Scale")
            wg.addLine()
        case IFS :
            wg.addOptionSelect(4,"IFS Equation","Select Equation Style",oeOptions);
            let v1:Float = -6, v2:Float = 6, v3:Float = 1
            wg.addDualFloat(UnsafeMutableRawPointer(&control.re1),  UnsafeMutableRawPointer(&control.re2), v1,v2,v3,"Scl/Off")
            wg.addSingleFloat(UnsafeMutableRawPointer(&control.im1), v1,v2,v3,"Shift")
            wg.addDualFloat(UnsafeMutableRawPointer(&control.mult1),  UnsafeMutableRawPointer(&control.mult2), v1,v2,v3,"Rot 1")
            wg.addDualFloat(UnsafeMutableRawPointer(&control.zoom1),  UnsafeMutableRawPointer(&control.zoom2), v1,v2,v3,"Rot 2")
            wg.addLine()
        case APOLLONIAN :
            wg.addLegend("Apollonian")
            wg.addSingleFloat(&control.mult1,0.001,100,50,"Mult")
            wg.addSingleFloat(&control.mult2, 10,300,60,"P1")
            wg.addSingleFloat(&control.re1, 0.5,1,0.2,"P2")
            wg.addSingleFloat(&control.re2, 0.5,1,0.2,"P3")
            wg.addLine()
        default : break
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
        wg.addCommand("Equation",.equation)
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
        case .cageXYZ :
            showAxesFlag = true
            bulb.calcCages()
        case .changeEnd, .power :
            control.hop = 1
            bulb.newBusy(.calc)
        case .palette :
            bulb.loadNextColorMap()
            pm.setNeedsDisplay()
            bulb.newBusy(.vertices)
        case .colorEdit :
            pm.isHidden = false
            layoutViews()
            pm.setNeedsDisplay()
        case .color :
            updateRenderColor()
            bulb.newBusy(.vertices)
        case .histo :
            updateControlCenter()
            bulb.newBusy(.vertices)
        case .fastCalc :
            bulb.fastCalc()
            dynamicSourceCode()
        case .smooth   : bulb.smoothData()
        case .smooth2  : bulb.smoothData2()
        case .quant    : bulb.quantizeData()
        case .quant2   : bulb.quantizeData2()
        case .showAxes : showAxesFlag = !showAxesFlag
        case .stereo   :
            stereoFlag = !stereoFlag
            layoutViews()
        case .cageScale:
            changeScale(control.scale * chgScale)
            showAxesFlag = true
            bulb.calcCages()
        case .saveLoad : performSegue(withIdentifier: "saveLoadSegue", sender: self)
        case .help     : performSegue(withIdentifier: "helpSegue", sender: self)
        case .equation :
            tv.isHidden = !tv.isHidden
            dynamicSourceCode()
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
        case 4 : return oeOptions[Int(control.ifsIndex)]
        default : return "noOption"
        }
    }

    func wgOptionSelected(_ ident:Int, _ index:Int) { // callback from popup
        switch(ident) {
        case 1 :    // formula
            control.formula = Int32(index)
            resetControlSettings()
            initializeWidgetGroup()
            bulb.newBusy(.calc)
            
        case 2 :    // pointsize
            pointSizeIndex = index
            updateRenderPointSize()
        case 3 :    // cloud count
            cloudCountIndex = index
            updateRenderCloudCount()
            bulb.newBusy(.calc)
        case 4 :    // IFS equation
            control.ifsIndex = Int32(index)
            loadIFSDefaultSettings()
            wg.setNeedsDisplay()
            bulb.newBusy(.calc)
        default : break
        }
    }

    //MARK: -
    
    func resetControlSettings() {
        switch Int(control.formula) {
        case JULIA :
            control.re1 = -2.17020011
            control.re2 = -0.0822001174
            control.im1 = 0.534700274
            control.im2 = -1.15230012
            control.mult1 = 1.42700005
            control.mult2 = 1.3253746
            control.zoom1 = 189.199997
            control.zoom2 = 211.949921
        case BOX :
            control.re1 = 1.671
            control.im1 = 0.7316
            control.mult1 = 1.6804
            control.zoom1 = 1.266
            control.re2 = 2.4677
            control.im2 = 2.52
        case QJULIA :
            control.basex = -1.14133
            control.basey = -1.12
            control.basez = -1.102
            control.scale = 0.00800000038
            control.re1 = 0.0912499353
            control.im1 = 0.485499978
            control.mult1 = -0.389624834
            control.mult2 = 1
            control.re2 = -0.238750175
            control.im2 = -0.389999956
            control.center = 12
            control.spread = 2
        case IFS :
            loadIFSDefaultSettings()
        case APOLLONIAN :
            control.basex = -1.34111273
            control.basey = -1.31978285
            control.basez = -1.30178273
            control.scale = 0.00933188479
            control.re1 = 0.998799979
            control.mult1 = 62.9147491
            control.mult2 = 143.37999
            control.re2 = 0.827500105
            control.center = 3
            control.spread = 2
            control.pColor.1 = 255
            control.pColor.3 = 179
            control.pColor.5 = 37
        default : break
        }
        
        controlColorRange = 128
        controlColorOffset = 128
        controlCenter = 10
        controlSpread = 2
    }
    
    func loadIFSDefaultSettings() {
        control.spread = 2
        control.offset = 128
        control.range = 128
        
        switch Int(control.ifsIndex) {
        case 0 : // Half Tet1
            control.basex = -5.50529909
            control.basey = -6.0948205
            control.basez = -6.12346792
            control.scale = 0.0350538194
            control.re1 = 1.03141177
            control.im1 = 1.12100089
            control.mult1 = 0.657745481
            control.zoom1 = -0.292500138
            control.re2 = 0.50168997
            control.mult2 = -0.309054941
            control.zoom2 = -0.318499744
            control.center = 10
        case 1 : // Half Tet2
            control.basex = -4.41710472
            control.basey = -3.91180563
            control.basez = -3.54410887
            control.scale = 0.027799191
            control.re1 = -1.20458925
            control.im1 = 0.0612261444
            control.mult1 = 0.734745502
            control.zoom1 = -1.78650033
            control.re2 = -0.455810547
            control.mult2 = 0.320944995
            control.zoom2 = 1.64700031
            control.center = 2
        case 2 : // Full Tet
            control.basex = -7.01420116
            control.basey = -5.96500015
            control.basez = -5.34282541
            control.scale = 0.0373393223
            control.re1 = -1.63158834
            control.im1 = 1.12100089
            control.mult1 = 0.780245482
            control.zoom1 = 0.507999897
            control.re2 = 0.267190039
            control.mult2 = -0.150054947
            control.zoom2 = -0.786999702
            control.center = 10
        case 3 : // cubic
            control.basex = -5.50529909
            control.basey = -6.0948205
            control.basez = -6.12346792
            control.scale = 0.0350538194
            control.re1 = 1.12741172
            control.im1 = 1.83650088
            control.mult1 = 1.6752454
            control.zoom1 = -0.0265000463
            control.re2 = 1.17418993
            control.mult2 = -0.584054947
            control.zoom2 = -0.318499833
            control.center = 15
        case 4 : // half octa
            control.basex = -5.50529909
            control.basey = -6.0948205
            control.basez = -6.12346792
            control.scale = 0.0350538194
            control.re1 = -1.80258822
            control.im1 = 1.09200096
            control.mult1 = -0.0567545593
            control.zoom1 = 0.569999814
            control.re2 = 0.573689878
            control.mult2 = -0.288055122
            control.zoom2 = -0.467999756
            control.center = 4
        case 5 : // full octa
            control.basex = -5.50529909
            control.basey = -6.0948205
            control.basez = -6.12346792
            control.scale = 0.0350538194
            control.re1 = 1.31841183
            control.im1 = 1.12100089
            control.mult1 = 0.657745481
            control.zoom1 = -0.292500138
            control.re2 = 0.942689955
            control.mult2 = -0.309054941
            control.zoom2 = -0.318499744
            control.center = 10
        default : // Kaleido
            control.basex = -1.0784421
            control.basey = -1.25651312
            control.basez = -1.69661307
            control.scale = 0.00554144336
            control.re1 = -1.21631932
            control.im1 = 0.931500792
            control.mult1 = 3.09924626
            control.zoom1 = -0.0305000525
            control.re2 = 2.94115138
            control.mult2 = -1.23205495
            control.zoom2 = 0.102000162
            control.center = 8
        }
    }
    
    //MARK: -

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
    
    let WGWIDTH:CGFloat = 120
    
    @objc func layoutViews() {
        let xs:CGFloat = view.bounds.width
        let ys:CGFloat = view.bounds.height
        
        let wgWidth:CGFloat = wg.isHidden ? 0 : WGWIDTH
        let pmWidth:CGFloat = pm.isHidden ? 0 : 120
        let vxs = xs - wgWidth - pmWidth
        
        var xBase = CGFloat()
        if !wg.isHidden {
            wg.frame = CGRect(x:xBase, y:0, width:wgWidth, height:view.bounds.height)
            xBase += wgWidth
        }
        if !pm.isHidden {
            pm.frame = CGRect(x:xBase, y:0, width:pmWidth, height:view.bounds.height)
            xBase += pmWidth
        }

        if stereoFlag {
            mtkViewR.isHidden = false
            mtkViewL.frame = CGRect(x:xBase, y:0, width:vxs/2, height:ys)
            mtkViewR.frame = CGRect(x:xBase + vxs/2, y:0, width:vxs/2, height:ys)
        }
        else {
            mtkViewR.isHidden = true
            mtkViewL.frame = CGRect(x:xBase, y:0, width:vxs, height:ys)
        }
        
        viewCenter.x = mtkViewL.frame.width/2
        viewCenter.y = mtkViewL.frame.height/2
        arcBall.initialize(Float(mtkViewL.frame.width),Float(mtkViewL.frame.height))
        
        hv.isHidden = wg.isHidden
        tv.frame = CGRect(x:xBase+10, y:1, width:420, height:500)
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
        pm.bellCurveColorScheme()
    }
    
    func reset() {
        resetControlSettings()
        
        undoControl1 = control
        undoControl2 = control
        
        pointSizeIndex = 1
        updateRenderPointSize()
        
        cloudCountIndex = 0
        updateRenderCloudCount()
        
        updateRenderColor()
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

func fClamp(_ v:Float, _ min:Float, _ max:Float) -> Float {
    if v < min { return min }
    if v > max { return max }
    return v
}


