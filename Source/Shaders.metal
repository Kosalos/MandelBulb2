#include <metal_stdlib>
#include <simd/simd.h>
#import "ShaderTypes.h"

using namespace metal;

float4 quaternionMultiply(float4 a,float4 b) {  // x = real; y,z,w = i,j,k
    float4 ans;
    ans.x = a.x * b.x - a.y * b.y - a.z * b.z - a.w * b.w;
    ans.y = a.x * b.y + a.y * b.x + a.z * b.w - a.w * b.z;
    ans.z = a.x * b.z - a.z * b.w + a.z * b.x + a.w * b.z;
    ans.w = a.x * b.w + a.y * b.z - a.z * b.y + a.w * b.x;
    return ans;
}

float4 quaternionSquare(float4 a) {  // x = real; y,z,w = i,j,k
    float temp = a.x * 2;
    float4 ans;
    ans.x = a.x * a.x - a.y * a.y - a.z * a.z - a.w * a.w;
    ans.y = a.y * temp;
    ans.z = a.z * temp;
    ans.w = a.w * temp;
    return ans;
}

float3 rotateXY(float3 pos, float angle) {
    float ss = sin(angle);
    float cc = cos(angle);
    float qt = pos.x;
    pos.x = pos.x * cc - pos.y * ss;
    pos.y =    qt * ss + pos.y * cc;
    return pos;
}

float3 rotateXZ(float3 pos, float angle) {
    float ss = sin(angle);
    float cc = cos(angle);
    float qt = pos.x;
    pos.x = pos.x * cc - pos.z * ss;
    pos.z =    qt * ss + pos.z * cc;
    return pos;
}

//float3 rotateYZ(float3 pos, float angle) {
//    float ss = sin(angle);
//    float cc = cos(angle);
//    float qt = pos.y;
//    pos.y = pos.y * cc - pos.z * ss;
//    pos.z =    qt * ss + pos.z * cc;
//    return pos;
//}

//MARK: -

