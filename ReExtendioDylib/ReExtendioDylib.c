#include <math.h>

/*
 * iOS 7 apps reference newer libSystem / libm symbols that don't exist on
 * iOS 6. We provide ABI-correct implementations so the app both links *and*
 * computes correct results at runtime.
 *
 * The *_stret variants are the "struct return" sincos helpers the compiler
 * emits for combined sin/cos calls. They MUST return the real struct by
 * value (sin first, cos second) or the caller reads garbage out of the
 * return registers. There are separate float and double flavours:
 *
 *   ___sincosf_stret  (float)   <- RedBall 4 was crashing on this one
 *   ___sincos_stret   (double)
 */

struct __float2 { float __sinval; float __cosval; };
struct __double2 { double __sinval; double __cosval; };

struct __float2 __sincosf_stret(float __x) {
    struct __float2 __r;
    __r.__sinval = sinf(__x);
    __r.__cosval = cosf(__x);
    return __r;
}

struct __double2 __sincos_stret(double __x) {
    struct __double2 __r;
    __r.__sinval = sin(__x);
    __r.__cosval = cos(__x);
    return __r;
}

double __exp10(double __x) {
    return pow(10.0, __x);
}

float __exp10f(float __x) {
    return (float)pow(10.0, (double)__x);
}
