import UIKit

// Path implementation that bridges UIBezierPath to MyScript's IINKIPath protocol.
@objc class Path: NSObject, IINKIPath {
  var bezierPath: UIBezierPath = UIBezierPath()

  @objc func move(to position: CGPoint) {
    bezierPath.move(to: position)
  }

  @objc func line(to position: CGPoint) {
    bezierPath.addLine(to: position)
  }

  @objc func close() {
    bezierPath.close()
  }

  @objc func curve(to: CGPoint, controlPoint1 c1: CGPoint, controlPoint2 c2: CGPoint) {
    bezierPath.addCurve(to: to, controlPoint1: c1, controlPoint2: c2)
  }

  @objc func quad(to: CGPoint, controlPoint c: CGPoint) {
    bezierPath.addQuadCurve(to: to, controlPoint: c)
  }
}