kernel void mapShader
(
 device Map3D &src [[buffer(0)]],
 constant Control &control [[buffer(1)]],
 uint3 pp [[thread_position_in_grid]])
{
    device unsigned char &d = src.data[pp.x][pp.y][pp.z];
    unsigned char iter = 0;
    
    if(control.hop > 1) {
        if(int(pp.x) % control.hop) { d = 0; return; }
        if(int(pp.y) % control.hop) { d = 0; return; }
        if(int(pp.z) % control.hop) { d = 0; return; }
    }
    
    // run 1,2 or 4 interleaved clouds to add more points to render
    float offset = float(control.cloudIndex) / float(NUM_CLOUD);
    float fpx = float(pp.x) + offset;
    float fpy = float(pp.y) + offset;
    float fpz = float(pp.z) + offset;

    //MARK: - JULIA_FORMULA
    if (control.formula == JULIA) {
        float re,im,mult,zoom;
        
        float ratio = fpz / float(WIDTH-1);
        re = control.re1 + (control.re2 - control.re1) * ratio;
        im = control.im1 + (control.im2 - control.im1) * ratio;
        mult = control.mult1 + (control.mult2 - control.mult1) * ratio;
        zoom = control.zoom1 + (control.zoom2 - control.zoom1) * ratio;
        if(zoom == 0) zoom = 1;
        
        float newRe, newIm, oldRe, oldIm;
        newRe = control.basex + fpx / zoom;
        newIm = control.basey + fpy / zoom;
        
        for(;;) {
            oldRe = newRe;
            oldIm = newIm;
            newRe = oldRe * oldRe - oldIm * oldIm + re;
            newIm = mult * oldRe * oldIm + im;
            
            if((newRe * newRe + newIm * newIm) > 4) break;
            if(++iter == MAX_ITERATIONS) break;
        }

        d = iter;
        return;
    }
    
    //MARK: - QJULIA_FORMULA
    float3 w;
    w.x = control.basex + fpx * control.scale;
    w.y = control.basey + fpy * control.scale;
    w.z = control.basez + fpz * control.scale;
    
    if (control.formula == QJULIA) {
        float4 q = float4();
        float4 c;
        
        c.x = control.re1;
        c.y = control.re2;
        c.z = control.im1;
        c.w = control.im2;
        
        q.x = w.z;
        q.y = control.mult1;
        q.z = w.x;
        q.w = w.y;
        
        for(;;) {
            q = quaternionSquare(q) * control.mult2;
            q += c;
            
            if(q.x > 4) break;
            if(++iter == MAX_ITERATIONS) break;
        }
        
        d = iter;
        return;
    }

    //MARK: - APOLLONIAN
    if (control.formula == APOLLONIAN) {
        float distance,t = control.re1 * (control.re2 + 0.25 * cos(control.mult1 * 3.1415926 * (w.z - w.x) / control.mult2));

        for(;;) {
            w = -1.0 + 2.0 * fract(0.5 * w + 0.5);

            distance = dot(w,w);
            if(distance > 1) break;
            if(++iter == 120) break;
            
            w *= t / distance;
        }

        d = iter;
        return;
    }

    //MARK: - IFS_FORMULA
    // http://hirnsohle.de/test/fractalLab/
    // http://www.fractalforums.com/sierpinski-gasket/kaleidoscopic-(escape-time-ifs)/
    if (control.formula == IFS) {
        float3 scale  = float3(control.re1);
        float3 offset = float3(control.re2);
        float3 shift  = float3(control.im1);
        float3 scale_offset = offset * (scale - 1);
        
        if(control.ifsIndex == 6) { // Kaleido
            float CX = control.im1;
            float CY = control.im1;
            float CZ = control.im1;
            float scl = control.re1;
            
            for(;;) {
                w = rotateXY(w,control.mult1);  // fractalRotation1
                w = rotateXZ(w,control.mult2);

                w.x = abs(w.x);
                w.y = abs(w.y);
                w.z = abs(w.z);
                if (w.x < w.y) w.xy = w.yx;
                if (w.x < w.z) w.xz = w.zx;
                if (w.y < w.z) w.yz = w.zy;

                w.z -= 0.5 * CZ * (scl-1) / scl;
                w.z = -abs( - w.z);
                w.z += 0.5 * CZ * (scl-1) / scl;

                w = rotateXY(w,control.zoom1);  // fractalRotation2
                w = rotateXZ(w,control.zoom2);

                w.x = scl * w.x - CX * (scl-1);
                w.y = scl * w.y - CY * (scl-1);
                w.z = scl * w.z;

                if(length(w) > 2) break;
                if(++iter == MAX_ITERATIONS) break;
            }
            
            d = iter;
            return;
        }
        
        for(;;) {
            w = rotateXY(w,control.mult1);  // fractalRotation1
            w = rotateXZ(w,control.mult2);
            
            w = abs(w + shift) - shift;

            switch(control.ifsIndex) {
                case 0 : // half1 tetrahedral
                    if (w.x + w.y < 0) { float t = -w.y; w.y = -w.x; w.x = t; }
                    if (w.x + w.z < 0) { float t = -w.z; w.z = -w.x; w.x = t; }
                    if (w.y + w.z < 0) { float t = -w.z; w.z = -w.y; w.y = t; }
                    break;
                case 1 : // half2 tetrahedral
                    if (w.x < w.y) w.xy = w.yx;
                    if (w.x < w.z) w.xz = w.zx;
                    if (w.y < w.z) w.yz = w.zy;
                    break;
                case 2 : // full tetrahedral
                    if (w.x < w.y) w.xy = w.yx;
                    if (w.x < w.z) w.xz = w.zx;
                    if (w.y < w.z) w.yz = w.zy;
                    if (w.x + w.y < 0) { float t = -w.y; w.y = -w.x; w.x = t; }
                    if (w.x + w.z < 0) { float t = -w.z; w.z = -w.x; w.x = t; }
                    if (w.y + w.z < 0) { float t = -w.z; w.z = -w.y; w.y = t; }
                    break;
                case 3 : // cubic
                    w.x = abs(w.x);
                    w.y = abs(w.y);
                    w.z = abs(w.z);
                    break;
                case 4 : // half Octahedral
                    if (w.x < w.y) w.xy = w.yx;
                    if (w.x + w.y < 0) { float t = -w.y; w.y = -w.x; w.x = t; }
                    if (w.x < w.z) w.xz = w.zx;
                    if (w.x + w.z < 0) { float t = -w.z; w.z = -w.x; w.x = t; }
                    break;
                default : // Octahedral
                    if (w.x < w.y) w.xy = w.yx;
                    if (w.x < w.z) w.xz = w.zx;
                    if (w.y < w.z) w.yz = w.zy;
                    break;
            }
            
            w = rotateXY(w,control.zoom1);  // fractalRotation2
            w = rotateXZ(w,control.zoom2);
            
            w *= scale;
            w -= scale_offset;
            
            if(length(w) > 4) break;
            if(++iter == MAX_ITERATIONS) break;
        }

        d = iter;
        return;
    }
    
    //MARK: - BULB_1
    // https://github.com/jtauber/mandelbulb/blob/master/mandel8.py
    if (control.formula == BULB_1) {
        float r,theta,phi,pwr,ss;
        
        for(;;) {
            r = sqrt(w.x * w.x + w.y * w.y + w.z * w.z);
            theta = atan2(sqrt(w.x * w.x + w.y * w.y), w.z);
            phi = atan2(w.y,w.x);
            pwr = pow(r,control.power );
            ss = sin(theta * control.power);
            
            w.x += pwr * ss * cos(phi * control.power);
            w.y += pwr * ss * sin(phi * control.power);
            w.z += pwr * cos(theta * control.power);

            if(length(w) > 4) break;
            if(++iter == MAX_ITERATIONS) break;
        }
        
        d = iter;
        return;
    }
    
    //MARK: - BULB_2
    if (control.formula == BULB_2) {
        float m = dot(w,w);
        float dz = 1.0;
        
        for(;;) {
            float m2 = m*m;
            float m4 = m2*m2;
            dz = 8.0*sqrt(m4*m2*m)*dz + 1.0;
            
            float x = w.x; float x2 = x*x; float x4 = x2*x2;
            float y = w.y; float y2 = y*y; float y4 = y2*y2;
            float z = w.z; float z2 = z*z; float z4 = z2*z2;
            
            float k3 = x2 + z2;
            float k2s = sqrt(  pow(k3,control.power ));
            float k2 = 1;  if(k2s != 0) k2 = 1.0 / k2s;
            float k1 = x4 + y4 + z4 - 6.0*y2*z2 - 6.0*x2*y2 + 2.0*z2*x2;
            float k4 = x2 - y2 + z2;
            
            w.x +=  64.0*x*y*z*(x2-z2)*k4*(x4-6.0*x2*z2+z4)*k1*k2;
            w.y +=  -16.0*y2*k3*k4*k4 + k1*k1;
            w.z +=  -8.0*y*k4*(x4*x4 - 28.0*x4*x2*z2 + 70.0*x4*z4 - 28.0*x2*z2*z4 + z4*z4)*k1*k2;
            
            m = dot(w,w);
            if( m > 4.0 ) break;
            if(++iter == MAX_ITERATIONS) break;
        }
        
        d = iter;
        return;
    }
    
    float magnitude, r, theta_power, r_power, phi, phi_sin, phi_cos, xxyy;
    
    //MARK: - BULB_3
    if (control.formula == BULB_3) {
        for(;;) {
            if(++iter == MAX_ITERATIONS) break;
            
            xxyy = w.x * w.x + w.y * w.y;
            magnitude = xxyy + w.z * w.z;
            r = sqrt(magnitude);
            if(r > 8) break;

            theta_power = atan2(w.y,w.x) * control.power;
            r_power = pow(r,control.power);
            
            phi = asin(w.z / r);
            phi_cos = cos(phi * control.power);
            w.x += r_power * cos(theta_power) * phi_cos;
            w.y += r_power * sin(theta_power) * phi_cos;
            w.z += r_power * sin(phi * control.power);
        }
        
        d = iter;
        return;
    }
    
    //MARK: - BULB_4
    if (control.formula == BULB_4) {
        for(;;) {
            if(++iter == MAX_ITERATIONS) break;

            xxyy = w.x * w.x + w.y * w.y;
            magnitude = xxyy + w.z * w.z;
            r = sqrt(magnitude);
            if(r > 8) break;

            theta_power = atan2(w.y,w.x) * control.power;
            r_power = pow(r,control.power);
            
            phi = atan2(sqrt(xxyy), w.z);
            phi_sin = sin(phi * control.power);
            w.x += r_power * cos(theta_power) * phi_sin;
            w.y += r_power * sin(theta_power) * phi_sin;
            w.z += r_power * cos(phi * control.power);
        }
        
        d = iter;
        return;
    }
    
    //MARK: - BULB_5
    if (control.formula == BULB_5) {
        for(;;) {
            if(++iter == MAX_ITERATIONS) break;
            
            xxyy = w.x * w.x + w.y * w.y;
            magnitude = xxyy + w.z * w.z;
            r = sqrt(magnitude);
            if(r > 8) break;
            
            theta_power = atan2(w.y,w.x) * control.power;
            r_power = pow(r,control.power);
            
            phi = acos(w.z / r);
            phi_cos = cos(phi * control.power);
            w.x += r_power * cos(theta_power) * phi_cos;
            w.y += r_power * sin(theta_power) * phi_cos;
            w.z += r_power * sin(phi*control.power);
        }
        
        d = iter;
        return;
    }

    //MARK: - BOX
    if (control.formula == BOX) {
        float fLimit  = control.re1;
        float fValue  = control.im1;
        float mRadius = control.mult1;
        float fRadius = control.zoom1;
        float scale   = control.re2;
        float mr2 = mRadius * mRadius;
        float fr2 = fRadius * fRadius;
        float ffmm = fr2 / mr2;
        
        for(;;) {
            if(++iter == MAX_ITERATIONS) break;
            
            if(w.x > fLimit) w.x = fValue - w.x; else if(w.x < -fLimit) w.x = -fValue - w.x;
            if(w.y > fLimit) w.y = fValue - w.y; else if(w.y < -fLimit) w.y = -fValue - w.y;
            if(w.z > fLimit) w.z = fValue - w.z; else if(w.z < -fLimit) w.z = -fValue - w.z;
            
            r = w.x * w.x + w.y * w.y +w.z * w.z;
            if(r > control.im2) break;
            
            if(r < mr2) {
                float num = ffmm * scale;
                w.x *= num;
                w.y *= num;
                w.z *= num;
            }
            else
                if(r < fr2) {
                    float den = fr2 * scale / r;
                    w.x *= den;
                    w.y *= den;
                    w.z *= den;
                }
        }
        
        d = iter;
    }
}
    
