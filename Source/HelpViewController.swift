import UIKit

class HelpViewController: UIViewController {

    @IBOutlet var tv: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        tv.font = UIFont(name: "Helvetica", size: 16)
        tv.resignFirstResponder()
        
        do {
            tv.text = try String(contentsOfFile: Bundle.main.path(forResource: "help.txt", ofType: "")!)
        } catch {
            fatalError("\n\nload help text failed\n\n")
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        tv.scrollRangeToVisible(NSMakeRange(0, 0))
    }
}
