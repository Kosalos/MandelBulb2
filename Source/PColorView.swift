import UIKit

let TOP:CGFloat = 10
let XMARGIN:CGFloat = 10
let YMARGIN:CGFloat = 2
let BAR_HEIGHT:CGFloat = CGFloat(700) / CGFloat(MAX_ITERATIONS)
let FULL_HEIGHT:CGFloat = CGFloat(MAX_ITERATIONS) * BAR_HEIGHT

class PColorView: UIView {
    var context : CGContext?
    var clearTouchFlag:Bool = false
    
    //MARK:-

    func initialize() {
        var yCoord:CGFloat = FULL_HEIGHT + 20
        
        func addButton(_ legend:String, _ callBack:Selector) {
            let btn = UIButton(type: .system)
            btn.setTitle(legend, for: .normal)
            btn.addTarget(self, action: callBack, for: .touchUpInside)
            btn.frame = CGRect(x:10, y:yCoord, width:100, height:30)
            btn.setTitleColor(.white, for: .normal)
            addSubview(btn)
            yCoord += 35
        }
        
        addButton("Slide Up",#selector(slideUpTapped))
        addButton("Slide Down",#selector(slideDownTapped))
        yCoord += 50
        addButton("Clear All",#selector(clearTapped))
        addButton("Finished",#selector(finishedTapped))
        
        addGestureRecognizer(UIPanGestureRecognizer(target:self, action: #selector(self.panGesture(_:))))
        addGestureRecognizer(UITapGestureRecognizer(target:self, action: #selector(self.tapGesture(_:))))
        
        isHidden = true
    }

    //MARK:-
    
    var cIndex:Int = 0
    var vIndex:Int = 0
    
    func determineCIndex(_ pt:CGPoint) -> Bool {
        cIndex = Int((pt.y - TOP) / BAR_HEIGHT)

        vIndex = Int(255 * pt.x / bounds.width)
        if vIndex < 0 { vIndex = 0 } else if vIndex > 255 { vIndex = 255 }

        return cIndex >= 0 && cIndex < Int(MAX_ITERATIONS)
    }

    func processPanTap(_ pt:CGPoint) {
        if determineCIndex(pt) {
            setPColor(Int32(cIndex),Int32(vIndex))
            setNeedsDisplay()
        }
    }
    
    @objc func panGesture(_ sender: UIPanGestureRecognizer) {
        processPanTap(sender.location(in: self))
        if sender.state == .ended { bulb.newBusy(.vertices) }
    }

    @objc func tapGesture(_ sender: UITapGestureRecognizer) {
        if determineCIndex(sender.location(in: self)) {
            if getPColor(Int32(cIndex)) > 0 {
                setPColor(Int32(cIndex),0)
            }
            else {
                setPColor(Int32(cIndex),Int32(vIndex))
            }
            
            setNeedsDisplay()
            bulb.newBusy(.vertices)
        }
    }

    //MARK:-

    @objc func slideUpTapped()   { slideEntries(-1); }
    @objc func slideDownTapped() { slideEntries(+1); }

    @objc func clearTapped() {
        pColorClear()
        setNeedsDisplay()
        bulb.newBusy(.vertices)
    }

    @objc func finishedTapped() { self.isHidden = true; vc.layoutViews() }

    //MARK:-
    
    func slideEntries(_ dir:Int) {  // skip entries 0,1
        if dir > 0 {
            for i in (3 ..< MAX_ITERATIONS).reversed() { setPColor(i,getPColor(i-1)) } // skip 0,1
            setPColor(2,0)
        }
        else {
            for i in 2 ..< MAX_ITERATIONS-1 { setPColor(i,getPColor(i+1)) }
            setPColor(MAX_ITERATIONS-1,0)
        }
        
        setNeedsDisplay()
        bulb.newBusy(.vertices)
    }

    //MARK:-

    func bellCurveColorScheme() {
        pColorClear()
        let width:Int = Int(control.spread) + 1
        let scale = Float(255) / Float(width)
        
        for i in -width ... width {
            let index:Int = Int(control.center) + i
            
            if index >= 0 && index < Int(MAX_ITERATIONS) {
                setPColor(Int32(index), Int32( Float(255) - Float(abs(i)) * scale))
            }
        }
        
        setNeedsDisplay()
    }

    //MARK:-
    
    func colorValue(_ index:Int) -> CGColor {
        var color = vector_float3()
        
        switch colorMapIndex {
        case 0 : color = colorLookup1(Int32(index))
        case 1 : color = colorLookup2(Int32(index))
        case 2 : color = colorLookup3(Int32(index))
        default: color = colorLookup4(Int32(index))
        }

        let c = UIColor(red:CGFloat(color.x), green:CGFloat(color.y), blue:CGFloat(color.z), alpha:1)
        return c.cgColor
    }
    
    override func draw(_ rect: CGRect) {
        context = UIGraphicsGetCurrentContext()
        
        func drawColorBar(_ index:Int) {
            let rect = CGRect(x:XMARGIN, y:TOP + CGFloat(index) * BAR_HEIGHT + YMARGIN, width:bounds.width - XMARGIN * 2, height:BAR_HEIGHT - YMARGIN)
            
            context?.setFillColor(colorValue(Int(getPColor(Int32(index)))))
            context?.setStrokeColor(UIColor.black.cgColor)
            context?.addRect(rect)
            context?.fillPath()
            context?.addRect(rect)
            context?.strokePath()
        }
        
        context?.setFillColor(UIColor.darkGray.cgColor)
        UIBezierPath(rect:rect).fill()

        for i in 1 ..< Int(MAX_ITERATIONS) {
            drawColorBar(i)
        }
    }
}