//MARK: -
// remove totally surrounded points from the cloud by marking them as '255' (not rendered)

kernel void adjacentShader
(
 device Map3D &src [[buffer(0)]],
 uint3 p [[thread_position_in_grid]])
{
    unsigned char M = 2;
    unsigned char d = src.data[p.x][p.y][p.z];
    if(d < M) { src.data[p.x][p.y][p.z] = 255; return; }

    int x1 = p.x - 1; if(x1 < 0) x1 = 1;
    int y1 = p.y - 1; if(y1 < 0) y1 = 1;
    int z1 = p.z - 1; if(z1 < 0) z1 = 1;

    int z2 = p.z + 1; if(z2 == WIDTH) z2 = WIDTH-2;

    d = src.data[x1][y1][z1];   if(d < M || d == 255) return;
    d = src.data[x1][y1][z2];   if(d < M || d == 255) return;

    int y2 = p.y + 1; if(y2 == WIDTH) y2 = WIDTH-2;

    d = src.data[x1][y2][z1];   if(d < M || d == 255) return;
    d = src.data[x1][y2][z2];   if(d < M || d == 255) return;

    int x2 = p.x + 1; if(x2 == WIDTH) x2 = WIDTH-2;

    d = src.data[x2][y1][z1];   if(d < M || d == 255) return;
    d = src.data[x2][y1][z2];   if(d < M || d == 255) return;
    d = src.data[x2][y2][z1];   if(d < M || d == 255) return;
    d = src.data[x2][y2][z2];   if(d < M || d == 255) return;

    src.data[p.x][p.y][p.z] = 255;      // generated zero
}

