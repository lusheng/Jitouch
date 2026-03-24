#ifndef MultitouchSupport_h
#define MultitouchSupport_h

#include <CoreFoundation/CoreFoundation.h>
#include <stdbool.h>
#include <stdint.h>

typedef struct __MTDevice* MTDeviceRef;

typedef enum {
    MTTouchStateNotTracking = 0,
    MTTouchStateStartInRange = 1,
    MTTouchStateHoverInRange = 2,
    MTTouchStateMakeTouch = 3,
    MTTouchStateTouching = 4,
    MTTouchStateBreakTouch = 5,
    MTTouchStateLingerInRange = 6,
    MTTouchStateOutOfRange = 7
} MTTouchState;

typedef struct { float x, y; } MTVector;
typedef struct { MTVector pos; MTVector vel; } MTReadout;

typedef struct {
    int frame;
    double timestamp;
    int identifier;
    MTTouchState state;
    int fingerId;
    int handId;
    MTReadout normalized;
    float size;
    int zero1;
    float angle;
    float majorAxis;
    float minorAxis;
    MTReadout mm;
    int zero2[2];
    float zDensity;
} Finger;

typedef int (*MTContactCallbackFunction)(MTDeviceRef device,
                                         Finger *data,
                                         int nFingers,
                                         double timestamp,
                                         int frame);

CFMutableArrayRef MTDeviceCreateList(void);
void MTRegisterContactFrameCallback(MTDeviceRef device, MTContactCallbackFunction callback);
void MTUnregisterContactFrameCallback(MTDeviceRef device, MTContactCallbackFunction callback);
void MTDeviceStart(MTDeviceRef device, int runLoopMode);
void MTDeviceStop(MTDeviceRef device);
bool MTDeviceIsRunning(MTDeviceRef device);
void MTDeviceGetFamilyID(MTDeviceRef device, int *familyID);
void MTDeviceGetDeviceID(MTDeviceRef device, uint64_t *deviceID) __attribute__((weak_import));

#endif
