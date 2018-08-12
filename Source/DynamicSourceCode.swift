
func dynamicSourceCode() {
    if vc.textView.isHidden { return }
    
    var s = String()
    
    func addString(_ str:String) { s += str; s += "\n" }
    
    switch control.formula {
    case 0 :
        addString("MandelBulb Equation #1")
        addString(" ")
        addString("float r,theta,phi,pwr,ss,dist;")
        addString("float3 w = current position")
        addString(" ")
        addString("for(;;) {")
        addString("    if(++iter == 40) { break }")
        addString("    r = sqrt(w.x * w.x + w.y * w.y + w.z * w.z);")
        addString("    theta = atan2(sqrt(w.x * w.x + w.y * w.y), w.z);")
        addString("    phi = atan2(w.y,w.x);")
        addString(String(format:"    pwr = pow(r, %8.5f);",control.power));
        addString(String(format:"    ss = sin(theta * %8.5f)",control.power));
        addString(String(format:"    w.x += pwr * ss * cos(phi * %8.5f)",control.power));
        addString(String(format:"    w.y += pwr * ss * sin(phi * %8.5f)",control.power));
        addString(String(format:"    w.z += pwr * cos(theta * %8.5f)",control.power));
        addString("    dist = w.x * w.x + w.y * w.y + w.z * w.z;");
        addString("    if(dist > 4) break;")
        addString("}")
    case 1 :
        addString("MandelBulb Equation #2")
        addString(" ")
        addString("float3 w = current position")
        addString("float m = dot(w,w);")
        addString("float dz = 1.0;")
        addString(" ")
        addString("for(;;) {")
        addString("    if(++iter == 40) { break }")
        addString("    float m2 = m*m;")
        addString("    float m4 = m2*m2;")
        addString("    dz = 8.0*sqrt(m4*m2*m)*dz + 1.0;")
        addString(" ")
        addString("    float x = w.x; float x2 = x*x; float x4 = x2*x2;")
        addString("    float y = w.y; float y2 = y*y; float y4 = y2*y2;")
        addString("    float z = w.z; float z2 = z*z; float z4 = z2*z2;")
        addString("    float k3 = x2 + z2;")
        addString(String(format:"    float k2s = sqrt( pow(k3,%8.5f));",control.power));
        addString("    float k2 = 1;  if(k2s != 0) k2 = 1.0 / k2s;");
        addString("    float k1 = x4 + y4 + z4 - 6.0*y2*z2 - 6.0*x2*y2 + 2.0*z2*x2;")
        addString("    float k4 = x2 - y2 + z2;")
        addString(" ")
        addString(" ")
        addString("    w.x += 64.0*x*y*z*(x2-z2)*k4*(x4-6.0*x2*z2+z4)*k1*k2;")
        addString("    w.y += -16.0*y2*k3*k4*k4 + k1*k1;")
        addString("    w.z += -8.0*y*k4*(x4*x4 - 28.0*x4*x2*z2 + 70.0*x4*z4")
        addString("           - 28.0*x2*z2*z4 + z4*z4)*k1*k2;")
        addString("    m = dot(w,w);")
        addString("    if( m > 4.0 ) break;");
        addString("}")
    case 2 :
        addString("MandelBulb Equation #3")
        addString(" ")
        addString("float3 w = current position")
        addString("float magnitude, r, theta_power, r_power;")
        addString("phi, phi_sin, phi_cos, xxyy;")
        addString(" ")
        addString("for(;;) {")
        addString("    if(++iter == 40) { break }")
        addString("    xxyy = w.x * w.x + w.y * w.y;")
        addString("    magnitude = xxyy + w.z * w.z;")
        addString("    r = sqrt(magnitude);")
        addString("    if(r > 8) break;")
        addString(String(format:"    theta_power = atan2(w.y,w.x) * %8.5f;",control.power));
        addString(String(format:"    r_power = pow(r,%8.5f);",control.power));
        addString("    phi = asin(w.z / r);")
        addString(String(format:"    phi_cos = cos(phi * %8.5f);",control.power));
        addString("    w.x += r_power * cos(theta_power) * phi_cos;")
        addString("    w.y += r_power * sin(theta_power) * phi_cos;")
        addString("    w.z += r_power * sin(phi * control.power);")
        addString("}")
    case 3 :
        addString("MandelBulb Equation #4")
        addString(" ")
        addString("float3 w = current position")
        addString("float magnitude, r, theta_power, r_power;")
        addString("phi, phi_sin, phi_cos, xxyy;")
        addString(" ")
        addString("for(;;) {")
        addString("    if(++iter == 40) { break }")
        addString("    xxyy = w.x * w.x + w.y * w.y;")
        addString("    magnitude = xxyy + w.z * w.z;")
        addString("    r = sqrt(magnitude);")
        addString("    if(r > 8) break;")
        addString(String(format:"    theta_power = atan2(w.y,w.x) * %8.5f;",control.power));
        addString(String(format:"    r_power = pow(r,%8.5f);",control.power));
        addString("    phi = atan2(sqrt(xxyy), w.z);")
        addString(String(format:"    phi_sin = sin(phi * %8.5f);",control.power));
        addString("    w.x += r_power * cos(theta_power) * phi_sin;")
        addString("    w.y += r_power * sin(theta_power) * phi_sin;")
        addString("    w.z += r_power * cos(phi * control.power);")
        addString("}")
    case 4 :
        addString("MandelBulb Equation #5")
        addString(" ")
        addString("float3 w = current position")
        addString("float magnitude, r, theta_power, r_power;")
        addString("phi, phi_sin, phi_cos, xxyy;")
        addString(" ")
        addString("for(;;) {")
        addString("    if(++iter == 40) { break }")
        addString("    xxyy = w.x * w.x + w.y * w.y;")
        addString("    magnitude = xxyy + w.z * w.z;")
        addString("    r = sqrt(magnitude);")
        addString("    if(r > 8) break;")
        addString(String(format:"    theta_power = atan2(w.y,w.x) * %8.5f;",control.power));
        addString(String(format:"    r_power = pow(r,%8.5f);",control.power));
        addString("    phi = acos(w.z / r);")
        addString(String(format:"    phi_cos = cos(phi * %8.5f);",control.power));
        addString("    w.x += r_power * cos(theta_power) * phi_cos;")
        addString("    w.y += r_power * sin(theta_power) * phi_cos;")
        addString("    w.z += r_power * sin(phi*control.power);")
        addString("}")
    case BOX_FORMULA :
        addString("MandelBox Equation")
        addString(" ")
        addString("float3 w = current position")
        addString(String(format:"float fLimit  = %8.5f;",control.re1));
        addString(String(format:"float fValue  = %8.5f;",control.im1));
        addString(String(format:"float mRadius = %8.5f;",control.mult1));
        addString(String(format:"float fRadius = %8.5f;",control.zoom1));
        addString(String(format:"float scale   = %8.5f;",control.re2));
        addString("float mr2 = mRadius * mRadius;")
        addString("float fr2 = fRadius * fRadius;")
        addString("float ffmm = fr2 / mr2;")
        addString(" ")
        addString("for(;;) {")
        addString("    if(++iter == 40) { break }")
        addString("    if(w.x > fLimit) w.x = fValue - w.x; else if(w.x < -fLimit) w.x = -fValue - w.x;")
        addString("    if(w.y > fLimit) w.y = fValue - w.y; else if(w.y < -fLimit) w.y = -fValue - w.y;")
        addString("    if(w.z > fLimit) w.z = fValue - w.z; else if(w.z < -fLimit) w.z = -fValue - w.z;")
        addString("    r = w.x * w.x + w.y * w.y +w.z * w.z;")
        addString(String(format:"    if(r > %8.5f) break;",control.im2));
        addString(" ")
        addString("    if(r < mr2) {")
        addString("        float num = ffmm * scale;")
        addString("        w.x *= num;")
        addString("        w.y *= num;")
        addString("        w.z *= num;")
        addString("    }")
        addString("    else")
        addString("    if(r < fr2) {")
        addString("        float den = fr2 * scale / r;")
        addString("        w.x *= den;")
        addString("        w.y *= den;")
        addString("        w.z *= den;")
        addString("    }")
        addString("}")
    case JULIA_FORMULA :
        addString("Stacked Julia Sets")
        addString(" ")
        addString(String(format:"float re = %8.5f",control.re1))
        addString(String(format:"float im = %8.5f",control.im1))
        addString(String(format:"float newRe = control.basex + position.x / %8.5f",control.zoom1))
        addString(String(format:"float newIm = control.basey + position.y / %8.5f",control.zoom1))
        addString("float oldRe,oldIm")
        addString(" ")
        addString("for(;;) {")
        addString("    oldRe = newRe;")
        addString("    oldIm = newIm;")
        addString("    newRe = oldRe * oldRe - oldIm * oldIm + re;")
        addString("    newIm = mult * oldRe * oldIm + im;")
        addString("    if((newRe * newRe + newIm * newIm) > 4) break;")
        addString("    if(++iter == 40) { break }")
        addString("}")
    case QJULIA_FORMULA :
        addString("Quaternion Julia Set")
        addString(" ")
        addString("float4 q = float4();")
        addString("float4 c;")
        addString(" ")
        addString(String(format:"c.x = %8.5f",control.re1))
        addString(String(format:"c.y = %8.5f",control.re2))
        addString(String(format:"c.z = %8.5f",control.im1))
        addString(String(format:"c.w = %8.5f",control.im2))
        addString(" ")
        addString("q.x = position.x")
        addString(String(format:"q.y = %8.5f",control.mult1))
        addString("q.z = position.y")
        addString("q.w = position.z")
        addString(" ")
        addString("for(;;) {")
        addString(String(format:"    q = quaternionSquare(q) * %8.5f",control.mult2))
        addString("    q += c;")
        addString("    if(q.x > 4) break;")
        addString("    if(++iter == 100) { break }")
        addString("}")
    case OCTA_FORMULA :
        addString("Octahedra IFS")
        addString(" ")
        addString(String(format:"float3 scale  = float3(%8.5f);",control.re1))
        addString(String(format:"float3 offset = float3(%8.5f);",control.re2))
        addString(String(format:"float3 shift  = float3(%8.5f);",control.im1))
        addString("float3 scale_offset = offset * (scale - 1);")
        addString(" ")
        addString("for(;;) {")
        addString(String(format:"    w = rotateXY(w,%8.5f);",control.mult1))
        addString(String(format:"    w = rotateXZ(w,%8.5f);",control.mult2))
        addString(" ")
        addString("    w = abs(w + shift) - shift;")
        addString(" ")
        addString("    if (w.x < w.y) w.xy = w.yx;")
        addString("    if (w.x < w.z) w.xz = w.zx;")
        addString("    if (w.y < w.z) w.yz = w.zy;")
        addString(" ")
        addString(String(format:"    w = rotateXY(w,%8.5f);",control.zoom1))
        addString(String(format:"    w = rotateXZ(w,%8.5f);",control.zoom2))
        addString(" ")
        addString("    w *= scale;")
        addString("    w -= scale_offset;")
        addString("    if(length(w) > 4) break;")
        addString("    if(++iter == 40) break;")
        addString("}")
    default : break
    }
    
    vc.textView.text = s
}