//MARK: -
// set cloud point value to average of neighboring points

#define X 1
#define Y WIDTH
#define Z (WIDTH * WIDTH)

#define CONVOLUTION_COUNT 27
constant int offset[] = {     // 3x3x3
    -X-Y-Z, -Y-Z, +X-Y-Z,
    -X-Z, -Z, +X-Z,
    -X+Y-Z, +Y-Z, +X+Y-Z,

    -X-Y, -Y, +X-Y,
    -X, 0, +X,
    -X+Y, +Y, +X+Y,

    -X-Y+Z, -Y+Z, +X-Y+Z,
    -X+Z, +Z, +X+Z,
    -X+Y+Z, +Y+Z, +X+Y+Z,
};

//#define CONVOLUTION_COUNT 7
//constant int offset[] = {   // diamond
//    -X,+X, -Y,+Y, -Z,+Z, 0
//};

kernel void smoothingShader
(
 constant Map3D &src [[buffer(0)]],
 device Map3D &dst [[buffer(1)]],
 uint3 p [[thread_position_in_grid]])
{
    bool skip = false;
    if(p.x == 0 || p.x == WIDTH-1) skip = true; else
        if(p.y == 0 || p.y == WIDTH-1) skip = true; else
            if(p.z == 0 || p.z == WIDTH-1) skip = true;
    
    if(skip) {
        dst.data[p.x][p.y][p.z] = src.data[p.x][p.y][p.z];
    }
    else {
        int total = 0;
        int count = 0;
        constant unsigned char *ptr = &src.data[p.x][p.y][p.z];
        unsigned char ch;
        
        for(int i=0;i<CONVOLUTION_COUNT;++i) {
            ch = *(ptr + offset[i]);
            if(ch > 0 && ch < 255) { // only include rendered points
                total += int(ch);
                ++count;
            }
        }
        
        if(count > 0) total /= count;
        
        dst.data[p.x][p.y][p.z] = (unsigned char)(total);
    }
}

