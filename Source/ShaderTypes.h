#pragma once
#include <simd/simd.h>

#define MAX_ITERATIONS 40
#define NUM_CLOUD 8
#define VMAX  int((255000000 / sizeof(TVertex)) - 10000)
#define WIDTH 300 // divisible by threadgroups (20)

enum { BULB_1,BULB_2,BULB_3,BULB_4,BULB_5,JULIA,BOX,QJULIA,IFS };

typedef struct {
    unsigned char data[WIDTH][WIDTH][WIDTH];
} Map3D;

typedef struct {
    float basex;
    float basey;
    float basez;
    float scale;
    float power;
    float re1;
    float im1;
    float mult1;
    float zoom1;
    float re2;
    float im2;
    float mult2;
    float zoom2;
    
    int formula;
    int hop;
    int center;
    int spread;
    int offset;
    int range;
    int ifsIndex;
    int cloudIndex;
    int param;
    
    unsigned char pColor[MAX_ITERATIONS];
    
    float future[10];
} Control;

typedef struct {
    int count;
} Counter;

typedef struct {
    int count[256];
} Histogram;

typedef struct {
    matrix_float4x4 projectionMatrix;
    matrix_float4x4 modelViewMatrix;
    matrix_float4x4 mvp;
    vector_float3 light;
    float pointSize;
} Uniforms;

typedef struct {
    vector_float3 pos;
    vector_float4 color;
} TVertex;

#ifndef __METAL_VERSION__

void setControlPointer(Control *ptr);
void setPColor(int index, int value);
int  getPColor(int index);
void pColorClear(void);

#endif

