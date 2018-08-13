#include "ShaderTypes.h"

Control *cPtr = NULL;

void setControlPointer(Control *ptr) { cPtr = ptr; }

void setPColor(int index, int value) { cPtr->pColor[index] = (unsigned char)(value & 255); }
int  getPColor(int index) { return (int)(cPtr->pColor[index]); }

void pColorClear(void) { for(int i=0;i<MAX_ITERATIONS;++i) cPtr->pColor[i] = 0; }