//MARK: -

kernel void quantizeShader
(
 device Map3D &src [[buffer(0)]],
 constant Control &control [[buffer(1)]],
 uint3 p [[thread_position_in_grid]])
{
    device unsigned char &d = src.data[p.x][p.y][p.z];
    unsigned char mask = (unsigned char)control.param;
    
    if(d > 0 && d < 255) { // only include rendered points
        d = 1 + (d & mask);
    }
}

//MARK: -
// histogram[256] = # points of each value in whole cloud

kernel void histogramShader
(
 constant Map3D &src [[buffer(0)]],
 device Histogram *dst [[buffer(1)]],
 uint3 p [[thread_position_in_grid]])
{
    int value = int(src.data[p.x][p.y][p.z]);
    
    if(value > 0 && value < 255) { // only include rendered points
        dst->count[value] += 1;
    }
}

//MARK: -

kernel void verticeShader
(
 constant Map3D &src        [[buffer(0)]], // source point cloud
 device atomic_uint &counter[[buffer(1)]], // global value = # vertices in output
 constant Control &control  [[buffer(2)]], // control params from Swift
 constant float3 *color     [[buffer(3)]], // color lookup table[256]
 device TVertex *vertices   [[buffer(4)]], // output list of vertices to render
 uint3 p [[thread_position_in_grid]])
{
    if(control.hop > 1) {       // 'fast calc' skips most coordinates
        if(int(p.x) % control.hop) return;
        if(int(p.y) % control.hop) return;
        if(int(p.z) % control.hop) return;
    }
    
    int cIndex = int(src.data[p.x][p.y][p.z]);
    if(cIndex == 0 || cIndex >= 255) return;     // non-rendered point

    int ccIndex;
    
    if(cIndex >= MAX_ITERATIONS) {  // dithered pixels for large spheres in Apollonian mode
        int skip = p.x + p.y * p.z;
        if((skip & 15) != 15) return;
        ccIndex = control.pColor[1];
    }
    else {
        ccIndex = control.pColor[cIndex];
    }
    
    if(ccIndex == 0) return;
    
    uint index = atomic_load(&counter);     // our assigned output vertex index
    if(index >= VMAX) return;
    index = atomic_fetch_add_explicit(&counter, 1, memory_order_relaxed);
    if(index >= VMAX) return;
    
    device TVertex &v = vertices[index];
    float offset = float(control.cloudIndex) / float(NUM_CLOUD);
    float center = float(WIDTH/2) + offset;

    v.pos.x = (float(p.x) - center) / 2;
    v.pos.y = (float(p.y) - center) / 2;
    v.pos.z = (float(p.z) - center) / 2;
    
    v.color = float4(color[ccIndex],1);
}

//MARK: -

struct Transfer {
    float4 position [[position]];
    float pointsize [[point_size]];
    float4 color;
};

vertex Transfer texturedVertexShader
(
 constant TVertex *data[[ buffer(0) ]],
 constant Uniforms &uniforms[[ buffer(1) ]],
 unsigned int vid [[ vertex_id ]])
{
    TVertex in = data[vid];
    Transfer out;
    
    out.pointsize = uniforms.pointSize;
    out.color = in.color;
    out.position = uniforms.mvp * float4(in.pos, 1.0);
    return out;
}

fragment half4 texturedFragmentShader
(
 Transfer in [[stage_in]],
 texture2d<float> tex2D [[texture(0)]],
 sampler sampler2D [[sampler(0)]])
{
    return half4(in.color);
}

