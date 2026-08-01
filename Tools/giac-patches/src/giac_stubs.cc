// Stub implementations for pruned GIAC builds.
//
// When a module is disabled at configure time (--disable-giac-XXX),
// its source files are dropped from libgiac and GIAC_NO_XXX is
// defined. The core sources still reference a few symbols from the
// disabled modules; those references are resolved here.
//
// Design notes:
//  - unary_function_ptr at_* objects are defined with parser_token=0,
//    so their command names are NOT registered with the lexer: typing
//    e.g. NORMALD(...) reports "unknown command" instead of silently
//    calling a stub (same observable behaviour as the module missing).
//  - gen-returning stubs return an error (or a neutral value where
//    the caller expects data, e.g. random generators return 0),
//    bool-returning stubs return false, string-returning stubs return
//    an empty string, numeric stubs return 0.
//  - Re-enabling a module (configure without --disable-giac-XXX)
//    makes these branches disappear: nothing else to clean up.
//
// Cross-module dependencies (documented):
//  - at_division / at_binary_minus / at_int / at_approx / at_exact / at_frac /
//    at_identity / at_copy / at_purge / at_denom / at_numer / at_period and
//    the sort helpers (sortad/_sorta/complex_sort/effectif/giacmin/giacmax)
//    are core commands whose official implementations happen to live in
//    pruned modules (rpn.cc/ti89.cc/maple.cc/moyal.cc/signalprocessing.cc);
//    they are re-implemented verbatim so core behaviour is unchanged.
//  - at_extrema depends on the Groebner basis engine (gbasis8 in cocoa.cc,
//    EXTLIB module). A build without EXTLIB cannot compute extrema (the
//    official gbasis path fails there too), so the command reports an error
//    instead of returning a partial result when GRAPH or EXTLIB is pruned.
//  - at_ratnormal and at_Beta are forwarded to their core implementations
//    (ratnormal, Beta); at_Beta also carries incomplete_beta/beta_mult.
//  - gbasis/greduce and algebraic-number simplification (algnum) rely on
//    gbasis8 (EXTLIB); they fail with "Unable to compute gbasis with giac"
//    when EXTLIB is pruned, matching the official build without CoCoA.
#include <vector>
#include <string>
#include <complex>
#ifdef HAVE_CONFIG_H
#include "config.h"
#endif
using namespace std; // required by giac headers that use unqualified vector etc.
#include "path.h"
#include "first.h"
#include "gen.h"
#include "usual.h"
#include "vecteur.h"
#include "mathml.h"
#include "tex.h"
#include "cocoa.h"
#include "pari.h"
#include "isom.h"
#include "graphtheory.h"
#include "moyal.h"
#include "misc.h"
#include "prog.h"
#include "plot.h"
#include "solve.h"
#include "intg.h"
#include "subst.h"
#include "derive.h"
#include "ifactor.h"
namespace giac { gen _purge(const gen & args,const context * contextptr); gen _trunc(const gen & args,GIAC_CONTEXT); }
#include "lin.h"
#include "static_extern.h" // extern declarations for all at_* objects
#include "optimization.h"
#include "rpn.h"
#include "ti89.h"
#include "sym2poly.h"
#include "permu.h"
#include "plot3d.h"
#include "signalprocessing.h"
#include "maple.h"
#include "help.h"
#include "quater.h"
#include "desolve.h"


namespace giac {

// helper used by all module stub blocks below; define it whenever any module may be disabled
#if defined GIAC_NO_PROBA || defined GIAC_NO_GRAPH || defined GIAC_NO_IOFMT || defined GIAC_NO_EXTLIB || defined GIAC_NO_ISOM || defined GIAC_NO_RPN || defined GIAC_NO_TI89 || defined GIAC_NO_PLOT3D || defined GIAC_NO_QUATER || defined GIAC_NO_SIGNAL || defined GIAC_NO_MAPLE || defined GIAC_NO_DESOLVE || defined GIAC_NO_HELP || defined GIAC_NO_KEXTRA || defined GIAC_NO_PLOT

static gen giac_module_disabled(const char * msg){
  return gensizeerr(msg);
}

#endif

#if defined GIAC_NO_PROBA
// ===================== Probability & statistics (moyal.cc) =====================
// 46 unary_function_ptr at_* objects + 28 helper functions.

static gen giac_stub_proba_unary(const gen &,GIAC_CONTEXT){
  return giac_module_disabled("Probability and statistics module is disabled in this build");
}
static define_unary_function_eval (__STUB_PROBA,giac_stub_proba_unary,"stub");
#define STUB_PROBA_PTR (&__STUB_PROBA)
define_unary_function_ptr5(at_NORMALD, alias_at_NORMALD, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_POISSON, alias_at_POISSON, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_student, alias_at_student, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_studentd, alias_at_studentd, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_fisher, alias_at_fisher, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_fisherd, alias_at_fisherd, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_snedecor, alias_at_snedecor, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_chisquare, alias_at_chisquare, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_chisquared, alias_at_chisquared, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_cauchy, alias_at_cauchy, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_cauchyd, alias_at_cauchyd, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_binomial, alias_at_binomial, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_betad, alias_at_betad, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_exponential, alias_at_exponential, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_exponentiald, alias_at_exponentiald, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_geometric, alias_at_geometric, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_gammad, alias_at_gammad, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_poisson, alias_at_poisson, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_uniform, alias_at_uniform, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_uniformd, alias_at_uniformd, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_normald, alias_at_normald, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_weibulld, alias_at_weibulld, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_multinomial, alias_at_multinomial, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_discreted, alias_at_discreted, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_moyal, alias_at_moyal, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_BINOMIAL, alias_at_BINOMIAL, STUB_PROBA_PTR, 0, 0);
  static void beta_mult(gen &res,gen & a,GIAC_CONTEXT){
  // full implementation copied from moyal.cc:127
  for (;;){
    gen a1=a-1;
    if (!is_positive(a1,contextptr))
      return;
    res=a1*res;
    a=a1;
  }
}
gen incomplete_beta(double a,double b,double p,bool regularize){ // regularize=true by default
    // I_p(a,b)=1/B(a,b)*int(t^(a-1)*(1-t)^(b-1),t=0..p)
    // =p^a*(1-p)^(b-1)/B(a,b)*continued fraction expansion
    // 1/(1+e2/(1+e3/(1+...)))
    // e_2m=-(a+m-1)*(b-m)/(a+2*m-2)/(a+2*m-1)*(x/(1-x))
    // e_2m+1= m*(a+b-1+m)/(a+2*m-1)/(a+2*m)*(x/(1-x))
    // assumes p in [0,1]
    if (p<=0)
      return 0;
    if (a<=0 || b<=0)
      return 1;
    // add here test for returning 1 if b>>a
    if (p>a/double(a+b)){
      gen tmp=incomplete_beta(b,a,1-p,true);
      if (regularize)
	return 1-tmp;
      return Beta(a,b,context0)*(1-tmp);
    }
    // Continued fraction expansion: a1/(b1+a2/(b2+...)))
    // P0=1, P1=a1, Q0=1, Q1=b1
    // j>=2: Pj=bj*Pj-1+aj*Pj-2, Qj=bj*Qj-1+aj*Qj-2
    // Here bm=1, am=em, etc.
    long_double Pm2=0,Pm1=1,Pm,Qm2=1,Qm1=1,Qm,am,x=p/(1-p);
    long_double deux=9007199254740992.,invdeux=1/deux;
    for (long_double m=1;m<100;++m){
      // odd term
      am=-(a+m-1)*(b-m)/(a+2*m-2)/(a+2*m-1)*x;
      Pm=Pm1+am*Pm2;
      Qm=Qm1+am*Qm2;
      Pm2=Pm1; Pm1=Pm;
      Qm2=Qm1; Qm1=Qm;
      // even term
      am=m*(a+b-1+m)/(a+2*m-1)/(a+2*m)*x;
      Pm=Pm1+am*Pm2;
      Qm=Qm1+am*Qm2;
      // cerr << Pm/Qm << " " << Pm2/Qm2 << "\n";
      if (absdouble(Pm/Qm-Pm2/Qm2)<1e-16*absdouble(Pm/Qm)){
	double res=Pm/Qm;
#if 0 // def VISUALC // no lgamma available
	gen r=res/a*std::pow(p,a)*std::pow(1-p,b-1);
	if (regularize)
	  r=r*Gamma(a+b,context0)/Gamma(a,context0)/Gamma(b,context0);
	return r;
#else
	if (regularize)
	  return res/a*std::exp(a*std::log(p)+(b-1)*std::log(1-p)+lngamma(a+b)-lngamma(a)-lngamma(b));
	return res/a*std::exp(a*std::log(p)+(b-1)*std::log(1-p));
#endif
      }	
      Pm2=Pm1; Pm1=Pm;
      Qm2=Qm1; Qm1=Qm;
      if (absdouble(Pm)>deux){
	Pm2 *= invdeux; Qm2 *= invdeux; Pm1 *= invdeux; Qm1 *= invdeux;
      }
      if (absdouble(Pm)<invdeux){
	Pm2 *= deux; Qm2 *= deux; Pm1 *= deux; Qm1 *= deux;
      }
    }
    return undef; //error
  }

  gen Beta(const gen & a,const gen& b,GIAC_CONTEXT){
    if (a.type==_DOUBLE_ || b.type==_DOUBLE_ ||
	a.type==_FLOAT_ || b.type==_FLOAT_ ||
	a.type==_CPLX || b.type==_CPLX ){
      gen A=evalf_double(a,1,contextptr);
      gen B=evalf_double(b,1,contextptr);
      gen C=lngamma(A+B,contextptr);
      A=lngamma(A,contextptr);
      B=lngamma(B,contextptr);
      C=A+B-C;
      C=exp(C,contextptr);
      return C;
    }
    gen n;
    if (a.type==_FRAC && b.type==_FRAC && is_positive(a,contextptr) && is_positive(b,contextptr) && is_integer( (n=a+b) )){
      gen res=1,a_(a),b_(b);
      beta_mult(res,a_,contextptr);
      beta_mult(res,b_,contextptr);
      if (a_+b_==1){
	return ratnormal(res*cst_pi/sin(cst_pi*a_,contextptr)/Gamma(n,contextptr),contextptr);
      }
    }
    return Gamma(a,contextptr)*Gamma(b,contextptr)/Gamma(a+b,contextptr);
  }

static const char _Beta_s []="Beta";
gen _Beta(const gen & args,GIAC_CONTEXT){
  // full implementation copied from moyal.cc:160
  if ( args.type==_STRNG && args.subtype==-1) return  args;
  if (args.type!=_VECT)
    return symbolic(at_Beta,args);
  vecteur v=*args._VECTptr;
  int s=int(v.size());
  if (s>2 && (v[0].type==_DOUBLE_ || v[1].type==_DOUBLE_ || v[2].type==_DOUBLE_ || v[0].type==_REAL || v[1].type==_REAL || v[2].type==_REAL)){
    gen tmp=evalf_double(v,1,contextptr);
    if (tmp.type==_VECT)
      v=*tmp._VECTptr;
    s=int(v.size());
  }
  if ( (s==3 || s==4) && v[0].type==_DOUBLE_ && v[1].type==_DOUBLE_ && v[2].type==_DOUBLE_ ){
    return incomplete_beta(v[0]._DOUBLE_val,v[1]._DOUBLE_val,v[2]._DOUBLE_val, s==4 && !is_zero(v[3]) );
  }
  if (s<2 || s>4)
    return gendimerr(contextptr);
  if (s==4){
    if (is_zero(v[3]))
      return symbolic(at_Beta,makesequence(v[0],v[1],v[2]));
    return symbolic(at_Beta,makesequence(v[0],v[1],v[2]))/Beta(v[0],v[1],contextptr);
  }
  if (s!=2)
    return symbolic(at_Beta,args);
  return Beta(v[0],v[1],contextptr);
}
static define_unary_function_eval (__STUB_BETA,&_Beta,_Beta_s);
define_unary_function_ptr5(at_Beta, alias_at_Beta, &__STUB_BETA, 0, true);
define_unary_function_ptr5(at_randNorm, alias_at_randNorm, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_randexp, alias_at_randexp, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_randpoisson, alias_at_randpoisson, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_randbinomial, alias_at_randbinomial, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_randbetad, alias_at_randbetad, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_randchisquare, alias_at_randchisquare, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_randchisquared, alias_at_randchisquared, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_randfisher, alias_at_randfisher, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_randfisherd, alias_at_randfisherd, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_randgammad, alias_at_randgammad, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_randgeometric, alias_at_randgeometric, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_randnormald, alias_at_randnormald, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_randstudent, alias_at_randstudent, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_randstudentd, alias_at_randstudentd, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_randweibulld, alias_at_randweibulld, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_UTPC, alias_at_UTPC, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_UTPF, alias_at_UTPF, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_UTPT, alias_at_UTPT, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_Airy_Ai, alias_at_Airy_Ai, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_BesselJ, alias_at_BesselJ, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_upper_incomplete_gamma, alias_at_upper_incomplete_gamma, STUB_PROBA_PTR, 0, 0);

static gen giac_stub_proba_gen(const gen &,GIAC_CONTEXT){
  return giac_module_disabled("Probability and statistics module is disabled in this build");
}
gen _chisquare(const gen & args,GIAC_CONTEXT){ return giac_stub_proba_gen(args,contextptr); }
gen _randNorm(const gen & args,GIAC_CONTEXT){ return giac_stub_proba_gen(args,contextptr); }
gen _randexp(const gen & args,GIAC_CONTEXT){ return giac_stub_proba_gen(args,contextptr); }
gen _snedecor(const gen & args,GIAC_CONTEXT){ return giac_stub_proba_gen(args,contextptr); }
gen _student(const gen & args,GIAC_CONTEXT){ return giac_stub_proba_gen(args,contextptr); }
gen _upper_incomplete_gamma(const gen & args,GIAC_CONTEXT){ return giac_stub_proba_gen(args,contextptr); }
gen binomial_icdf(const gen & n,const gen & p,const gen & x_orig,GIAC_CONTEXT){ return giac_stub_proba_gen(n,contextptr); }
gen randdiscrete(const vecteur & m,GIAC_CONTEXT) {
    int n;
    if (m.empty() || !m.front().is_integer() || (n=m.front().val)<1)
      return gensizeerr(contextptr);
    double ran1=giac_rand(contextptr)/(rand_max2+1.0);
    double ran2=giac_rand(contextptr)/(rand_max2+1.0);
    int i=std::floor(n*ran1);
    int index=is_strictly_greater(m[i+1],ran2,contextptr)?i:m[n+i+1].val;
    if (int(m.size()-1)==3*n)
      return m[2*n+index+1];
    return index+array_start(contextptr);
}
gen randbinomial(int n,double P,GIAC_CONTEXT){ return giac_stub_proba_gen(gen(n),contextptr); }
// Real implementations below are copied verbatim from moyal.cc (PROBA
// module). They only depend on core APIs (giac_rand/rand_max2, lngamma,
// std math), so pruning PROBA keeps rand/randNorm/randpoisson/rgamma/
// Gamma(2-arg DOUBLE path) numerically correct. The lambda>700 branch of
// randpoisson would need poisson_icdf (pruned) and reports an error
// instead of returning a wrong value.
double unif_rand(GIAC_CONTEXT){
  return giac_rand(contextptr)/(rand_max2+1.0);
}
double exp_rand(GIAC_CONTEXT){
  double u=giac_rand(contextptr)/(rand_max2+1.0);
  return -std::log(1-u);
}
double randNorm(GIAC_CONTEXT){
  double u=giac_rand(contextptr)/(rand_max2+1.0);
  double d=giac_rand(contextptr)/(rand_max2+1.0);
  return std::sqrt(-2*std::log(u))*std::cos(2*M_PI*d);
}
// randpoisson(lambda) returns k>0 with proba poisson(lambda,k)
gen randpoisson(double lambda,GIAC_CONTEXT){
  if (lambda>700)
    return giac_stub_proba_gen(gen(lambda),contextptr); // needs poisson_icdf (pruned)
  int k=0;
  if (lambda<200){
    double seuil=std::exp(-lambda);
    double res=1.0;
    for (;;++k){
      res *= giac_rand(contextptr)/(rand_max2+1.0);
      if (res<seuil)
        return k;
    }
  }
  double res=0.0;
  for (;;++k){
    double u = giac_rand(contextptr)/(rand_max2+1.0);
    res += -std::log(1-u)/lambda;
    if (res>=1.0)
      return k;
  }
}
// rgamma: R algorithm (moyal.cc), verbatim
double rgamma(double a, double scale,GIAC_CONTEXT){
  /* Constants : */
  const static double sqrt32 = 5.656854;
  const static double exp_m1 = 0.36787944117144232159;/* exp(-1) = 1/e */

  /* Coefficients q[k] - for q0 = sum(q[k]*a^(-k))
   * Coefficients a[k] - for q = q0+(t*t/2)*sum(a[k]*v^k)
   * Coefficients e[k] - for exp(q)-1 = sum(e[k]*q^k)
   */
  const static double q1 = 0.04166669;
  const static double q2 = 0.02083148;
  const static double q3 = 0.00801191;
  const static double q4 = 0.00144121;
  const static double q5 = -7.388e-5;
  const static double q6 = 2.4511e-4;
  const static double q7 = 2.424e-4;

  const static double a1 = 0.3333333;
  const static double a2 = -0.250003;
  const static double a3 = 0.2000062;
  const static double a4 = -0.1662921;
  const static double a5 = 0.1423657;
  const static double a6 = -0.1367177;
  const static double a7 = 0.1233795;

  /* State variables [FIXME for threading!] :*/
  static double aa = 0.;
  static double aaa = 0.;
  static double s, s2, d;    /* no. 1 (step 1) */
  static double q0, b, si, c;/* no. 2 (step 4) */

  double e, p, q, r, t, u, v, w, x, ret_val;

  if (a < 1.) { /* GS algorithm for parameters a < 1 */
    e = 1.0 + exp_m1 * a;
    for (;;) {
      p = e * unif_rand(contextptr);
      if (p >= 1.0) {
        x = -std::log((e - p) / a);
        if (exp_rand(contextptr) >= (1.0 - a) * std::log(x))
          break;
      } else {
        x = std::exp(std::log(p) / a);
        if (exp_rand(contextptr) >= x)
          break;
      }
    }
    return scale * x;
  }

  /* --- a >= 1 : GD algorithm --- */
  /* Step 1: Recalculations of s2, s, d if a has changed */
  if (a != aa) {
    aa = a;
    s2 = a - 0.5;
    s = std::sqrt(s2);
    d = sqrt32 - s * 12.0;
  }
  /* Step 2: t = standard normal deviate, x = (s,1/2) -normal deviate. */
  /* immediate acceptance (i) */
  t = randNorm(contextptr);
  x = s + 0.5 * t;
  ret_val = x * x;
  if (t >= 0.0)
    return scale * ret_val;

  /* Step 3: u = 0,1 - uniform sample. squeeze acceptance (s) */
  u = unif_rand(contextptr);
  if (d * u <= t * t * t)
    return scale * ret_val;

  /* Step 4: recalculations of q0, b, si, c if necessary */
  if (a != aaa) {
    aaa = a;
    r = 1.0 / a;
    q0 = ((((((q7 * r + q6) * r + q5) * r + q4) * r + q3) * r
           + q2) * r + q1) * r;

    /* Approximation depending on size of parameter a */
    /* The constants in the expressions for b, si and c */
    /* were established by numerical experiments */

    if (a <= 3.686) {
      b = 0.463 + s + 0.178 * s2;
      si = 1.235;
      c = 0.195 / s - 0.079 + 0.16 * s;
    } else if (a <= 13.022) {
      b = 1.654 + 0.0076 * s2;
      si = 1.68 / s + 0.275;
      c = 0.062 / s + 0.024;
    } else {
      b = 1.77;
      si = 0.75;
      c = 0.1515 / s;
    }
  }
  /* Step 5: no quotient test if x not positive */
  if (x > 0.0) {
    /* Step 6: calculation of v and quotient q */
    v = t / (s + s);
    if (fabs(v) <= 0.25)
      q = q0 + 0.5 * t * t * ((((((a7 * v + a6) * v + a5) * v + a4) * v
                                + a3) * v + a2) * v + a1) * v;
    else
      q = q0 - s * t + 0.25 * t * t + (s2 + s2) * std::log(1.0 + v);

    /* Step 7: quotient acceptance (q) */
    if (std::log(1.0 - u) <= q)
      return scale * ret_val;
  }

  for(;;) {
    /* Step 8: e = standard exponential deviate
     *  u =  0,1 -uniform deviate
     *  t = (b,si)-double exponential (laplace) sample */
    e = exp_rand(contextptr);
    u = unif_rand(contextptr);
    u = u + u - 1.0;
    if (u < 0.0)
      t = b - si * e;
    else
      t = b + si * e;
    /* Step  9:  rejection if t < tau(1) = -0.71874483771719 */
    if (t >= -0.71874483771719) {
      /* Step 10:  calculation of v and quotient q */
      v = t / (s + s);
      if (fabs(v) <= 0.25)
        q = q0 + 0.5 * t * t *
            ((((((a7 * v + a6) * v + a5) * v + a4) * v + a3) * v
              + a2) * v + a1) * v;
      else
        q = q0 - s * t + 0.25 * t * t + (s2 + s2) * std::log(1.0 + v);
      /* Step 11:  hat acceptance (h) */
      /* (if q not positive go to step 8) */
      if (q > 0.0) {
        w = expm1(q);
        /* if t is rejected sample again at step 8 */
        if (c * fabs(u) <= w * std::exp(e - 0.5 * t * t))
          break;
      }
    }
  } /* repeat .. until  `t' is accepted */
  x = s + 0.5 * t;
  return scale * x * x;
}
gen distribution(int nd){ return giac_stub_proba_gen(gen(nd),0); }
gen icdf(int n){ return giac_stub_proba_gen(gen(n),0); }
double randchisquare(int,GIAC_CONTEXT){ return 0.0; }
double randstudent(int,GIAC_CONTEXT){ return 0.0; }
// exp(-lambda)*sum(lambda^k/k!,k=0..x)
// or 1-exp(-lambda)*sum(lambda^k/k!,k=x+1..inf)
double poisson_cdf(double lambda,double x){
  long_double N=lambda;
  long_double res=0,prod=1;
  int fx=int(std::floor(x));
  if (fx>=lambda){
    for (int i=fx+1;prod>1e-17;){
      res += prod;
      prod *= N;
      ++i;
      prod /= long_double(i);
    }
    res *= std::exp(-N+(fx+1)*std::log(N)-lngamma(fx+2.));
    return 1-res;
  }
  for (int i=fx;i>=0 && prod>1e-17;--i){
    res += prod;
    prod /= N;
    prod *= long_double(i);
  }
  res *= std::exp(-N+fx*std::log(N)-lngamma(fx+1.));
  return res;
}
int distrib_nargs(int nd){ (void)nd; return 0; }
bool distrib_support(int nd,gen & a,gen & b,bool){ (void)nd; a=0; b=0; return false; }
void effectif(const std::vector<int> & x,std::vector<int> & eff,int m){
  // count frequencies; required by _sort integer path in prog.cc
  std::vector<int>::const_iterator it=x.begin(),itend=x.end();
  for (;it!=itend;++it){
    ++eff[*it-m];
  }
}
int giacmax(const std::vector<int> & X){
  // required by _sort integer path in prog.cc (defined in moyal.cc)
  std::vector<int>::const_iterator it=X.begin(),itend=X.end();
  int r=-RAND_MAX;
  for (;it!=itend;++it){
    if (*it>r)
      r=*it;
  }
  return r;
}
int giacmin(const std::vector<int> & X){
  // required by _sort integer path in prog.cc (defined in moyal.cc)
  std::vector<int>::const_iterator it=X.begin(),itend=X.end();
  int r=RAND_MAX;
  for (;it!=itend;++it){
    if (*it<r)
      r=*it;
  }
  return r;
}
bool is_discrete_distribution(int nd){ (void)nd; return false; }
int is_distribution(const gen &){ return 0; }
int is_half_atrig(const gen & x,gen & arg){ (void)x; arg=0; return 0; }
// LambertW (moyal.cc:4238/4310, verbatim): required by core solve() for
// x^a=a^x type exponential equations (solve.cc:678). Pruning PROBA must not
// break core solving, so the real implementations are provided here.
std::complex<double> LambertW(std::complex<double> z,int n){
  // n!=0 is not implemented yet
  if (z==0) return z;
  if (is_undef(z))
    return z;
  if (is_inf(z.real()) && z.real()>0)
    return 703.217754008;
  std::complex<double> w;
  // initial guess
  w=2.0*(M_E*z+1.0);
  if (std::abs(w)<1e-13)
    return -1.0;
  if (std::abs(w)<0.1 && (n==0 || ( n==1 && z.imag()<0) || (n==-1 && z.imag()>0))){
    // near -1/e, set p=sqrt(2(ez+1)), -1+p-1/3*p^2+11/72*p^3+...
    w=std::sqrt(w);
    if (n==0) w=-1.0+w*(1.0+w*(-1./3.+w*11./72.));
    if (n==1 || n==-1) w=-1.0+w*(-1.0+w*(-1./3.-w*11./72.));
  }
  else {
    if (z.imag()==0 && z.real()<1 && w.real()>0 && (n==0 || n==-1)){
      w=1;
      if (n==-1 && z.real()<0){
        double lnw=std::log(-z.real());
        double lnlnw=std::log(-lnw);
        w=lnw-lnlnw+lnlnw/lnw;
      }
    }
    else {
      // almost everywhere Log(z)-ln(Log(z))
      w=std::log(z)+2.0*n*std::complex<double>(0,M_PI);
      if (std::abs(z)>=3)
        w=w-std::log(w);
    }
  }
  if (n==0 && std::abs(z - .5)<=.5)
    w = (0.35173371 * (0.1237166 + 7.061302897 * z)) / (2. + 0.827184 * (1. + 2. * z));// (1,1) Pade approximant for W(z,0)
  if (n==-1 && std::abs(z - .5)<.5)
    w = -((std::complex<double>(2.2591588985 ,4.22096) * (std::complex<double>(-14.073271 ,-33.767687754) * z - std::complex<double>(12.7127,-19.071643) * (1. + 2.*z))) / (2. - std::complex<double>(17.23103,-10.629721) * (1. + 2.*z)));// (1,1) Pade
  if (z.imag()==0 && w.imag()==0){
    double Z=z.real(),W=w.real();
    for (int count=1;count<SOLVER_MAX_ITERATE;++count){
      // wnext=w-(w*exp(w)-z)/(exp(w)*(w+1)-(w+2)*(w*exp(w)-z)/(2*w+2))
      double expw(std::exp(W)),wexpwz(W*expw-Z),w1(W+1.0);
      double wnext(W-wexpwz/(w1*expw-(W+2.0)*wexpwz/w1/2.0));
      if (abs(wnext-W)<1e-13*count*std::abs(W))
        return wnext;
      W=wnext;
    }
    return W;
  }
  for (int count=1;count<SOLVER_MAX_ITERATE;++count){
    // wnext=w-(w*exp(w)-z)/(exp(w)*(w+1)-(w+2)*(w*exp(w)-z)/(2*w+2))
    std::complex<double> expw(std::exp(w)),wexpwz(w*expw-z),w1(w+1.0);
    std::complex<double> wnext(w-wexpwz/(w1*expw-(w+2.0)*wexpwz/w1/2.0));
    if (abs(wnext-w)<1e-13*(1.0+std::abs(w)))
      return wnext;
    w=wnext;
  }
  return w;
}
#ifdef HAVE_LIBMPFR
gen LambertW(const gen & Z,int n){
  gen z(Z);
  if (z==0) return z;
  int nbits=45;
  if (z.type==_REAL)
    nbits=mpfr_get_prec(z._REALptr->inf);
  if (z.type==_CPLX && z._CPLXptr->type==_REAL)
    nbits=mpfr_get_prec(z._CPLXptr->_REALptr->inf);
  // initial guess
  gen w=evalf_double(z,1,context0);
  if (w.type==_DOUBLE_){
    w=LambertW(std::complex<double>(w._DOUBLE_val,0),n);
  }
  else {
    if (w.type!=_CPLX || w.subtype!=3)
      return gensizeerr("Unable to convert to float");
    w=LambertW(std::complex<double>(w._CPLXptr->_DOUBLE_val,(w._CPLXptr+1)->_DOUBLE_val));
  }
  if (nbits<=45)
    return w;
  int addprec=10;
  gen tmp=abs(w,context0);
  if (is_greater(tmp,1,context0))
    addprec += int(std::floor(evalf_double(ln(tmp,context0),1,context0)._DOUBLE_val));
  w=accurate_evalf(w,nbits+addprec);
  z=accurate_evalf(z,nbits+addprec);
  gen eps=accurate_evalf(pow(inv(2,context0),nbits,context0),100);//std::pow(.5,nbits);
  while (1){
    // wnext=w-(w*exp(w)-z)/(exp(w)*(w+1)-(w+2)*(w*exp(w)-z)/(2*w+2))
    gen expw(exp(w,context0)),wexpwz(w*expw-z),w1(w+1);
    gen wnext(w-wexpwz/(w1*expw-(w+2)*wexpwz/w1/2));
    if (is_greater(eps*(1+abs(w,context0)),abs(wnext-w,context0),context0))
      return accurate_evalf(wnext,nbits);
    w=wnext;
  }
}
#endif
define_unary_function_ptr5(at_black, alias_at_black, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_green, alias_at_green, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_white, alias_at_white, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_Test, alias_at_Test, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_brownian, alias_at_brownian, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_bs_delta, alias_at_bs_delta, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_bs_gamma, alias_at_bs_gamma, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_bs_greeks, alias_at_bs_greeks, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_bs_implied_vol, alias_at_bs_implied_vol, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_bs_price, alias_at_bs_price, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_bs_rho, alias_at_bs_rho, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_bs_theta, alias_at_bs_theta, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_bs_vega, alias_at_bs_vega, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_cir, alias_at_cir, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_cov_matrix, alias_at_cov_matrix, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_fit_gbm, alias_at_fit_gbm, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_fit_ou, alias_at_fit_ou, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_gbm, alias_at_gbm, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_mc_bs_price, alias_at_mc_bs_price, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_mc_bs_price_antithetic, alias_at_mc_bs_price_antithetic, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_mc_estimate, alias_at_mc_estimate, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_mc_mean, alias_at_mc_mean, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_mc_mean_antithetic, alias_at_mc_mean_antithetic, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_mlr, alias_at_mlr, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_mlr_beta, alias_at_mlr_beta, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_mlr_ic, alias_at_mlr_ic, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_mlr_mse, alias_at_mlr_mse, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_mlr_predict, alias_at_mlr_predict, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_mlr_r2, alias_at_mlr_r2, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_mlr_residuals, alias_at_mlr_residuals, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_mlr_sigma2, alias_at_mlr_sigma2, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_ornstein_uhlenbeck, alias_at_ornstein_uhlenbeck, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_pca, alias_at_pca, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_pca_eigenvalues, alias_at_pca_eigenvalues, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_pca_explained_ratio, alias_at_pca_explained_ratio, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_pca_loadings, alias_at_pca_loadings, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_pca_scores, alias_at_pca_scores, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_pca_select_q, alias_at_pca_select_q, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_sde_euler, alias_at_sde_euler, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_sde_milstein, alias_at_sde_milstein, STUB_PROBA_PTR, 0, 0);

define_unary_function_ptr5(at_Airy_Bi, alias_at_Airy_Bi, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_BesselI, alias_at_BesselI, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_BesselK, alias_at_BesselK, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_BesselY, alias_at_BesselY, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_UTPN, alias_at_UTPN, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_besselI, alias_at_besselI, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_besselJ, alias_at_besselJ, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_besselK, alias_at_besselK, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_besselY, alias_at_besselY, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_betad_cdf, alias_at_betad_cdf, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_betad_icdf, alias_at_betad_icdf, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_betavariate, alias_at_betavariate, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_binomial_cdf, alias_at_binomial_cdf, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_binomial_icdf, alias_at_binomial_icdf, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_blue, alias_at_blue, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_cauchy_cdf, alias_at_cauchy_cdf, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_cauchy_icdf, alias_at_cauchy_icdf, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_cauchyd_cdf, alias_at_cauchyd_cdf, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_cauchyd_icdf, alias_at_cauchyd_icdf, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_cdf, alias_at_cdf, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_cdfplot, alias_at_cdfplot, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_chisquare_cdf, alias_at_chisquare_cdf, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_chisquare_icdf, alias_at_chisquare_icdf, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_chisquared_cdf, alias_at_chisquared_cdf, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_chisquared_icdf, alias_at_chisquared_icdf, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_chisquaret, alias_at_chisquaret, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_cyan, alias_at_cyan, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_exponential_cdf, alias_at_exponential_cdf, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_exponential_icdf, alias_at_exponential_icdf, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_exponentiald_cdf, alias_at_exponentiald_cdf, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_exponentiald_icdf, alias_at_exponentiald_icdf, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_expovariate, alias_at_expovariate, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_filled, alias_at_filled, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_fisher_cdf, alias_at_fisher_cdf, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_fisher_icdf, alias_at_fisher_icdf, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_fisherd_cdf, alias_at_fisherd_cdf, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_fisherd_icdf, alias_at_fisherd_icdf, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_gammad_cdf, alias_at_gammad_cdf, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_gammad_icdf, alias_at_gammad_icdf, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_gammavariate, alias_at_gammavariate, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_geometric_cdf, alias_at_geometric_cdf, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_geometric_icdf, alias_at_geometric_icdf, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_harmonic, alias_at_harmonic, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_hidden_name, alias_at_hidden_name, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_icdf, alias_at_icdf, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_kolmogorovd, alias_at_kolmogorovd, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_kolmogorovt, alias_at_kolmogorovt, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_magenta, alias_at_magenta, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_mgf, alias_at_mgf, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_negbinomial, alias_at_negbinomial, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_negbinomial_cdf, alias_at_negbinomial_cdf, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_negbinomial_icdf, alias_at_negbinomial_icdf, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_normal_cdf, alias_at_normal_cdf, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_normal_icdf, alias_at_normal_icdf, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_normald_cdf, alias_at_normald_cdf, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_normald_icdf, alias_at_normald_icdf, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_normalt, alias_at_normalt, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_normalvariate, alias_at_normalvariate, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_plotcdf, alias_at_plotcdf, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_poisson_cdf, alias_at_poisson_cdf, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_poisson_icdf, alias_at_poisson_icdf, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_polygamma, alias_at_polygamma, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_randmultinomial, alias_at_randmultinomial, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_red, alias_at_red, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_snedecor_cdf, alias_at_snedecor_cdf, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_snedecor_icdf, alias_at_snedecor_icdf, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_snedecord, alias_at_snedecord, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_snedecord_cdf, alias_at_snedecord_cdf, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_snedecord_icdf, alias_at_snedecord_icdf, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_student_cdf, alias_at_student_cdf, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_student_icdf, alias_at_student_icdf, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_studentd_cdf, alias_at_studentd_cdf, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_studentd_icdf, alias_at_studentd_icdf, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_studentt, alias_at_studentt, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_uniform_cdf, alias_at_uniform_cdf, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_uniform_icdf, alias_at_uniform_icdf, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_uniformd_cdf, alias_at_uniformd_cdf, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_uniformd_icdf, alias_at_uniformd_icdf, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_weibull, alias_at_weibull, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_weibull_cdf, alias_at_weibull_cdf, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_weibull_icdf, alias_at_weibull_icdf, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_weibulld_cdf, alias_at_weibulld_cdf, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_weibulld_icdf, alias_at_weibulld_icdf, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_weibullvariate, alias_at_weibullvariate, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_wilcoxonp, alias_at_wilcoxonp, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_wilcoxons, alias_at_wilcoxons, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_wilcoxont, alias_at_wilcoxont, STUB_PROBA_PTR, 0, 0);
define_unary_function_ptr5(at_yellow, alias_at_yellow, STUB_PROBA_PTR, 0, 0);

#endif // GIAC_NO_PROBA

#if defined GIAC_NO_GRAPH
// ===================== Graph theory (graphtheory.cc) =====================
static gen giac_stub_graph_unary(const gen &,GIAC_CONTEXT){
  return giac_module_disabled("Graph theory module is disabled in this build");
}
static define_unary_function_eval (__STUB_GRAPH,giac_stub_graph_unary,"stub");
#define STUB_GRAPH_PTR (&__STUB_GRAPH)
define_unary_function_ptr5(at_edges, alias_at_edges, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_foldl, alias_at_foldl, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_foldr, alias_at_foldr, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_girth, alias_at_girth, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_graph, alias_at_graph, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_icomp, alias_at_icomp, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_trail, alias_at_trail, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_add_arc, alias_at_add_arc, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_add_edge, alias_at_add_edge, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_add_vertex, alias_at_add_vertex, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_adjacency_matrix, alias_at_adjacency_matrix, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_allpairs_distance, alias_at_allpairs_distance, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_antiprism_graph, alias_at_antiprism_graph, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_arrivals, alias_at_arrivals, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_articulation_points, alias_at_articulation_points, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_assign_edge_weights, alias_at_assign_edge_weights, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_bellman_ford, alias_at_bellman_ford, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_biconnected_components, alias_at_biconnected_components, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_bipartite_matching, alias_at_bipartite_matching, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_canonical_labeling, alias_at_canonical_labeling, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_cartesian_product, alias_at_cartesian_product, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_chromatic_index, alias_at_chromatic_index, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_chromatic_number, alias_at_chromatic_number, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_chromatic_polynomial, alias_at_chromatic_polynomial, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_clique_cover, alias_at_clique_cover, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_clique_cover_number, alias_at_clique_cover_number, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_clique_number, alias_at_clique_number, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_clustering_coefficient, alias_at_clustering_coefficient, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_complete_binary_tree, alias_at_complete_binary_tree, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_complete_graph, alias_at_complete_graph, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_complete_kary_tree, alias_at_complete_kary_tree, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_condensation, alias_at_condensation, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_connected_components, alias_at_connected_components, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_contract_edge, alias_at_contract_edge, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_cycle_basis, alias_at_cycle_basis, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_cycle_graph, alias_at_cycle_graph, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_degree_sequence, alias_at_degree_sequence, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_delete_arc, alias_at_delete_arc, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_delete_edge, alias_at_delete_edge, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_delete_vertex, alias_at_delete_vertex, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_departures, alias_at_departures, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_digraph, alias_at_digraph, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_dijkstra, alias_at_dijkstra, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_discard_edge_attribute, alias_at_discard_edge_attribute, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_discard_graph_attribute, alias_at_discard_graph_attribute, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_discard_vertex_attribute, alias_at_discard_vertex_attribute, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_disjoint_union, alias_at_disjoint_union, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_draw_graph, alias_at_draw_graph, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_edge_connectivity, alias_at_edge_connectivity, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_export_graph, alias_at_export_graph, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_find_cycles, alias_at_find_cycles, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_flow_polynomial, alias_at_flow_polynomial, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_flower_snark, alias_at_flower_snark, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_fundamental_cycle, alias_at_fundamental_cycle, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_get_edge_attribute, alias_at_get_edge_attribute, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_get_edge_weight, alias_at_get_edge_weight, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_get_graph_attribute, alias_at_get_graph_attribute, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_get_vertex_attribute, alias_at_get_vertex_attribute, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_goldberg_snark, alias_at_goldberg_snark, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_graph_automorphisms, alias_at_graph_automorphisms, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_graph_charpoly, alias_at_graph_charpoly, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_graph_complement, alias_at_graph_complement, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_graph_diameter, alias_at_graph_diameter, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_graph_equal, alias_at_graph_equal, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_graph_join, alias_at_graph_join, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_graph_power, alias_at_graph_power, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_graph_rank, alias_at_graph_rank, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_graph_spectrum, alias_at_graph_spectrum, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_graph_union, alias_at_graph_union, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_graph_vertices, alias_at_graph_vertices, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_greedy_color, alias_at_greedy_color, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_grid_graph, alias_at_grid_graph, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_haar_graph, alias_at_haar_graph, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_has_arc, alias_at_has_arc, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_has_edge, alias_at_has_edge, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_highlight_edges, alias_at_highlight_edges, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_highlight_subgraph, alias_at_highlight_subgraph, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_highlight_trail, alias_at_highlight_trail, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_highlight_vertex, alias_at_highlight_vertex, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_hypercube_graph, alias_at_hypercube_graph, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_import_graph, alias_at_import_graph, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_incidence_matrix, alias_at_incidence_matrix, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_incident_edges, alias_at_incident_edges, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_independence_number, alias_at_independence_number, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_induced_subgraph, alias_at_induced_subgraph, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_interval_graph, alias_at_interval_graph, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_is_acyclic, alias_at_is_acyclic, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_is_arborescence, alias_at_is_arborescence, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_is_biconnected, alias_at_is_biconnected, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_is_bipartite, alias_at_is_bipartite, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_is_clique, alias_at_is_clique, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_is_connected, alias_at_is_connected, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_is_cut_set, alias_at_is_cut_set, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_is_directed, alias_at_is_directed, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_is_eulerian, alias_at_is_eulerian, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_is_forest, alias_at_is_forest, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_is_graphic_sequence, alias_at_is_graphic_sequence, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_is_hamiltonian, alias_at_is_hamiltonian, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_is_integer_graph, alias_at_is_integer_graph, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_is_isomorphic, alias_at_is_isomorphic, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_is_network, alias_at_is_network, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_is_planar, alias_at_is_planar, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_is_regular, alias_at_is_regular, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_is_strongly_connected, alias_at_is_strongly_connected, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_is_strongly_regular, alias_at_is_strongly_regular, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_is_tournament, alias_at_is_tournament, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_is_tree, alias_at_is_tree, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_is_triconnected, alias_at_is_triconnected, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_is_two_edge_connected, alias_at_is_two_edge_connected, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_is_vertex_colorable, alias_at_is_vertex_colorable, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_is_weighted, alias_at_is_weighted, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_isomorphic_copy, alias_at_isomorphic_copy, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_johnson_graph, alias_at_johnson_graph, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_kneser_graph, alias_at_kneser_graph, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_kspaths, alias_at_kspaths, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_laplacian_matrix, alias_at_laplacian_matrix, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_lcf_graph, alias_at_lcf_graph, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_line_graph, alias_at_line_graph, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_list_edge_attributes, alias_at_list_edge_attributes, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_list_graph_attributes, alias_at_list_graph_attributes, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_list_vertex_attributes, alias_at_list_vertex_attributes, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_lowest_common_ancestor, alias_at_lowest_common_ancestor, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_make_directed, alias_at_make_directed, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_make_weighted, alias_at_make_weighted, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_maxflow, alias_at_maxflow, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_maximum_clique, alias_at_maximum_clique, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_maximum_degree, alias_at_maximum_degree, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_maximum_independent_set, alias_at_maximum_independent_set, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_maximum_matching, alias_at_maximum_matching, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_minimal_edge_coloring, alias_at_minimal_edge_coloring, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_minimal_spanning_tree, alias_at_minimal_spanning_tree, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_minimal_vertex_coloring, alias_at_minimal_vertex_coloring, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_minimum_cut, alias_at_minimum_cut, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_minimum_degree, alias_at_minimum_degree, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_mycielski, alias_at_mycielski, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_neighbors, alias_at_neighbors, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_network_transitivity, alias_at_network_transitivity, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_number_of_edges, alias_at_number_of_edges, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_number_of_spanning_trees, alias_at_number_of_spanning_trees, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_number_of_triangles, alias_at_number_of_triangles, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_number_of_vertices, alias_at_number_of_vertices, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_odd_girth, alias_at_odd_girth, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_odd_graph, alias_at_odd_graph, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_paley_graph, alias_at_paley_graph, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_path_graph, alias_at_path_graph, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_permute_vertices, alias_at_permute_vertices, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_petersen_graph, alias_at_petersen_graph, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_plane_dual, alias_at_plane_dual, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_prism_graph, alias_at_prism_graph, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_random_bipartite_graph, alias_at_random_bipartite_graph, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_random_digraph, alias_at_random_digraph, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_random_graph, alias_at_random_graph, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_random_network, alias_at_random_network, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_random_planar_graph, alias_at_random_planar_graph, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_random_regular_graph, alias_at_random_regular_graph, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_random_sequence_graph, alias_at_random_sequence_graph, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_random_tournament, alias_at_random_tournament, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_random_tree, alias_at_random_tree, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_random_variable, alias_at_random_variable, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_randvar, alias_at_randvar, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_relabel_vertices, alias_at_relabel_vertices, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_reliability_polynomial, alias_at_reliability_polynomial, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_reverse_graph, alias_at_reverse_graph, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_seidel_spectrum, alias_at_seidel_spectrum, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_seidel_switch, alias_at_seidel_switch, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_sequence_graph, alias_at_sequence_graph, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_set_edge_attribute, alias_at_set_edge_attribute, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_set_edge_weight, alias_at_set_edge_weight, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_set_graph_attribute, alias_at_set_graph_attribute, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_set_vertex_attribute, alias_at_set_vertex_attribute, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_set_vertex_positions, alias_at_set_vertex_positions, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_shortest_path, alias_at_shortest_path, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_sierpinski_graph, alias_at_sierpinski_graph, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_spanning_tree, alias_at_spanning_tree, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_st_ordering, alias_at_st_ordering, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_star_graph, alias_at_star_graph, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_strongly_connected_components, alias_at_strongly_connected_components, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_subdivide_edges, alias_at_subdivide_edges, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_subgraph, alias_at_subgraph, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_tensor_product, alias_at_tensor_product, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_tonnetz, alias_at_tonnetz, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_topologic_sort, alias_at_topologic_sort, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_topological_sort, alias_at_topological_sort, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_torus_grid_graph, alias_at_torus_grid_graph, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_trail2edges, alias_at_trail2edges, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_transitive_closure, alias_at_transitive_closure, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_traveling_salesman, alias_at_traveling_salesman, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_tree_height, alias_at_tree_height, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_truncate_graph, alias_at_truncate_graph, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_tutte_polynomial, alias_at_tutte_polynomial, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_two_edge_connected_components, alias_at_two_edge_connected_components, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_underlying_graph, alias_at_underlying_graph, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_vertex_connectivity, alias_at_vertex_connectivity, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_vertex_degree, alias_at_vertex_degree, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_vertex_distance, alias_at_vertex_distance, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_vertex_in_degree, alias_at_vertex_in_degree, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_vertex_out_degree, alias_at_vertex_out_degree, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_web_graph, alias_at_web_graph, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_weight_matrix, alias_at_weight_matrix, STUB_GRAPH_PTR, 0, 0);
define_unary_function_ptr5(at_wheel_graph, alias_at_wheel_graph, STUB_GRAPH_PTR, 0, 0);

bool is_graphe(const gen & g){ (void)g; return false; }
gen _graph_charpoly(const gen & g,GIAC_CONTEXT){ return giac_module_disabled("Graph theory module is disabled in this build"); }
gen _graph_vertices(const gen & g,GIAC_CONTEXT){ return giac_module_disabled("Graph theory module is disabled in this build"); }
gen _is_planar(const gen & g,GIAC_CONTEXT){ return giac_module_disabled("Graph theory module is disabled in this build"); }
// at_extrema: officially implemented in optimization.cc (GRAPH module); its
// computation relies on the Groebner basis engine (gbasis8) which lives in
// cocoa.cc (EXTLIB module). A build without EXTLIB cannot compute extrema
// (the official gbasis path fails there too), so when either module is pruned
// the command reports an error instead of returning a partial result.
static gen giac_stub_extrema(const gen & args,GIAC_CONTEXT){
  return giac_module_disabled("extrema requires the external CAS module (Groebner basis engine), which is disabled in this build");
}
static define_unary_function_eval_quoted (__STUB_EXTREMA,giac_stub_extrema,"extrema");
define_unary_function_ptr5(at_extrema, alias_at_extrema, &__STUB_EXTREMA, _QUOTE_ARGUMENTS, true);
#endif // GIAC_NO_GRAPH

#if defined GIAC_NO_IOFMT
// ===================== MathML/TeX/Markup output (mathml.cc, tex.cc, markup.cc) =====================
gen _mathml(const gen & g,GIAC_CONTEXT){ return giac_module_disabled("MathML/TeX output module is disabled in this build"); }
gen _latex(const gen & g,GIAC_CONTEXT){ return giac_module_disabled("MathML/TeX output module is disabled in this build"); }
static gen giac_stub_mathml_unary(const gen & g,GIAC_CONTEXT){ return giac_module_disabled("MathML/TeX output module is disabled in this build"); }
static define_unary_function_eval (__STUB_MATHML,giac_stub_mathml_unary,"mathml");
define_unary_function_ptr5(at_mathml, alias_at_mathml, &__STUB_MATHML, 0, true);
static gen giac_stub_latex_unary(const gen & g,GIAC_CONTEXT){ return giac_module_disabled("MathML/TeX output module is disabled in this build"); }
static define_unary_function_eval (__STUB_LATEX,giac_stub_latex_unary,"latex");
define_unary_function_ptr5(at_latex, alias_at_latex, &__STUB_LATEX, 0, true);
define_unary_function_ptr5(at_TeX, alias_at_TeX, &__STUB_MATHML, 0, true);
define_unary_function_ptr5(at_graph2tex, alias_at_graph2tex, &__STUB_MATHML, 0, true);
define_unary_function_ptr5(at_graph3d2tex, alias_at_graph3d2tex, &__STUB_MATHML, 0, true);

define_unary_function_ptr5(at_spread2mathml, alias_at_spread2mathml, &__STUB_MATHML, 0, true);
define_unary_function_ptr5(at_svg, alias_at_svg, &__STUB_MATHML, 0, true);

void arc_en_ciel(int k,int & r,int & g,int & b){ (void)k; r=g=b=0; }
std::string gen2tex(const gen & e,GIAC_CONTEXT){
  // Full implementation lives in tex.cc (IOFMT module, pruned). Returning
  // explicit error text (not an empty string) so any internal caller sees
  // a failure instead of silently broken TeX.
  (void)e;
  return std::string("Error in Tex conversion (IOFMT module disabled)");
}
std::string get_path(const std::string & st){
  int s=int(st.size()),i;
  for (i=s-1;i>=0;--i){
    if (st[i]=='/')
      break;
  }
  return st.substr(0,i+1);
}
std::string remove_path(const std::string & st){
  int s=int(st.size()),i;
  for (i=s-1;i>=0;--i){
    if (st[i]=='/')
      break;
  }
  return st.substr(i+1,s-i-1);
}
std::string translate_underscore(const std::string & s){ return s; }
std::string gen2scm(const gen & g,GIAC_CONTEXT){ (void)g; return std::string(); }
void enable_texmacs_compatible_latex_export(bool yes){ (void)yes; }
std::string export_mathml(const gen & g,GIAC_CONTEXT){ (void)g; return std::string(); }
std::string export_mathml_presentation(const gen & g,GIAC_CONTEXT){ (void)g; return std::string(); }
std::string export_mathml_content(const gen & g,GIAC_CONTEXT){ (void)g; return std::string(); }
gen _export_mathml(const gen & g,GIAC_CONTEXT){ return giac_module_disabled("MathML/TeX output module is disabled in this build"); }
const char tex_preamble[] = "\\documentclass{article}\\usepackage{amsmath}";
const char tex_end[] = "\\end{document}";
#endif // GIAC_NO_IOFMT

#if defined GIAC_NO_EXTLIB
// ===================== External CAS bindings (cocoa.cc, pari.cc) =====================
static gen giac_stub_extlib_unary(const gen &,GIAC_CONTEXT){
  return giac_module_disabled("External CAS module is disabled in this build");
}
static define_unary_function_eval (__STUB_EXTLIB,giac_stub_extlib_unary,"stub");
#define STUB_EXTLIB_PTR (&__STUB_EXTLIB)
bool f5(vectpoly &,const gen & order){ (void)order; return false; }
bool cocoa_gbasis(vectpoly &,const gen & order){ (void)order; return false; }
bool cocoa_greduce(const vectpoly &,const vectpoly &,const gen & order,vectpoly & res){ (void)order; res.clear(); return false; }
bool gbasis8(const vectpoly & v,order_t & order,vectpoly & res,environment * env,bool,bool,int & rur,GIAC_CONTEXT,gbasis_param_t,vector<vectpoly> * coeffsmodptr){
  (void)v;(void)order;(void)res;(void)env;(void)rur; if (coeffsmodptr) coeffsmodptr->clear(); return false;
}
bool greduce8(const vectpoly &,const vectpoly &,order_t &,vectpoly &,environment *,GIAC_CONTEXT){ return false; }
longlong memory_usage(){ return 0; }
bool pari_galoisconj(const gen & g,vecteur & w,GIAC_CONTEXT){ (void)g; w.clear(); return false; }
bool pari_polroots(const vecteur & p,vecteur & res,long prec,GIAC_CONTEXT){ (void)p;(void)prec; res.clear(); return false; }
bool pari_polroots(const vecteur & p,vecteur & res,longlong prec,GIAC_CONTEXT){ (void)p;(void)prec; res.clear(); return false; }
define_unary_function_ptr5(at_pari, alias_at_pari, STUB_EXTLIB_PTR, 0, 0);
define_unary_function_ptr5(at_pari_unlock, alias_at_pari_unlock, STUB_EXTLIB_PTR, 0, 0);

#endif // GIAC_NO_EXTLIB

#if defined GIAC_NO_ISOM
// ===================== Isometries (isom.cc) =====================
static gen giac_stub_isom_unary(const gen &,GIAC_CONTEXT){
  return giac_module_disabled("Isometries module is disabled in this build");
}
static define_unary_function_eval (__STUB_ISOM,giac_stub_isom_unary,"stub");
#define STUB_ISOM_PTR (&__STUB_ISOM)
define_unary_function_ptr5(at_isom, alias_at_isom, STUB_ISOM_PTR, 0, 0);
define_unary_function_ptr5(at_mkisom, alias_at_mkisom, STUB_ISOM_PTR, 0, 0);
vecteur mkisom(const gen & n,int b,GIAC_CONTEXT){ (void)n;(void)b; return vecteur(); }
#endif // GIAC_NO_ISOM

#if defined GIAC_NO_RPN
// ===================== RPN mode (rpn.cc) =====================
static gen giac_stub_rpn_unary(const gen &,GIAC_CONTEXT){
  return giac_module_disabled("RPN mode module is disabled in this build");
}
static define_unary_function_eval (__STUB_RPN,giac_stub_rpn_unary,"stub");
#define STUB_RPN_PTR (&__STUB_RPN)
define_unary_function_ptr5(at_Ans, alias_at_Ans, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_COS, alias_at_COS, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_DELTALIST, alias_at_DELTALIST, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_EXP, alias_at_EXP, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_HAngle, alias_at_HAngle, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_HComplex, alias_at_HComplex, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_HDigits, alias_at_HDigits, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_HFormat, alias_at_HFormat, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_HLanguage, alias_at_HLanguage, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_HPDIFF, alias_at_HPDIFF, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_HPINT, alias_at_HPINT, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_HPSUM, alias_at_HPSUM, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_IFTE, alias_at_IFTE, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_NOP, alias_at_NOP, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_NTHROOT, alias_at_NTHROOT, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_PERCENT, alias_at_PERCENT, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_PILIST, alias_at_PILIST, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_RPN_CASE, alias_at_RPN_CASE, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_RPN_FOR, alias_at_RPN_FOR, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_RPN_LOCAL, alias_at_RPN_LOCAL, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_RPN_WHILE, alias_at_RPN_WHILE, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_SIGMALIST, alias_at_SIGMALIST, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_SIN, alias_at_SIN, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_TAN, alias_at_TAN, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_VARS, alias_at_VARS, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_alg, alias_at_alg, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_polar_complex, alias_at_polar_complex, STUB_RPN_PTR, 0, 0);
gen _purge(const gen & args,const context * contextptr);
static const char _STUB_purge_s []="purge";
static define_unary_function_eval_quoted (__STUB_PURGE,&_purge,_STUB_purge_s);
define_unary_function_ptr5(at_purge, alias_at_purge, &__STUB_PURGE, _QUOTE_ARGUMENTS, 0);
define_unary_function_ptr5(at_rpn, alias_at_rpn, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_rpn_prog, alias_at_rpn_prog, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_ACOSH, alias_at_ACOSH, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_ASINH, alias_at_ASINH, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_ATANH, alias_at_ATANH, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_CROSS, alias_at_CROSS, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_EXPM1, alias_at_EXPM1, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_FLOOR, alias_at_FLOOR, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_INPUT, alias_at_INPUT, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_MINUS, alias_at_MINUS, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_PIXON, alias_at_PIXON, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_PRINT, alias_at_PRINT, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_QUOTE, alias_at_QUOTE, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_REDIM, alias_at_REDIM, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_ROLLD, alias_at_ROLLD, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_ROUND, alias_at_ROUND, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_SCALE, alias_at_SCALE, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_SCHUR, alias_at_SCHUR, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_TRACE, alias_at_TRACE, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_UNION, alias_at_UNION, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_VIEWS, alias_at_VIEWS, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_expm1, alias_at_expm1, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_frexp, alias_at_frexp, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_ldexp, alias_at_ldexp, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_log1p, alias_at_log1p, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_redim, alias_at_redim, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_scale, alias_at_scale, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_schur, alias_at_schur, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_tests, alias_at_tests, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_ABS, alias_at_ABS, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_ACOS, alias_at_ACOS, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_ACOT, alias_at_ACOT, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_ACSC, alias_at_ACSC, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_ADDCOL, alias_at_ADDCOL, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_ADDROW, alias_at_ADDROW, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_ALOG, alias_at_ALOG, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_ARC, alias_at_ARC, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_ASEC, alias_at_ASEC, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_ASIN, alias_at_ASIN, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_ATAN, alias_at_ATAN, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_CEILING, alias_at_CEILING, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_CHOOSE, alias_at_CHOOSE, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_COLNORM, alias_at_COLNORM, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_COMB, alias_at_COMB, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_CONCAT, alias_at_CONCAT, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_COND, alias_at_COND, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_CONJ, alias_at_CONJ, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_COSH, alias_at_COSH, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_COT, alias_at_COT, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_CSC, alias_at_CSC, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_Celsius2Fahrenheit, alias_at_Celsius2Fahrenheit, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_DEGXRAD, alias_at_DEGXRAD, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_DELCOL, alias_at_DELCOL, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_DELROW, alias_at_DELROW, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_DET, alias_at_DET, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_DISP, alias_at_DISP, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_DOT, alias_at_DOT, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_DROP, alias_at_DROP, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_DUP, alias_at_DUP, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_EDITMAT, alias_at_EDITMAT, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_EIGENVAL, alias_at_EIGENVAL, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_EIGENVV, alias_at_EIGENVV, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_EXPORT, alias_at_EXPORT, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_FNROOT, alias_at_FNROOT, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_Fahrenheit2Celsius, alias_at_Fahrenheit2Celsius, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_GETKEY, alias_at_GETKEY, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_HMSX, alias_at_HMSX, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_IDENMAT, alias_at_IDENMAT, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_IM, alias_at_IM, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_INT, alias_at_INT, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_INTERSECT, alias_at_INTERSECT, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_INVERSE, alias_at_INVERSE, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_ISOLATE, alias_at_ISOLATE, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_IS_LINEAR, alias_at_IS_LINEAR, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_ITERATE, alias_at_ITERATE, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_LINE, alias_at_LINE, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_LN, alias_at_LN, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_LNP1, alias_at_LNP1, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_LOG, alias_at_LOG, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_LQ, alias_at_LQ, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_LSQ, alias_at_LSQ, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_MAKELIST, alias_at_MAKELIST, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_MAKEMAT, alias_at_MAKEMAT, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_MANT, alias_at_MANT, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_MAX, alias_at_MAX, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_MAXREAL, alias_at_MAXREAL, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_MIN, alias_at_MIN, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_MINREAL, alias_at_MINREAL, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_MOD, alias_at_MOD, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_MSGBOX, alias_at_MSGBOX, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_OVER, alias_at_OVER, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_PERCENTCHANGE, alias_at_PERCENTCHANGE, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_PERCENTTOTAL, alias_at_PERCENTTOTAL, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_PERM, alias_at_PERM, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_PICK, alias_at_PICK, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_PIXOFF, alias_at_PIXOFF, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_POLYCOEF, alias_at_POLYCOEF, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_POLYEVAL, alias_at_POLYEVAL, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_POLYFORM, alias_at_POLYFORM, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_POLYROOT, alias_at_POLYROOT, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_POS, alias_at_POS, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_QUAD, alias_at_QUAD, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_RADXDEG, alias_at_RADXDEG, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_RANDMAT, alias_at_RANDMAT, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_RANDOM, alias_at_RANDOM, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_RANDSEED, alias_at_RANDSEED, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_RANK, alias_at_RANK, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_RCL, alias_at_RCL, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_RE, alias_at_RE, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_RECT, alias_at_RECT, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_RECURSE, alias_at_RECURSE, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_REPLACE, alias_at_REPLACE, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_REVERSE, alias_at_REVERSE, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_ROLL, alias_at_ROLL, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_ROWNORM, alias_at_ROWNORM, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_RPN_UNTIL, alias_at_RPN_UNTIL, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_RREF, alias_at_RREF, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_SCALEADD, alias_at_SCALEADD, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_SEC, alias_at_SEC, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_SIGN, alias_at_SIGN, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_SINH, alias_at_SINH, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_SIZE, alias_at_SIZE, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_SORT, alias_at_SORT, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_SPECNORM, alias_at_SPECNORM, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_SPECRAD, alias_at_SPECRAD, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_SUB, alias_at_SUB, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_SVD, alias_at_SVD, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_SVL, alias_at_SVL, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_SWAP, alias_at_SWAP, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_SWAPCOL, alias_at_SWAPCOL, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_SWAPROW, alias_at_SWAPROW, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_TANH, alias_at_TANH, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_TAYLOR, alias_at_TAYLOR, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_TRN, alias_at_TRN, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_TRUNCATE, alias_at_TRUNCATE, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_WAIT, alias_at_WAIT, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_XHMS, alias_at_XHMS, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_XPON, alias_at_XPON, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_colSwap, alias_at_colSwap, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_colswap, alias_at_colswap, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_cond, alias_at_cond, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_copysign, alias_at_copysign, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_ggb_ang, alias_at_ggb_ang, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_hp38, alias_at_hp38, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_lsq, alias_at_lsq, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_mantissa, alias_at_mantissa, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_pointer, alias_at_pointer, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_replace, alias_at_replace, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_scaleadd, alias_at_scaleadd, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_svl, alias_at_svl, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_swapcol, alias_at_swapcol, STUB_RPN_PTR, 0, 0);
define_unary_function_ptr5(at_testfunc, alias_at_testfunc, STUB_RPN_PTR, 0, 0);


// at_division and at_binary_minus are operators used by the parser for
// every '/' and '-' in expressions; they are only defined in rpn.cc.
// When the RPN module is disabled we must still provide real implementations
// (plus their print functions for correct display).
static std::string giac_stub_printasdivision(const gen & feuille,const char * s,GIAC_CONTEXT){
  if (feuille.type!=_VECT || feuille._VECTptr->size()!=2)
    return printsommetasoperator(feuille,s,contextptr);
  gen n=feuille._VECTptr->front();
  bool need=need_parenthesis(n);
  std::string res;
  if (need) res+='(';
  res += n.print(contextptr);
  if (need) res += ')';
  res += '/';
  gen f=feuille._VECTptr->back();
  if ( (f.type==_SYMB && ( f._SYMBptr->sommet==at_plus || f._SYMBptr->sommet==at_prod || f._SYMBptr->sommet==at_division || f._SYMBptr->sommet==at_inv  || need_parenthesis(f._SYMBptr->sommet) )) || (f.type==_CPLX) || (f.type==_MOD) || (f.type==_FRAC)){
    res += '(';
    res += f.print(contextptr);
    res += ')';
  }
  else
    res += f.print(contextptr);
  return res;
}
static std::string giac_stub_texprintasdivision(const gen & feuille,const char * s,GIAC_CONTEXT){
  if (feuille.type!=_VECT || feuille._VECTptr->size()!=2)
    return "invalid /";
  return "\\frac{"+gen2tex(feuille._VECTptr->front(),contextptr)+"}{"+gen2tex(feuille._VECTptr->back(),contextptr)+"}";
}
static gen giac_stub_division(const gen & args,GIAC_CONTEXT){
  // full implementation copied from rpn.cc _division (approx precision paths included)
  if ( args.type==_STRNG && args.subtype==-1) return  args;
  if (args.type!=_VECT || args._VECTptr->size()!=2)
    return symbolic(at_division,args);
  gen a=args._VECTptr->front(),b=args._VECTptr->back();
  if (a.is_approx()){
    gen b1;
    if (has_evalf(b,b1,1,contextptr) && b.type!=b1.type){
#ifdef HAVE_LIBMPFR
      if (a.type==_REAL){
	gen b2=accurate_evalf(b,mpfr_get_prec(a._REALptr->inf));
	if (b2.is_approx())
	  return (*a._REALptr)/b2;
      }
#endif
      return rdiv(a,b1,contextptr);
    }
  }
  if (b.is_approx()){
    gen a1;
    if (has_evalf(a,a1,1,contextptr) && a.type!=a1.type){
#ifdef HAVE_LIBMPFR
      if (b.type==_REAL){
	gen a2=accurate_evalf(a,mpfr_get_prec(b._REALptr->inf));
	if (a2.is_approx())
	  return a2/b;
      }
#endif
      return rdiv(a1,b,contextptr);
    }
  }
  return rdiv(a,b,contextptr);
}
static gen giac_stub_binary_minus(const gen & args,GIAC_CONTEXT){
  if ( args.type==_STRNG && args.subtype==-1) return  args;
  if (args.type!=_VECT || args._VECTptr->size()!=2)
    return symbolic(at_binary_minus,args);
  return args._VECTptr->front()-args._VECTptr->back();
}
static define_unary_function_eval4_index (10,__STUB_DIVISION,&giac_stub_division,"/",&giac_stub_printasdivision,&giac_stub_texprintasdivision);
static define_unary_function_eval4_index (6,__STUB_BINARY_MINUS,&giac_stub_binary_minus,"-",&printsommetasoperator,&texprintsommetasoperator);
define_unary_function_ptr5(at_division, alias_at_division, &__STUB_DIVISION, 0, 0);
define_unary_function_ptr5(at_binary_minus, alias_at_binary_minus, &__STUB_BINARY_MINUS, 0, 0);

gen _RANDOM(const gen & args,GIAC_CONTEXT){ return giac_stub_rpn_unary(args,contextptr); }
bool is_Ans(const gen & g){
  // full implementation copied from rpn.cc:1427
  if (g.type==_FUNC && *g._FUNCptr==at_Ans)
    return true;
  if (g.type==_SYMB && g._SYMBptr->sommet==at_Ans)
    return true;
  return false;
}
gen _LSQ(const gen & args,GIAC_CONTEXT){
    if ( args.type==_STRNG && args.subtype==-1) return  args;
    if (args.type!=_VECT || args._VECTptr->size()<2)
      return gentypeerr(contextptr);
    vecteur v = *args._VECTptr;
    gen v0=v[0]; // evalf(v[0],1,contextptr)
    gen v1=v[1];
    int vs=int(v.size());
    if (vs==3){
      v.push_back(vecteur(0));
      ++vs;
    }
    if (vs==4){
      gen v2=v[2],v3=v[3];
      if (v0.type==_VECT && v1.type==_VECT && !v0._VECTptr->empty() && v0._VECTptr->size()==v1._VECTptr->size() && v2.type==_VECT && v3.type==_VECT){
	// v0=list of values of x or of [x,y,...], v1= observed value at x, 
	// v2=v[vs-2]=list of expressions f_i(x) or f_i(x,y) or [f_i(vars)],[vars]  
	// v3=v.back()=list of constraints = list of 
	// [X_k,n_k (number of derivatives), Y_k=value of n_k-th diff at X_k]
	// or [[X_k,Y_k,...],[n_k],value]
	// minimize sum_j=1..N (y_j-sum_i=1..M(a_i*f_i(x_j),i))^2
	// under sum_i=1..M a_i*diff(f_i,n_k)(X_k) = 0 for k=1..K
	vecteur expr(*v2._VECTptr),constraints(*v3._VECTptr);
	if (!constraints.empty() && constraints.front().type!=_VECT)
	  constraints=vecteur(1,constraints);
	if (!constraints.empty() && (!ckmatrix(constraints) || constraints.front()._VECTptr->size()!=3))
	  return gensizeerr(contextptr);
	vecteur & x=*v0._VECTptr;
	vecteur & y=*v1._VECTptr;
	unsigned M=unsigned(expr.size()), K=unsigned(constraints.size()),N=unsigned(v0._VECTptr->size());
	vecteur vars(1,x__IDNT_e);
	int dim=2;
	if (x.front().type==_VECT){
	  if (!ckmatrix(x))
	    return gensizeerr(contextptr);
	  dim=int(x.front()._VECTptr->size())+1;
	  if (dim<2)
	    return gendimerr(contextptr);
	}
	if (dim==3)
	  vars.push_back(y__IDNT_e);
	if (expr.front().type==_VECT){
	  if (M!=2 || expr.back().type!=_VECT)
	    return gensizeerr(contextptr);
	  vars=*expr.back()._VECTptr;
	  if (int(vars.size())!=dim-1)
	    return gendimerr(contextptr);
	  expr=*expr.front()._VECTptr;
	  M=unsigned(expr.size());
	}
	else {
	  if (dim>3)
	    return gendimerr(contextptr);
	}
	// F_{i,j}=f_i(x_j)
	matrice F; // M rows, N cols
	for (unsigned i=0;i<M;++i){
	  gen fi=expr[i];
	  vecteur ligne;
	  for (unsigned j=0;j<N;++j){
	    ligne.push_back(subst(fi,vars,gen2vecteur(x[j]),false,contextptr));
	  }
	  F.push_back(ligne);
	}
	// dF_{i,k}=diff(f_i,n_k)(X_k)
	matrice dF; // M rows, K cols
	for (unsigned i=0;i<M;++i){
	  gen fi=expr[i];
	  vecteur ligne;
	  for (unsigned k=0;k<K;++k){
	    gen nk=constraints[k][1];
	    gen tmp=derive(fi,vars,gen2vecteur(nk),contextptr);
	    ligne.push_back(subst(tmp,vars,gen2vecteur(constraints[k][0]),false,contextptr));
	  }
	  dF.push_back(ligne);
	}
	matrice mat; // M+K rows, M+K+1 cols
	// first M equations of linear system: for l=1..M
	// sum_i=1..M a_i*sum_j=1..N f_l(x_j)*f_i(x_j) + sum_k=1..K lagrange_k*diff(f_l,n_k)(X_k) = sum_j=1..N f_l(x_j)*y_j
	for (unsigned l=0;l<M;++l){
	  vecteur ligne;
	  for (unsigned i=0;i<M;++i){
	    gen tmp=0;
	    for (unsigned j=0;j<N;++j)
	      tmp += F[l][j]*F[i][j];
	    ligne.push_back(tmp);
	  }
	  for (unsigned k=0;k<K;++k){
	    ligne.push_back(dF[l][k]);
	  }
	  gen tmp=0;
	  for (unsigned j=0;j<N;++j){
	    tmp += F[l][j]*y[j];
	  }
	  ligne.push_back(tmp);
	  mat.push_back(ligne);
	}
	// last K equations
	// sum_i=1..M a_i*diff(f_i,n_k)(X_k)=Y_k
	// giving a (M+K,M+K) matrix -> linsolve, first M coordinates 
	// -> sum_i=1..M a_i f_i(x)
	for (unsigned k=0;k<K;++k){
	  vecteur ligne(M+K+1);
	  ligne[M+K]=constraints[k][2];
	  for (unsigned i=0;i<M;++i){
	    ligne[i]=dF[i][k];
	  }
	  mat.push_back(ligne);
	}
	// now solve linear system
	vecteur res=mker(mat,contextptr);
	if (res.size()!=1 || res.front().type!=_VECT || res.front()._VECTptr->size()!=M+K+1)
	  return gensizeerr("Singular linear system");
	vecteur Res=*res.front()._VECTptr;
	res=vecteur(Res.begin(),Res.begin()+M);
	return gen(res);
      }
      else
	return gensizeerr(contextptr);
    }
    if (!ckmatrix(v0) || v1.type!=_VECT)
      return gentypeerr(contextptr);
    int neq=int(v0._VECTptr->size()); // neq equations
    v0=_trn(v0,contextptr);
    matrice A=*v0._VECTptr,B;
    if (ckmatrix(v1))
      B=gen2vecteur(_trn(v1,contextptr));
    else
      B=vecteur(1,v1);
    if (int(B[0]._VECTptr->size())!=neq)
      return gendimerr(contextptr);
    int as=int(A.size()),bs=int(B.size()); 
    // bs system to solve, each with neq equations and as variables
    if (as>neq){ // under-determined system, find the smallest solution
      if (has_num_coeff(A)){
	// QR factorization of A=trn(system matrix) 
	// R_1=neq first rows of R
	// Q_1=neq first cols of Q
	// solve R_1^* c = B[i] then output Q_1*c
	gen qrdec=qr(A,contextptr);
	if (qrdec.type==_VECT && qrdec._VECTptr->size()==2){
	  gen q=qrdec._VECTptr->front(),r=qrdec._VECTptr->back();
	  if (ckmatrix(q) && ckmatrix(r)){ 
	    if (!is_zero(r[neq-1])){
	      vecteur R(r._VECTptr->begin(),r._VECTptr->begin()+neq);
	      r=mtran(R);
	      R=*r._VECTptr;
	      vecteur qt=mtran(*q._VECTptr);
	      matrice res;
	      qt=vecteur(qt.begin(),qt.begin()+neq);
	      qt=mtran(qt);
	      for (int i=0;i<bs;++i){
		gen Bi=B[i];
		vecteur v,w;
		linsolve_l(R,*Bi._VECTptr,v);
		multmatvecteur(qt,v,w);
		res.push_back(w);
	      }
	      return mtran(res);
	    }
	  }
	}
      }
      // not optimal since we solve the system for each Bi
      A.push_back(0);
      matrice res;
      for (int i=0;i<bs;++i){
	gen Bi=B[i];
	A[as]=Bi;
	matrice At=gen2vecteur(_trn(A,contextptr));
	vecteur B=mker(At,contextptr);
	if (is_undef(B) || B.empty())
	  return undef;
	// The last element of B must have a non-zero last component
	vecteur Bend=*B.back()._VECTptr;
	gen last=-Bend.back();
	if (is_zero(last))
	  return vecteur(0);
	vecteur R=divvecteur(Bend,last);
	R.pop_back();
	B.pop_back();
	int Bs=int(B.size());
	for (int j=0;j<Bs;j++)
	  B[j]._VECTptr->pop_back();
	// The solution is R+Vect(B[0],..,B[Bs-1])
	// the smallest solution is the orthogonal projection of 0 on R+Vect(B)
	// i.e. R + projection of -R on Vect(B)
	matrice r,Bg=gramschmidt(B,r,false,contextptr);
	gen Rtmp(R);
	for (int j=0;j<Bs;++j){
	  Rtmp -= dotvecteur(Bg[j],R)/dotvecteur(Bg[j],Bg[j])*Bg[j];
	}
	res.push_back(Rtmp);
      }
      res=gen2vecteur(_trn(res,contextptr));
      return res;
    }
    matrice res;
    if (has_num_coeff(v)){
      // <Ax-b|Ax-b> minimal, i.e. A* Ax=A* b or 
      // A=QR, if A has m rows and n cols and m>=n, then Q is m*m and R is m*n
      // first n cols of Q are Q1, first n rows of R are R1
      // solve R1*x=Q1^t*b
      gen qrdec=qr(v[0],contextptr);
      if (qrdec.type==_VECT && qrdec._VECTptr->size()==2){
	gen q=qrdec._VECTptr->front(),r=qrdec._VECTptr->back();
	if (ckmatrix(q) && ckmatrix(r)){ 
	  if (!is_zero(r[int(A.size())-1])){
	    gen qt=_trn(q,contextptr);
	    qt=vecteur(qt._VECTptr->begin(),qt._VECTptr->begin()+as);
	    vecteur R(r._VECTptr->begin(),r._VECTptr->begin()+A.size());
	    for (int i=0;i<bs;++i){
	      gen Bi=B[i];
	      vecteur v;
	      linsolve_u(R,multmatvecteur(*qt._VECTptr,*Bi._VECTptr),v);
	      res.push_back(v);
	    }
	    return mtran(res);
	  }
	  // A* Ax=A* b => R* Rx=R* Qb
	  gen rstar=_trn(r,contextptr);
	  gen rr=rstar*r;
	  gen rq=rstar*q*B;
	  return _linsolve(makesequence(rr,rq),contextptr);
	}
      }
    }
    // orthogonal projection of each vector of B on image of A
    if (A.size()>20)
      *logptr(contextptr) << "LSQ: exact data, running Gramschmidt instead of qr, this is much slower for large matrices" << '\n';
    matrice r,Ag=gramschmidt(A,r,false,contextptr);
    for (int i=0;i<bs;++i){
      gen Bi=B[i];
      vecteur tmp(as);
      for (int j=0;j<as;++j){
	tmp[j] = scalar_product(Ag[j],Bi,contextptr)/scalar_product(Ag[j],Ag[j],contextptr);
      }
      res.push_back(tmp);
    }
    res=gen2vecteur(_trn(res,contextptr));
    return mmult(*inv(r,contextptr)._VECTptr,res);
  }

gen _INT(const gen & g,GIAC_CONTEXT){
  // full implementation copied from rpn.cc:1956 (integer part; used by fPart in ti89 path)
  if ( g.type==_STRNG && g.subtype==-1) return  g;
  if (g.type==_VECT)
    return apply(g,_INT,contextptr);
  if (g.type==_CPLX)
    return _INT(*g._CPLXptr,contextptr)+cst_i*_INT(*(g._CPLXptr+1),contextptr);
  if (is_positive(g,contextptr))
    return _floor(g,contextptr);
  else {
    if (is_positive(-g,contextptr))
      return _ceil(g,contextptr);
    gen sg=sign(g,contextptr);
    return sg*_floor(g*sg,contextptr);
  }
}
gen _SVL(const gen & args0,GIAC_CONTEXT){
  // full implementation copied from rpn.cc:2330 (matrix norm/abs path in misc.cc/gen.cc)
  if ( args0.type==_STRNG && args0.subtype==-1) return  args0;
  if (!ckmatrix(args0))
    return gentypeerr(contextptr);
  gen args=evalf(args0,1,contextptr);
  return _svd(gen(makevecteur(args,-2),_SEQ__VECT),contextptr);
}
gen _VARS(const gen & args,GIAC_CONTEXT){ return giac_stub_rpn_unary(args,contextptr); }
  gen _purge(const gen & args,const context * contextptr) {
    if ( args.type==_STRNG && args.subtype==-1) return  args;
    if (rpn_mode(contextptr) && (args.type==_VECT)){
      if (!args._VECTptr->size())
	return gentoofewargs("purge");
      gen apurger=args._VECTptr->back();
      _purge(apurger,contextptr);
      args._VECTptr->pop_back();
      return gen(*args._VECTptr,_RPN_STACK__VECT);
    }
    if (args.type==_VECT)
      return apply(args,contextptr,_purge);
    if (args.is_symb_of_sommet(at_at)){
      gen & f = args._SYMBptr->feuille;
      if (f.type==_VECT && f._VECTptr->size()==2){
	gen m = eval(f._VECTptr->front(),eval_level(contextptr),contextptr);
	gen indice=eval(f._VECTptr->back(),eval_level(contextptr),contextptr);
	if (m.type==_MAP){
	  gen_map::iterator it=m._MAPptr->find(indice),itend=m._MAPptr->end();
	  if (it==itend)
	    return gensizeerr(gettext("Bad index")+indice.print(contextptr));
	  m._MAPptr->erase(it);
	  return 1;
	}
	if (m.type==_VECT && indice.type==_INT_){
	  vecteur & v = *m._VECTptr;
	  int i=indice.val;
	  if (i>=0 && i<v.size()){
	    v.erase(v.begin()+i);
	    return 1;
	  }
	  return gendimerr(contextptr);
	}
      }
    }
    if (contextptr && args.is_symb_of_sommet(at_rootof)){
      gen a=eval(args,1,contextptr);
      if (!a.is_symb_of_sommet(at_rootof))
	return gensizeerr(gettext("Bad rootof"));
      if (!contextptr->globalcontextptr->rootofs)
	contextptr->globalcontextptr->rootofs=new vecteur;
      gen Pmin=a._SYMBptr->feuille;
      if (Pmin.type!=_VECT || Pmin._VECTptr->size()!=2 || Pmin._VECTptr->front()!=makevecteur(1,0))
	return gensizeerr(gettext("Bad rootof"));
      Pmin=Pmin._VECTptr->back();
      vecteur & r =*contextptr->globalcontextptr->rootofs;
      for (unsigned i=0;i<r.size();++i){
	gen ri=r[i];
	if (ri.type==_VECT && ri._VECTptr->size()==2 && Pmin==ri._VECTptr->front()){
	  gen a=ri._VECTptr->back();
	  r.erase(r.begin()+i);
	  return _purge(a,contextptr);
	}
      }
      return 0;
    }
    if (args.type!=_IDNT)
      return symbolic(at_purge,args);
    // REMOVED! args.eval(eval_level(contextptr),contextptr); 
    if (contextptr){
      if (contextptr->globalcontextptr!=contextptr){ 
	// purge a local variable = set it to assume(DOM_SYMBOLIC)
	gen a2(_SYMB);
	a2.subtype=1;
	return sto(gen(makevecteur(a2),_ASSUME__VECT),args,contextptr);
      }
      return purgenoassume(args,contextptr);
    }
    if (current_folder_name.type==_IDNT && current_folder_name._IDNTptr->value && current_folder_name._IDNTptr->value->type==_VECT){
      vecteur v=*current_folder_name._IDNTptr->value->_VECTptr;
      iterateur it=v.begin(),itend=v.end();
      gen val;
      for (;it!=itend;++it){
	if (it->type!=_VECT || it->_VECTptr->size()!=2)
	  continue;
	vecteur & w=*it->_VECTptr;
	if (w[0]==args){
	  val=w[1];
	  break;
	}
      }
      if (it!=itend){
	v.erase(it);
	gen res=gen(v,_FOLDER__VECT);
	*current_folder_name._IDNTptr->value=res;
#ifdef HAVE_SIGNAL_H_OLD
	if (!child_id && signal_store)
	  _signal(symb_quote(symbolic(at_sto,makesequence(res,current_folder_name))),contextptr);
#endif
	return val;
      }
    }
    if (args._IDNTptr->value && args._IDNTptr->ref_count_ptr!=(int *)-1){
      // *logptr(contextptr) << "Purging " << args <<  " refs " << *(args._IDNTptr->ref_count_ptr) << "\n";
#if !defined RTOS_THREADX && !defined BESTA_OS && !defined FREERTOS && !defined FXCG
      if (variables_are_files(contextptr))
	unlink((args._IDNTptr->name()+string(cas_suffixe)).c_str());
#endif
      gen res=*args._IDNTptr->value;
      if (res.type==_VECT && res.subtype==_FOLDER__VECT){
	if (res._VECTptr->size()!=1)
	  return gensizeerr(gettext("Non-empty folder"));
      }
      delete args._IDNTptr->value;
      args._IDNTptr->value=0;
#ifdef HAVE_SIGNAL_H_OLD
      if (!child_id && signal_store)
	_signal(symb_quote(symb_purge(args)),contextptr);
#endif
      return res;
    }
    else
      return string2gen("No such variable "+args.print(contextptr),false);
    //return string2gen(args.print(contextptr)+" not assigned",false);
  }
gen purgenoassume(const gen & args,const context * contextptr){
  // full implementation copied from rpn.cc:875 (called by _purge)
  if (args.type==_VECT){
    vecteur & v=*args._VECTptr;
    vecteur res;
    for (unsigned i=0;i<v.size();++i)
      res.push_back(purgenoassume(v[i],contextptr));
    return res;
  }
  if (args.type!=_IDNT)
    return gensizeerr("Invalid purgenoassume "+args.print(contextptr));
  if (!contextptr)
    return _purge(args,0);
  const char * ch=args._IDNTptr->id_name;
  if (strlen(ch)==1){
    if (ch[0]=='O' && (series_flags(contextptr) & (1<<6)) )
      series_flags(contextptr) ^= (1<<6);
    if (ch[0]==series_variable_name(contextptr)){
      if (series_flags(contextptr) & (1<<5))
	series_flags(contextptr) ^= (1<<5);
      if (series_flags(contextptr) & (1<<6))
	series_flags(contextptr) ^= (1<<6);
    }
  }
  // purge a global variable
  sym_tab::iterator it=contextptr->tabptr->find(ch),itend=contextptr->tabptr->end();
  if (it==itend){
#if 1 //def GIAC_HAS_STO_38
    if (contextptr && contextptr->previous!=contextptr)
      return purgenoassume(args,contextptr->previous);
#endif
    return string2gen("No such variable "+args.print(contextptr),false);
  }
  gen res=it->second;
  if (it->second.type==_POINTER_ && it->second.subtype==_THREAD_POINTER)
    return gentypeerr(args.print(contextptr)+" is locked by thread "+it->second.print(contextptr));
  if (it->second.type==_POINTER_ && it->second.subtype==_BUFFER_POINTER)
    free(it->second._POINTER_val);
  if (contextptr->previous)
    it->second=identificateur(it->first);
  else
    contextptr->tabptr->erase(it);
  if (res.is_symb_of_sommet(at_rootof))
    _purge(res,contextptr);
  return res;
}
gen symb_rpn_prog(const gen & args){ return giac_stub_rpn_unary(args,0); }
vecteur rpn_eval(const vecteur & prog,vecteur & pile,GIAC_CONTEXT){ (void)prog;(void)pile; return vecteur(); }
char * hp38_display_in_maj(const char * s){ return const_cast<char*>(s? s : ""); }
std::string printasRANDOM(const gen & feuille,const char * s,GIAC_CONTEXT){ (void)feuille;(void)s; return std::string(); }
std::string printasconstant(const gen & feuille,const char * sommetstr,GIAC_CONTEXT){ (void)feuille;(void)sommetstr; return std::string(); }
#endif // GIAC_NO_RPN

#if defined GIAC_NO_TI89
// ===================== TI-89 emulation (ti89.cc) =====================
static gen giac_stub_ti89_unary(const gen &,GIAC_CONTEXT){
  return giac_module_disabled("TI-89 emulation module is disabled in this build");
}
static define_unary_function_eval (__STUB_TI89,giac_stub_ti89_unary,"stub");
#define STUB_TI89_PTR (&__STUB_TI89)
define_unary_function_ptr5(at_entry, alias_at_entry, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_et, alias_at_et, STUB_TI89_PTR, 0, 0);
// at_approx is the "approx" command (an alias of evalf, defined in ti89.cc); core code uses it.
static gen giac_stub_approx(const gen & g,GIAC_CONTEXT){ return _evalf(g,contextptr); }
static define_unary_function_eval (__STUB_APPROX,giac_stub_approx,"approx");
define_unary_function_ptr5(at_approx, alias_at_approx, &__STUB_APPROX, 0, true);
static gen giac_stub_exact(const gen & g,GIAC_CONTEXT){ return exact(g,contextptr); }
static define_unary_function_eval (__STUB_EXACT,giac_stub_exact,"exact");
define_unary_function_ptr5(at_exact, alias_at_exact, &__STUB_EXACT, 0, true);
static gen giac_stub_frac(const gen & g,GIAC_CONTEXT){ return fPart(g,contextptr); }
static define_unary_function_eval (__STUB_FRAC,giac_stub_frac,"frac");
define_unary_function_ptr5(at_frac, alias_at_frac, &__STUB_FRAC, 0, true);
// at_identity is the "identity" command (alias of _idn in ti89.cc); matrix algebra depends on it.
static gen giac_stub_identity(const gen & g,GIAC_CONTEXT){ return _idn(g,contextptr); }
static define_unary_function_eval (__STUB_IDENTITY,giac_stub_identity,"identity");
define_unary_function_ptr5(at_identity, alias_at_identity, &__STUB_IDENTITY, 0, true);
define_unary_function_ptr5(at_getKey, alias_at_getKey, STUB_TI89_PTR, 0, 0);
// at_int implements the "int" command which forwards to _integrate in ti89.cc.
// Keep it functional when the TI-89 module is disabled: "int" is a core user command.
static gen giac_stub_int(const gen & g,GIAC_CONTEXT){
  // full implementation copied from ti89.cc _int
  if ( g.type==_STRNG && g.subtype==-1) return  g;
  if (g.type==_VECT && g.subtype==_SEQ__VECT && g._VECTptr->size()==2 && g._VECTptr->front().type==_STRNG && g._VECTptr->back().type==_INT_){
    gen b=g._VECTptr->back();
    if (b.val<2 || b.val>36)
      return gendimerr(contextptr);
    gen res=0;
    const std::string & s=*g._VECTptr->front()._STRNGptr;
    int ss=int(s.size());
    for (int i=0;i<ss;++i){
      char ch=s[i];
      if (ch>='0' && ch<='9'){
	res = res*b+int(ch-'0');
	continue;
      }
      if (ch>='A' && ch<='Z'){
	res = res*b+int(ch-'A')+10;
	continue;
      }
      if (ch>='a' && ch<='z'){
	res = res*b+int(ch-'a')+10;
	continue;
      }
    }
    return res;
  }
  if (xcas_mode(contextptr)==3 || (python_compat(contextptr) && g.type!=_VECT)){
    gen g_=eval(g,1,contextptr);
    if (g_.type==_STRNG)
      g_=gen(*g_._STRNGptr,contextptr);
    if (is_integer(g_))
      return g_;
    return _floor(evalf(g_,1,contextptr),contextptr);
  }
  else
    return _integrate(g,contextptr);
}
static define_unary_function_eval (__STUB_INT,giac_stub_int,"int");
define_unary_function_ptr5(at_int, alias_at_int, &__STUB_INT, _QUOTE_ARGUMENTS, true);
define_unary_function_ptr5(at_left, alias_at_left, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_logb, alias_at_logb, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_oufr, alias_at_oufr, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_pour, alias_at_pour, STUB_TI89_PTR, 0, 0);
  gen _product(const gen & g,GIAC_CONTEXT){
    if ( g.type==_STRNG && g.subtype==-1) return  g;
    if (g.type==_VECT){
      if (g.subtype!=_SEQ__VECT)
	return prodsum(g.eval(eval_level(contextptr),contextptr),true);
      vecteur v=*g._VECTptr;
      maple_sum_product_unquote(v,contextptr);
      int s=int(v.size());
      if (s==2 && v[1]==at_prod){
	gen tmp=eval(v[0],1,contextptr);
	if (tmp.type==_VECT){
	  gen res(1);
	  const_iterateur it=tmp._VECTptr->begin(),itend=tmp._VECTptr->end();
	  for (;it!=itend;++it)
	    res = res * *it;
	  return res;
	}
      }
      if (!adjust_int_sum_arg(v,s))
	return gensizeerr(contextptr);
      if (v.size()==4 && (v[2].type!=_INT_ || v[3].type!=_INT_)){
	if (v[1].type!=_IDNT){
	  if (v[1].type!=_SYMB || lidnt(v[1]).empty())
	    return prodsum(g.eval(eval_level(contextptr),contextptr),true);
	  identificateur tmp("x");
	  v[0]=quotesubst(v[0],v[1],tmp,contextptr);
	  v[1]=tmp;
	  gen res=_product(gen(v,g.subtype),contextptr);
	  return quotesubst(res,tmp,v[1],contextptr);
	}
	v=quote_eval(v,makevecteur(v[1]),contextptr);
	gen n=v[1];
	vecteur lv(1,n);
	lvar(v[0],lv);
	if (is_zero(derive(vecteur(lv.begin()+1,lv.end()),n,contextptr),contextptr)){
	  v[0]=e2r(v[0],lv,contextptr);
	  gen p1,p2;
	  fxnd(v[0],p1,p2);
	  return simplify(product(gen2polynome(p1,int(lv.size())),lv,n,v[2],v[3],contextptr)/product(gen2polynome(p2,int(lv.size())),lv,n,v[2],v[3],contextptr),contextptr);
	}
      }
      if (v.size()==4 && v[2].type==_INT_ && v[3].type==_INT_ && v[2].val>v[3].val){
	if (v[3].val==v[2].val-1)
	  return 1;
#if defined RTOS_THREADX || defined BESTA_OS || defined USTL
	{ gen a=v[2]; v[2]=v[3]; v[3]=a; }
#else
	swap(v[2],v[3]);
#endif
	v[2]=v[2]+1;
	v[3]=v[3]-1;
	return inv(seqprod(gen(v,_SEQ__VECT),1,contextptr),contextptr);
      }
      return seqprod(gen(v,_SEQ__VECT),1,contextptr);
    }
    gen tmp=g.eval(eval_level(contextptr),contextptr);
    if (tmp.type==_VECT)
      return _product(tmp,contextptr);
    return seqprod(g,1,contextptr);
  }
static const char _STUB_product_s []="product";
static define_unary_function_eval_quoted (__STUB_PRODUCT,&_product,_STUB_product_s);
define_unary_function_ptr5(at_product, alias_at_product, &__STUB_PRODUCT, _QUOTE_ARGUMENTS, true);
// at_real: the "real" command (ti89.cc) must stay registered so that
// assume(x,real) / type checks in core code (usual.cc:5024, prog.cc:1172)
// recognize the type marker; eval still reports the module as disabled.
// NB: lexer registration uses the eval object's name, so a dedicated
// "real"-named eval object is required (sharing STUB_TI89_PTR would
// register the name "stub" instead).
static gen giac_stub_real(const gen & g,GIAC_CONTEXT){ return giac_stub_ti89_unary(g,contextptr); }
static define_unary_function_eval (__STUB_REAL,giac_stub_real,"real");
define_unary_function_ptr5(at_real, alias_at_real, &__STUB_REAL, 0, true);
define_unary_function_ptr5(at_right, alias_at_right, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_rotate, alias_at_rotate, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_seq, alias_at_seq, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_shift, alias_at_shift, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_si, alias_at_si, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_sialorssinon, alias_at_sialorssinon, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_tantque, alias_at_tantque, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_ClrIO, alias_at_ClrIO, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_DispG, alias_at_DispG, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_Input, alias_at_Input, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_PopUp, alias_at_PopUp, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_PtOff, alias_at_PtOff, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_PxlOn, alias_at_PxlOn, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_SortA, alias_at_SortA, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_SortD, alias_at_SortD, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_Store, alias_at_Store, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_alors, alias_at_alors, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_avgRC, alias_at_avgRC, STUB_TI89_PTR, 0, 0);
static gen giac_stub_denom(const gen & g,GIAC_CONTEXT){
  // full implementation copied from ti89.cc:433 (denom = tail of _fxnd)
  gen res=_fxnd(g,contextptr);
  if (res.type!=_VECT) return res;
  return res._VECTptr->back();
}
static gen giac_stub_atdenom(const gen & g,GIAC_CONTEXT){ return apply(g,giac_stub_denom,contextptr); }
static define_unary_function_eval (__STUB_DENOM,giac_stub_atdenom,"denom");
gen _denom(const gen & g,GIAC_CONTEXT){
  // full implementation copied from ti89.cc:438; needed by misc/desolve/optimization
  // and the signalprocessing helpers regardless of which module is pruned
  return apply(g,giac_stub_denom,contextptr);
}
define_unary_function_ptr5(at_denom, alias_at_denom, &__STUB_DENOM, 0, true);
define_unary_function_ptr5(at_droit, alias_at_droit, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_eigVc, alias_at_eigVc, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_eigVl, alias_at_eigVl, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_fPart, alias_at_fPart, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_faire, alias_at_faire, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_iPart, alias_at_iPart, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_sinon, alias_at_sinon, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_sorta, alias_at_sorta, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_sortd, alias_at_sortd, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_unitV, alias_at_unitV, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_zeros, alias_at_zeros, STUB_TI89_PTR, 0, 0);
gen _SortD(const gen & args,GIAC_CONTEXT){ return giac_stub_ti89_unary(args,contextptr); }
gen _cSolve(const gen & args,GIAC_CONTEXT){ return giac_stub_ti89_unary(args,contextptr); }
gen _cZeros(const gen & args,GIAC_CONTEXT){ return giac_stub_ti89_unary(args,contextptr); }
gen _cpartfrac(const gen & args,GIAC_CONTEXT){ return giac_stub_ti89_unary(args,contextptr); }
gen _deltalist(const gen & args,GIAC_CONTEXT){ return giac_stub_ti89_unary(args,contextptr); }
gen _dim(const gen & args,GIAC_CONTEXT){ return giac_stub_ti89_unary(args,contextptr); }
gen _fMax(const gen & args,GIAC_CONTEXT){ return giac_stub_ti89_unary(args,contextptr); }
gen _fMin(const gen & args,GIAC_CONTEXT){ return giac_stub_ti89_unary(args,contextptr); }
gen _getKey(const gen & args,GIAC_CONTEXT){ return giac_stub_ti89_unary(args,contextptr); }
gen _getNum(const gen & args,GIAC_CONTEXT){ return giac_stub_ti89_unary(args,contextptr); }
gen _int(const gen & args,GIAC_CONTEXT){ return giac_stub_ti89_unary(args,contextptr); }
gen _mRow(const gen & args,GIAC_CONTEXT){ return giac_stub_ti89_unary(args,contextptr); }
gen _mid(const gen & args,GIAC_CONTEXT){ return giac_stub_ti89_unary(args,contextptr); }
gen _subMat(const gen & args,GIAC_CONTEXT){ return giac_stub_ti89_unary(args,contextptr); }
gen _zeros(const gen & args,GIAC_CONTEXT){ return giac_stub_ti89_unary(args,contextptr); }
gen _colNorm(const gen & args,GIAC_CONTEXT){ return giac_stub_ti89_unary(args,contextptr); }
gen _deSolve(const gen & args,GIAC_CONTEXT){ return giac_stub_ti89_unary(args,contextptr); }
gen _getDenom(const gen & args,GIAC_CONTEXT){ return giac_stub_ti89_unary(args,contextptr); }
gen _mRowAdd(const gen & args,GIAC_CONTEXT){ return giac_stub_ti89_unary(args,contextptr); }
gen _rowSwap(const gen & args,GIAC_CONTEXT){ return giac_stub_ti89_unary(args,contextptr); }
gen _taylor(const gen & args,GIAC_CONTEXT){ return giac_stub_ti89_unary(args,contextptr); }


define_unary_function_ptr5(at_Archive, alias_at_Archive, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_Circle, alias_at_Circle, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_ClrDraw, alias_at_ClrDraw, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_ClrGraph, alias_at_ClrGraph, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_CopyVar, alias_at_CopyVar, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_CyclePic, alias_at_CyclePic, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_DelFold, alias_at_DelFold, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_DispHome, alias_at_DispHome, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_DrawSlp, alias_at_DrawSlp, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_Exec, alias_at_Exec, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_Fill, alias_at_Fill, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_Get, alias_at_Get, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_GetCalc, alias_at_GetCalc, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_GetFold, alias_at_GetFold, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_InputStr, alias_at_InputStr, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_LU, alias_at_LU, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_Line, alias_at_Line, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_LineHorz, alias_at_LineHorz, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_LineTan, alias_at_LineTan, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_LineVert, alias_at_LineVert, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_NewFold, alias_at_NewFold, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_NewPic, alias_at_NewPic, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_Output, alias_at_Output, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_Prompt, alias_at_Prompt, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_PtOn, alias_at_PtOn, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_PtText, alias_at_PtText, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_PxlOff, alias_at_PxlOff, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_QR, alias_at_QR, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_RandSeed, alias_at_RandSeed, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_RclPic, alias_at_RclPic, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_RplcPic, alias_at_RplcPic, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_StoPic, alias_at_StoPic, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_Unarchiv, alias_at_Unarchiv, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_ZoomRcl, alias_at_ZoomRcl, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_ZoomSto, alias_at_ZoomSto, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_arcLen, alias_at_arcLen, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_arclen, alias_at_arclen, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_augment, alias_at_augment, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_cFactor, alias_at_cFactor, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_cSolve, alias_at_cSolve, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_cZeros, alias_at_cZeros, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_ceiling, alias_at_ceiling, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_cfactor, alias_at_cfactor, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_colDim, alias_at_colDim, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_colNorm, alias_at_colNorm, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_colnorm, alias_at_colnorm, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_comDenom, alias_at_comDenom, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_cpartfrac, alias_at_cpartfrac, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_crossP, alias_at_crossP, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_csolve, alias_at_csolve, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_cumSum, alias_at_cumSum, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_cumsum, alias_at_cumsum, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_curvature, alias_at_curvature, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_czeros, alias_at_czeros, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_de, alias_at_de, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_deSolve, alias_at_deSolve, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_deltalist, alias_at_deltalist, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_dim, alias_at_dim, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_dotP, alias_at_dotP, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_droite_tangente, alias_at_droite_tangente, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_evolute, alias_at_evolute, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_exp2list, alias_at_exp2list, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_fMax, alias_at_fMax, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_fMin, alias_at_fMin, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_factoriser_sur_C, alias_at_factoriser_sur_C, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_fonction, alias_at_fonction, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_format, alias_at_format, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_frenet, alias_at_frenet, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_gauche, alias_at_gauche, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_getDenom, alias_at_getDenom, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_getNum, alias_at_getNum, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_getType, alias_at_getType, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_imag, alias_at_imag, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_inString, alias_at_inString, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_intDiv, alias_at_intDiv, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_isPrime, alias_at_isPrime, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_isprime, alias_at_isprime, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_jusque, alias_at_jusque, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_keydown, alias_at_keydown, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_lis, alias_at_lis, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_lis_phrase, alias_at_lis_phrase, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_list2exp, alias_at_list2exp, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_list2mat, alias_at_list2mat, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_mRow, alias_at_mRow, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_mRowAdd, alias_at_mRowAdd, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_mat2list, alias_at_mat2list, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_mid, alias_at_mid, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_mul, alias_at_mul, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_nCr, alias_at_nCr, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_nDeriv, alias_at_nDeriv, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_nInt, alias_at_nInt, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_nPr, alias_at_nPr, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_nSolve, alias_at_nSolve, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_newList, alias_at_newList, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_newMat, alias_at_newMat, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_non, alias_at_non, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_ord, alias_at_ord, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_osculating_circle, alias_at_osculating_circle, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_pas, alias_at_pas, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_polyEval, alias_at_polyEval, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_propFrac, alias_at_propFrac, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_randMat, alias_at_randMat, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_randPoly, alias_at_randPoly, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_randpoly, alias_at_randpoly, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_ref, alias_at_ref, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_remain, alias_at_remain, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_resoudre_dans_C, alias_at_resoudre_dans_C, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_rowAdd, alias_at_rowAdd, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_rowDim, alias_at_rowDim, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_rowNorm, alias_at_rowNorm, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_rowSwap, alias_at_rowSwap, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_rownorm, alias_at_rownorm, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_rowswap, alias_at_rowswap, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_scalarProduct, alias_at_scalarProduct, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_semi_augment, alias_at_semi_augment, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_simult, alias_at_simult, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_subMat, alias_at_subMat, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_submatrix, alias_at_submatrix, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_swaprow, alias_at_swaprow, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_tCollect, alias_at_tCollect, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_tExpand, alias_at_tExpand, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_tangente, alias_at_tangente, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_taylor, alias_at_taylor, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_transpose, alias_at_transpose, STUB_TI89_PTR, 0, 0);
define_unary_function_ptr5(at_unarchive_ti, alias_at_unarchive_ti, STUB_TI89_PTR, 0, 0);


gen _seq(const gen & g,GIAC_CONTEXT){ return giac_stub_ti89_unary(g,contextptr); }
gen _logb(const gen & g,GIAC_CONTEXT){ return giac_stub_ti89_unary(g,contextptr); }
gen _isprime(const gen & args,GIAC_CONTEXT){ return giac_stub_ti89_unary(args,contextptr); }

static gen giac_stub_numer(const gen & g,GIAC_CONTEXT){
  // full implementation copied from ti89.cc:460
  gen res=_fxnd(g,contextptr);
  if (res.type!=_VECT) return res;
  return res._VECTptr->front();
}
gen _numer(const gen & g,GIAC_CONTEXT){
  return apply(g,giac_stub_numer,contextptr);
}
static gen giac_stub_atnumer(const gen & g,GIAC_CONTEXT){ return _numer(g,contextptr); }
static define_unary_function_eval (__STUB_NUMER,giac_stub_atnumer,"numer");
define_unary_function_ptr5(at_numer, alias_at_numer, &__STUB_NUMER, 0, true);
gen _left(const gen & g,GIAC_CONTEXT){ return giac_stub_ti89_unary(g,contextptr); }
gen _right(const gen & g,GIAC_CONTEXT){ return giac_stub_ti89_unary(g,contextptr); }
gen _rotate(const gen & g,GIAC_CONTEXT){ return giac_stub_ti89_unary(g,contextptr); }
gen _shift(const gen & g,GIAC_CONTEXT){ return giac_stub_ti89_unary(g,contextptr); }
gen _list2exp(const gen & g,GIAC_CONTEXT){ return giac_stub_ti89_unary(g,contextptr); }
gen _sorta(const gen & g,GIAC_CONTEXT){
  // real behavior copied from ti89.cc: non-VECT input is a size error
  if ( g.type==_STRNG && g.subtype==-1) return  g;
  if (g.type==_VECT)
    return sortad(*g._VECTptr,true,contextptr);
  return gensizeerr(contextptr);
}
gen _rowNorm(const gen & g,GIAC_CONTEXT){ return giac_stub_ti89_unary(g,contextptr); }
gen _unarchive_ti(const gen & args,GIAC_CONTEXT){ return giac_stub_ti89_unary(args,contextptr); }
gen exact(const gen & g,GIAC_CONTEXT){
  // full implementation copied from ti89.cc:2771; required by _partfrac/_limit/_resultant etc.
  switch (g.type){
  case _DOUBLE_:
    return exact_double(g._DOUBLE_val,epsilon(contextptr));
  case _REAL:
#ifdef HAVE_LIBMPFR
    // D1.3: high-precision reals expand the mantissa exactly (real2int);
    // evalf_double would collapse to ~16 digits before the continued
    // fraction rebuild (12-digit result for evalf(pi,1000)).
    if (mpfr_get_prec(g._REALptr->inf) > 53){
      ref_mpz_t * m=new ref_mpz_t;
      long nn=mpfr_get_z_exp(m->z,g._REALptr->inf);
      gen res(m->z);
      if (nn>=0)
	return res*pow(plus_two,gen(nn),contextptr);
      return res/pow(plus_two,gen(-nn),contextptr);
    }
#endif
    return exact_double(evalf_double(g,1,contextptr)._DOUBLE_val,epsilon(contextptr));
#ifdef BCD
  case _FLOAT_:
    return exact_double(evalf_double(g,1,contextptr)._DOUBLE_val,1e-10);
#endif
  case _CPLX:
    return exact(re(g,contextptr),contextptr)+cst_i*exact(im(g,contextptr),contextptr);
  case _SYMB:
    return symbolic(g._SYMBptr->sommet,exact(g._SYMBptr->feuille,contextptr));
  case _VECT:
    return apply(g,exact,contextptr);
  default:
    return g;
  }
}
gen _exact(const gen & g,GIAC_CONTEXT){ return exact(g,contextptr); }
gen fPart(const gen & g,GIAC_CONTEXT){
  // full implementation copied from ti89.cc:2788
  if (is_undef(g))
    return g;
  if (is_equal(g))
    return apply_to_equal(g,fPart,contextptr);
  if (g.type==_VECT)
    return apply(g,fPart,contextptr);
  return g-_INT(g,contextptr);
}
gen exact_double(double d,double eps){
  // full implementation copied from ti89.cc:2729 (continued fraction to exact rational)
  if (eps<1e-14)
    eps=1e-14;
  if (d<0)
    return -exact_double(-d,eps);
  if (d > (1<<30) )
    return _floor(d,context0);
  if (d==0)
    return 0;
  if (d<1)
    return inv(exact_double(1/d,eps),context0);
  vector<int> res;
  double eps1(1+eps);
  for (;!interrupted;){
#ifdef TIMEOUT
    control_c();
#endif
    if (ctrl_c || interrupted) { 
      interrupted = true; ctrl_c=false;
      return gensizeerr(gettext("Stopped by user interruption.")); 
    }
    res.push_back(int(d*eps1));
    d=d-int(d*eps1);
    if (d<=eps)
      break;
    d=1/d;
    if (d > (1<<30))
      break;
    eps=eps*d*d;
  }
  if (res.empty())
    return gensizeerr(gettext("Stopped by user interruption.")); 
  reverse(res.begin(),res.end());
  vector<int>::const_iterator it=res.begin(),itend=res.end();
  if (it==itend)
    return undef;
  gen x(*it);
  for (++it;it!=itend;++it){
    x=*it+inv(x,context0);
  }
  return x;
}
gen sortad(const vecteur & v,bool ascend,GIAC_CONTEXT){
  // real implementation (defined in ti89.cc); required by _proot and misc.cc
  if (v.empty()) return v;
  vecteur valeur=*eval(v,eval_level(contextptr),contextptr)._VECTptr;
  bool ismat=ckmatrix(valeur);
  if (!ismat)
    valeur=vecteur(1,valeur);
  valeur=mtran(valeur);
  gen_sort_f_context(valeur.begin(),valeur.end(),complex_sort,contextptr);
  if (!ascend)
    reverse(valeur.begin(),valeur.end());
  if (!ismat)
    return gen(mtran(valeur).front());
  return gen(mtran(valeur));
}
bool complex_sort(const gen & a,const gen & b,GIAC_CONTEXT){
  // real implementation copied from ti89.cc:1635 (used by sortad/_proot/_complexroot/sort_eigenvals)
  if (a.type==_VECT && !a._VECTptr->empty() && b.type==_VECT && !b._VECTptr->empty())
    return complex_sort(a._VECTptr->front(),b._VECTptr->front(),contextptr);
  if (a==b)
    return false;
  if (a.type==_CPLX && b.type==_CPLX){
    if (*a._CPLXptr!=*b._CPLXptr)
      return is_strictly_greater(*b._CPLXptr,*a._CPLXptr,contextptr);
    return is_strictly_greater(*(b._CPLXptr+1),*(a._CPLXptr+1),contextptr);
  }
  if (a.type==_CPLX){
    if (*a._CPLXptr!=b)
      return is_strictly_greater(b,*a._CPLXptr,contextptr);
    return is_strictly_greater(0,*(a._CPLXptr+1),contextptr);
  }
  if (b.type==_CPLX){
    if (a!=*b._CPLXptr)
      return is_strictly_greater(*b._CPLXptr,a,contextptr);
    return is_strictly_greater(*(b._CPLXptr+1),0,contextptr);
  }
  gen g=inferieur_strict(a,b,contextptr); 
  if (g.type!=_INT_)
    return a.islesscomplexthan(b);
  return g.val==1;
}
unary_function_eval __getKey(0,&giac_stub_ti89_unary,"getKey");
#endif // GIAC_NO_TI89

#if defined GIAC_NO_PLOT3D
// ===================== 3D plotting (plot3d.cc) =====================
static gen giac_stub_plot3d_unary(const gen &,GIAC_CONTEXT){
  return giac_module_disabled("3D plotting module is disabled in this build");
}
static define_unary_function_eval (__STUB_PLOT3D,giac_stub_plot3d_unary,"stub");
#define STUB_PLOT3D_PTR (&__STUB_PLOT3D)
define_unary_function_ptr5(at_cylindre, alias_at_cylindre, STUB_PLOT3D_PTR, 0, 0);
define_unary_function_ptr5(at_plan, alias_at_plan, STUB_PLOT3D_PTR, 0, 0);
define_unary_function_ptr5(at_sphere, alias_at_sphere, STUB_PLOT3D_PTR, 0, 0);
define_unary_function_ptr5(at_octaedre, alias_at_octaedre, STUB_PLOT3D_PTR, 0, 0);
define_unary_function_ptr5(at_convert3d, alias_at_convert3d, STUB_PLOT3D_PTR, 0, 0);
define_unary_function_ptr5(at_icosaedre, alias_at_icosaedre, STUB_PLOT3D_PTR, 0, 0);
define_unary_function_ptr5(at_tetraedre, alias_at_tetraedre, STUB_PLOT3D_PTR, 0, 0);
define_unary_function_ptr5(at_dodecaedre, alias_at_dodecaedre, STUB_PLOT3D_PTR, 0, 0);
define_unary_function_ptr5(at_est_cospherique, alias_at_est_cospherique, STUB_PLOT3D_PTR, 0, 0);
define_unary_function_ptr5(at_cone, alias_at_cone, STUB_PLOT3D_PTR, 0, 0);
define_unary_function_ptr5(at_cube, alias_at_cube, STUB_PLOT3D_PTR, 0, 0);
define_unary_function_ptr5(at_volume, alias_at_volume, STUB_PLOT3D_PTR, 0, 0);

gen _plan(const gen & args,GIAC_CONTEXT){ return giac_stub_plot3d_unary(args,contextptr); }
gen _sphere(const gen & args,GIAC_CONTEXT){ return giac_stub_plot3d_unary(args,contextptr); }
gen do_point3d(const gen & g){ return giac_stub_plot3d_unary(g,0); }
bool is3d(const gen & g){ (void)g; return false; }
gen hyperplan2hypersurface(const gen & g){ return giac_stub_plot3d_unary(g,0); }
vecteur hyperplan_normal(const gen & g){ (void)g; return vecteur(); }
bool hyperplan_normal_point(const gen & g,vecteur & n,vecteur & P){ (void)g; n.clear(); P.clear(); return false; }
gen hypersphere2hypersurface(const gen & g){ return giac_stub_plot3d_unary(g,0); }
gen hypersphere_equation(const gen & g,const vecteur & xyz){ (void)xyz; return giac_stub_plot3d_unary(g,0); }
gen hypersurface_equation(const gen & g,const vecteur & xyz,GIAC_CONTEXT){ (void)xyz; return giac_stub_plot3d_unary(g,contextptr); }
vecteur inter2hypersurface(const gen & a,const gen & b,GIAC_CONTEXT){ (void)a;(void)b; return vecteur(); }
vecteur interdroitehyperplan(const gen & a,const gen & b,GIAC_CONTEXT){ (void)a;(void)b; return vecteur(); }
vecteur interhyperplan(const gen & p1,const gen & p2,GIAC_CONTEXT){ (void)p1;(void)p2; return vecteur(); }
vecteur interhypersurfacecurve(const gen & a,const gen & b,GIAC_CONTEXT){ (void)a;(void)b; return vecteur(); }
vecteur interplansphere(const gen & a,const gen & b,GIAC_CONTEXT){ (void)a;(void)b; return vecteur(); }
vecteur interpolyedre(const vecteur & p,const gen & bb,GIAC_CONTEXT){ (void)p;(void)bb; return vecteur(); }
vecteur rand_3d(){ return vecteur(); }
bool normal3d(const gen & n,vecteur & v1,vecteur & v2){ (void)n; v1.clear(); v2.clear(); return false; }
bool perpendiculaire_commune(const gen & d1,const gen & d2,gen & M,gen & N,vecteur & n,GIAC_CONTEXT){ (void)d1;(void)d2; M=N=0; n.clear(); return false; }
gen similitude3d(const vecteur & centrev,const gen & angle,const gen & rapport,const gen & b,int symrot,GIAC_CONTEXT){ (void)centrev;(void)angle;(void)rapport;(void)b;(void)symrot; return giac_stub_plot3d_unary(gen(0),contextptr); }
gen plotparam3d(const gen & f,const vecteur & vars,double function_xmin,double function_xmax, double function_ymin, double function_ymax,double function_zmin,double function_zmax,double function_umin,double function_umax,double function_vmin,double function_vmax,bool clrplot,bool f_autoscale,const vecteur & attributs,double ustep,double vstep,const gen & eq,const vecteur & eqvars,GIAC_CONTEXT){
  (void)f;(void)vars;(void)function_xmin;(void)function_xmax;(void)function_ymin;(void)function_ymax;(void)function_zmin;(void)function_zmax;(void)function_umin;(void)function_umax;(void)function_vmin;(void)function_vmax;(void)clrplot;(void)f_autoscale;(void)attributs;(void)ustep;(void)vstep;(void)eq;(void)eqvars;
  return giac_stub_plot3d_unary(gen(0),contextptr);
}
gen plotimplicit(const gen & f,const gen & x,const gen & y,const gen & z,double xmin,double xmax,double ymin,double ymax,double zmin,double zmax,int nx,int ny,int nz,double pas,const vecteur & attributs,bool clrplot,bool f_autoscale,GIAC_CONTEXT){
  (void)f;(void)x;(void)y;(void)z;(void)xmin;(void)xmax;(void)ymin;(void)ymax;(void)zmin;(void)zmax;(void)nx;(void)ny;(void)nz;(void)pas;(void)attributs;(void)clrplot;(void)f_autoscale;
  return giac_stub_plot3d_unary(gen(0),contextptr);
}
#endif // GIAC_NO_PLOT3D

#if defined GIAC_NO_QUATER
// ===================== Quaternions & Galois fields (quater.cc) =====================
static gen giac_stub_quater_unary(const gen &,GIAC_CONTEXT){
  return giac_module_disabled("Quaternion/Galois field module is disabled in this build");
}
static define_unary_function_eval (__STUB_QUATER,giac_stub_quater_unary,"stub");
#define STUB_QUATER_PTR (&__STUB_QUATER)
define_unary_function_ptr5(at_quaternion, alias_at_quaternion, STUB_QUATER_PTR, 0, 0);
gen _galois_field(const gen & args,GIAC_CONTEXT){ return giac_stub_quater_unary(args,contextptr); }
gen char2_uncoerce(const gen & a){ return giac_stub_quater_unary(a,0); }
int dotgf_char2(const std::vector<int> & v,const std::vector<int> & w,int M){ (void)v;(void)w;(void)M; return 0; }
int is_irreducible(const vecteur & v,const gen & g){ (void)v;(void)g; return 0; }
int is_irreducible_primitive(const vecteur & v,const gen & p,vecteur & vmin,int primitive,GIAC_CONTEXT){ (void)v;(void)p;(void)primitive; vmin.clear(); return 0; }
int gfsize(const gen & P){ (void)P; return 0; }
bool has_gf_coeff(const gen & e){ (void)e; return false; }
bool has_gf_coeff(const vecteur & v){ (void)v; return false; }
bool has_gf_coeff(const gen & e,gen & p,gen & pmin){ (void)e; p=pmin=0; return false; }
bool has_gf_coeff(const vecteur & v,gen & p,gen & pmin){ (void)v; p=pmin=0; return false; }
static gfmap stub_gfmap;
gfmap & gf_list(){ return stub_gfmap; }
int gf_char2_vecteur2vectorint(const vecteur & v,std::vector<int> & V,gen & x){ (void)v; V.clear(); x=0; return 0; }
int gf_char2_matrice2vectorvectorint(const matrice & m,std::vector< std::vector<int> > & M,gen & x){ (void)m; M.clear(); x=0; return 0; }
void gf_char2_vectorint2vecteur(const std::vector<int> & source,vecteur & target,int M,const gen & x){ (void)source;(void)M;(void)x; target.clear(); }
void gf_char2_vectorvectorint2mat(const std::vector< std::vector<int> > & source,matrice & target,int M,const gen & x){ (void)source;(void)M;(void)x; target.clear(); }
bool gf_char2_mmult_atranb(const std::vector< std::vector<int> > & A,const std::vector< std::vector<int> > & tranB,std::vector< std::vector<int> > & C,int M){ (void)A;(void)tranB;(void)M; C.clear(); return false; }
bool gf_char2_rref(std::vector< std::vector<int> > & N,const gen & x,int M,vecteur & pivots,std::vector<int> & permutation,std::vector<int> & maxrankcols,gen & det,int l, int lmax, int c,int cmax,int fullreduction,int dont_swap_below,int rref_or_det_or_lu){
  (void)N;(void)x;(void)M;pivots.clear();permutation.clear();maxrankcols.clear();det=0;(void)l;(void)lmax;(void)c;(void)cmax;(void)fullreduction;(void)dont_swap_below;(void)rref_or_det_or_lu; return false;
}
bool gf_char2_multpoly(const std::vector<int> & a,const std::vector<int> & b,std::vector<int> & res,int M){ (void)a;(void)b;(void)M; res.clear(); return false; }
bool gf_multpoly(const std::vector< std::vector<int> > & a,const std::vector< std::vector<int> > & b,std::vector< std::vector<int> > & res,const std::vector<int> & pmin,int modulo){ (void)a;(void)b;(void)pmin;(void)modulo; res.clear(); return false; }
int gf_vecteur2vectorvectorint(const vecteur & v,std::vector< std::vector<int> > & V,gen & x,std::vector<int> & pmin){ (void)v; V.clear(); x=0; pmin.clear(); return 0; }
void gf_vectorvectorint2vecteur(const std::vector< std::vector<int> > & source,vecteur & target,const gen & carac,const vecteur & pmin,const gen & x){ (void)source;(void)carac;(void)pmin;(void)x; target.clear(); }
void gf_vectorvectorint2vecteur(const std::vector< std::vector<int> > & source,vecteur & target,int carac,const std::vector<int> & pmin,const gen & x){ (void)source;(void)carac;(void)pmin;(void)x; target.clear(); }
galois_field::galois_field(const galois_field & q,bool doreduce) : gen_user(q), p(q.p), P(q.P), x(q.x), a(q.a) { (void)doreduce; }
galois_field::galois_field(const gen p_,const gen & P_,const gen & x_,const gen & a_,bool doreduce) : gen_user(), p(p_), P(P_), x(x_), a(a_) { (void)doreduce; }
// vtable/typeinfo requirements (all virtual members return neutral values)
gen galois_field::operator + (const gen & g) const { (void)g; return gensizeerr(gettext("Galois field module is disabled in this build")); }
gen galois_field::operator - (const gen & g) const { (void)g; return gensizeerr(gettext("Galois field module is disabled in this build")); }
gen galois_field::operator - () const { return gensizeerr(gettext("Galois field module is disabled in this build")); }
gen galois_field::operator * (const gen & g) const { (void)g; return gensizeerr(gettext("Galois field module is disabled in this build")); }
gen galois_field::operator / (const gen & g) const { (void)g; return gensizeerr(gettext("Galois field module is disabled in this build")); }
gen galois_field::inv () const { return gensizeerr(gettext("Galois field module is disabled in this build")); }
std::string galois_field::print (GIAC_CONTEXT) const { return std::string(); }
std::string galois_field::texprint (GIAC_CONTEXT) const { return std::string(); }
gen galois_field::giac_constructor (GIAC_CONTEXT) const { return gensizeerr(gettext("Galois field module is disabled in this build")); }
bool galois_field::operator == (const gen & g) const { (void)g; return false; }
bool galois_field::is_zero() const { return false; }
bool galois_field::is_one() const { return false; }
bool galois_field::is_minus_one() const { return false; }
gen galois_field::operator () (const gen & g,GIAC_CONTEXT) const { (void)g; return gensizeerr(gettext("Galois field module is disabled in this build")); }
gen galois_field::operator [] (const gen & g) { (void)g; return gensizeerr(gettext("Galois field module is disabled in this build")); }
gen galois_field::operator > (const gen & g) const { (void)g; return 0; }
gen galois_field::operator < (const gen & g) const { (void)g; return 0; }
gen galois_field::operator >= (const gen & g) const { (void)g; return 0; }
gen galois_field::operator <= (const gen & g) const { (void)g; return 0; }
gen galois_field::polygcd (const polynome & p,const polynome & q,polynome & r) const { (void)p;(void)q; r=polynome(1); return plus_one; }
gen galois_field::makegen(int i) const { (void)i; return 0; }
gen galois_field::polyfactor (const polynome & p,factorization & f) const { (void)p; f.clear(); return plus_one; }
gen galois_field::sqrt(GIAC_CONTEXT) const { return gensizeerr(gettext("Galois field module is disabled in this build")); }
gen galois_field::rand(GIAC_CONTEXT) const { return gensizeerr(gettext("Galois field module is disabled in this build")); }
#endif // GIAC_NO_QUATER

#if defined GIAC_NO_SIGNAL
// ===================== Signal processing (signalprocessing.cc) =====================
// signalprocessing.cc:69-89 (verbatim): full-system error-semantics chain
// (optimization.cc validation paths rely on these error types).
gen generr(const char* msg) {
    string m(msg);
    m.append(".");
    return gensizeerr(m.c_str());
}
static gen giac_stub_signal_unary(const gen &,GIAC_CONTEXT){
  return giac_module_disabled("Signal processing module is disabled in this build");
}
static define_unary_function_eval (__STUB_SIGNAL,giac_stub_signal_unary,"stub");
#define STUB_SIGNAL_PTR (&__STUB_SIGNAL)
define_unary_function_ptr5(at_istft, alias_at_istft, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_train, alias_at_train, STUB_SIGNAL_PTR, 0, 0);
// signalprocessing.cc:91-97 (verbatim): warnings (e.g. "some critical points
// may have been undetected") must reach the user instead of being swallowed.
void print_error(const char *msg,GIAC_CONTEXT) {
    *logptr(contextptr) << gettext("Error") << ": " << gettext(msg) << "\n";
}
void print_warning(const char *msg,GIAC_CONTEXT) {
    *logptr(contextptr) << gettext("Warning") << ": " << gettext(msg) << "\n";
}
void set_assumptions(const gen &g,const vecteur &cond,const vecteur &excluded,bool additionally,GIAC_CONTEXT) {
    if (cond.empty())
        return;
    vecteur args;
    for (const_iterateur it=cond.begin();it!=cond.end();++it) {
        if (it->type==_VECT) {
            assert(it->_VECTptr->size()==2);
            const gen &lb=it->_VECTptr->front(),&ub=it->_VECTptr->back();
            gen l=is_inf(lb)?undef:(contains(excluded,lb)?symb_superieur_strict(g,lb):symb_superieur_egal(g,lb));
            gen r=is_inf(ub)?undef:(contains(excluded,ub)?symb_inferieur_strict(g,ub):symb_inferieur_egal(g,ub));
            if (!is_undef(l) && !is_undef(r))
                args.push_back(symb_and(l,r));
            else if (!is_undef(l))
                args.push_back(l);
            else if (!is_undef(r))
                args.push_back(r);
        } else args.push_back(*it);
    }
    gen a=symbolic(at_ou,change_subtype(args,_SEQ__VECT));
    if (additionally)
        giac_additionally(a,contextptr);
    else giac_assume(a,contextptr);
}
gen _convolution(const gen & args,GIAC_CONTEXT){ return giac_stub_signal_unary(args,contextptr); }
bool laplace_periodic(const gen &g_orig,const gen &x,const gen &s,gen &t,GIAC_CONTEXT){ (void)g_orig;(void)x;(void)s; t=0; return false; }
bool ilaplace2(const gen &g,const gen &s,const gen &x,gen &orig,GIAC_CONTEXT){ (void)g;(void)s;(void)x; orig=0; return false; }
double audio_clip::peak() const { return 0.0; }
rgba_image rgba_image::blend(const rgba_image &other,double t) const { (void)other;(void)t; return *this; }
rgba_image rgba_image::blend(int color,double t) const { (void)color;(void)t; return *this; }
int rgba_image::write_png(const char *fname) const { (void)fname; return 0; }

define_unary_function_ptr5(at_Fourier, alias_at_Fourier, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_Heaviside2sign, alias_at_Heaviside2sign, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_Hilbert, alias_at_Hilbert, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_addtable, alias_at_addtable, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_auto_correlation, alias_at_auto_correlation, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_bartlett_hann_window, alias_at_bartlett_hann_window, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_bit_depth, alias_at_bit_depth, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_blackman_harris_window, alias_at_blackman_harris_window, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_blackman_window, alias_at_blackman_window, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_bohman_window, alias_at_bohman_window, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_boxcar, alias_at_boxcar, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_channel_data, alias_at_channel_data, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_channels, alias_at_channels, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_convolution, alias_at_convolution, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_cosine_window, alias_at_cosine_window, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_createwav, alias_at_createwav, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_cross_correlation, alias_at_cross_correlation, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_duration, alias_at_duration, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_dwt, alias_at_dwt, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_emd, alias_at_emd, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_fourier, alias_at_fourier, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_gaussian_window, alias_at_gaussian_window, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_hamming_window, alias_at_hamming_window, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_hann_poisson_window, alias_at_hann_poisson_window, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_hann_window, alias_at_hann_window, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_hht, alias_at_hht, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_highpass, alias_at_highpass, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_hilbert, alias_at_hilbert, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_idwt, alias_at_idwt, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_ifourier, alias_at_ifourier, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_imfplot, alias_at_imfplot, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_instfreq, alias_at_instfreq, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_instphase, alias_at_instphase, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_linabs, alias_at_linabs, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_linstep, alias_at_linstep, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_logistic, alias_at_logistic, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_lowpass, alias_at_lowpass, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_mixdown, alias_at_mixdown, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_moving_average, alias_at_moving_average, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_neural_network, alias_at_neural_network, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_parzen_window, alias_at_parzen_window, STUB_SIGNAL_PTR, 0, 0);
gen sign2Heaviside(const gen &g) {
    // full implementation copied from signalprocessing.cc:433
    if (g.type==_VECT) {
        vecteur res;
        res.reserve(g._VECTptr->size());
        for (const_iterateur it=g._VECTptr->begin();it!=g._VECTptr->end();++it) {
            res.push_back(sign2Heaviside(*it));
        }
        return gen(res,g.subtype);
    }
    if (g.is_symb_of_sommet(at_sign))
        return 2*symbolic(at_Heaviside,g._SYMBptr->feuille)-1;
    if (g.type==_SYMB)
        return symbolic(g._SYMBptr->sommet,sign2Heaviside(g._SYMBptr->feuille));
    return g;
}
bool is_const_wrt(const gen &g,const gen &x,GIAC_CONTEXT) {
    // full implementation copied from signalprocessing.cc:483
    return is_constant_wrt(sign2Heaviside(g),x,contextptr) && !contains(*_lname(g,contextptr)._VECTptr,x);
}
bool is_integer_idnt(const gen &g,GIAC_CONTEXT) {
    // full implementation copied from signalprocessing.cc:487
    if (g.type!=_IDNT)
        return false;
    matrice i;
    vecteur e;
    int d;
    return get_assumptions(g,d,i,e,contextptr) && d==2;
}
bool is_real_number(const gen &g,GIAC_CONTEXT) {
    // full implementation copied from signalprocessing.cc:262
    if (g.type==_INT_ || g.type==_ZINT || g.type==_FLOAT_ || g.type==_DOUBLE_ || g.type==_REAL || g.type==_FRAC)
        return true;
    return evalf_double(g,1,contextptr).type==_DOUBLE_;
}
#define MAX_TAILLE 500
bool is_simpler(const gen &a,const gen &b) {
    return taille(a,MAX_TAILLE)<taille(b,MAX_TAILLE);
}
bool get_assumptions(const gen &g,int &dom,matrice &intervals,vecteur &excluded,GIAC_CONTEXT) {
    // full implementation copied from signalprocessing.cc:361
    if (g.type!=_IDNT)
        return false;
    dom=-1;
    intervals.clear();
    excluded.clear();
    gen res=_about(g,contextptr);
    if (res.type==_IDNT && res==g) {
        intervals.push_back(makevecteur(minus_inf,plus_inf));
        return true; // no assumptions
    }
    if (res.type!=_VECT || res.subtype!=_ASSUME__VECT)
        return false;
    if (res._VECTptr->size()==1) {
        if (!res._VECTptr->front().is_integer())
            return false;
        dom=res._VECTptr->front().val;
        return true;
    }
    if (res._VECTptr->size()!=3)
        return false;
    if (res._VECTptr->front().is_integer())
        dom=res._VECTptr->front().val; // 1 - real, 2 - integer, 4 - complex, 10 - rational
    intervals=*res._VECTptr->at(1)._VECTptr;
    excluded=*res._VECTptr->at(2)._VECTptr;
    return true;
}
gen simplify_floor(const gen &g,GIAC_CONTEXT) {
    if (g.type==_VECT) {
        vecteur res;
        res.reserve(g._VECTptr->size());
        const_iterateur it=g._VECTptr->begin(),itend=g._VECTptr->end();
        for (;it!=itend;++it) {
            res.push_back(simplify_floor(*it,contextptr));
        }
        return gen(res,g.subtype);
    }
    if (g.type!=_SYMB)
        return g;
    const gen &args=g._SYMBptr->feuille;
    if (g.is_symb_of_sommet(at_floor)) {
        gen e=expand(ratnormal(simplify_floor(args,contextptr),contextptr),contextptr),ar=0,rest=0,num,den;
        vecteur terms=e.is_symb_of_sommet(at_plus)?*e._SYMBptr->feuille._VECTptr:vecteur(1,e);
        const_iterateur it=terms.begin(),itend=terms.end();
        for (;it!=itend;++it) {
            if (is_inZ(*it,contextptr))
                rest+=*it;
            else if (is_real_number(*it,contextptr)) {
                gen f=_floor(_abs(*it,contextptr),contextptr),s=_sign(*it,contextptr);
                rest+=f*s;
                ar+=*it-f*s;
            } else ar+=*it;
        }
        ar=ratnormal(ar,contextptr);
        if (is_inZ(ar,contextptr))
            return ar+rest;
        if (ar.type==_FRAC)
            return rest+(is_positive(ar,contextptr)?symbolic(at_floor,ar):
                         -symbolic(at_floor,(_abs(ar._FRACptr->num,contextptr)-1)/_abs(ar._FRACptr->den,contextptr))-1);
        /* handle some cases of nesting */
        if ((den=_denom(ar,contextptr)).is_integer() && den.val>0) {
            num=expand(simplify_floor(_numer(ar,contextptr),contextptr),contextptr);
            gen a,b,c(undef);
            if (num.is_symb_of_sommet(at_floor))
                return rest+simplify_floor(_floor(num._SYMBptr->feuille/den,contextptr),contextptr);
            if (num.is_symb_of_sommet(at_neg) && (a=num._SYMBptr->feuille).is_symb_of_sommet(at_ceil))
                return rest+simplify_floor(_floor(-a._SYMBptr->feuille/den,contextptr),contextptr);
            if (num.is_symb_of_sommet(at_plus) && num._SYMBptr->feuille.type==_VECT) {
                const vecteur &terms=*num._SYMBptr->feuille._VECTptr;
                const_iterateur it=terms.begin(),itend=terms.end(),jt=itend;
                a=undef;
                for (;it!=itend;++it) {
                    if (it->is_symb_of_sommet(at_floor)) {
                        if (is_undef(a) || is_simpler(a,it->_SYMBptr->feuille)) {
                            a=it->_SYMBptr->feuille;
                            jt=it;
                        }
                    } else if (it->is_symb_of_sommet(at_neg) && (b=it->_SYMBptr->feuille).is_symb_of_sommet(at_ceil)) {
                        if (is_undef(a) || is_simpler(a,-b._SYMBptr->feuille)) {
                            a=-b._SYMBptr->feuille;
                            jt=it;
                        }
                    }
                }
                if (jt!=itend) {
                    vecteur t(terms);
                    t.erase(t.begin()+(jt-terms.begin()));
                    b=_sum(t,contextptr);
                    if (is_inZ(b,contextptr))
                        return rest+simplify_floor(_floor(ratnormal((a+b)/den,contextptr),contextptr),contextptr);
                }
            }
        }
        return is_zero(rest)?_floor(ar,contextptr):rest+simplify_floor(_floor(ar,contextptr),contextptr);
    }
    if (g.is_symb_of_sommet(at_ceil))
        return simplify_floor(-symbolic(at_floor,-args),contextptr);
    return symbolic(g._SYMBptr->sommet,simplify_floor(args,contextptr));
}

bool is_inZ(const gen &g_orig,GIAC_CONTEXT) {
    // full implementation copied from signalprocessing.cc:492
    gen g=ratnormal(g_orig,contextptr);
    if (g.is_integer() || is_integer_idnt(g,contextptr))
        return true;
    if (g.type!=_SYMB || !is_one(_denom(g,contextptr)))
        return false;
    const gen &ar=g._SYMBptr->feuille;
    if (g.is_symb_of_sommet(at_neg))
        return is_inZ(ar,contextptr);
    gen d;
    if (g.is_symb_of_sommet(at_pow) && ar.type==_VECT && (d=ar._VECTptr->back()).is_integer() && d.val>=0)
        return is_inZ(ar._VECTptr->front(),contextptr);
    if (g.is_symb_of_sommet(at_floor) || g.is_symb_of_sommet(at_ceil) ||
            g.is_symb_of_sommet(at_sign) || g.is_symb_of_sommet(at_Heaviside) ||
            g.is_symb_of_sommet(at_legendre_symbol) || g.is_symb_of_sommet(at_jacobi_symbol))
        return true;
    if ((g.is_symb_of_sommet(at_plus) || g.is_symb_of_sommet(at_prod)) && ar.type==_VECT) {
        const_iterateur it=ar._VECTptr->begin(),itend=ar._VECTptr->end();
        for (;it!=itend;++it) {
            if (!is_inZ(*it,contextptr))
                return false;
        }
        return true;
    }
    return false;
}
bool is_periodic_wrt(const gen &g_orig,const gen &x,gen &T,GIAC_CONTEXT) {
    gen g=ratnormal(g_orig,contextptr);
    if (is_const_wrt(g,x,contextptr))
        return true;
    gen f=_lin(trig2exp(g,contextptr),contextptr);
    vecteur v;
    lvar(f,v);
    bool hasx=find(v.begin(),v.end(),x)!=v.end();
    v.clear();
    rlvarx(f,x,v);
    islesscomplexthanf_sort(v.begin(),v.end());
    int i,s=int(v.size());
    if (s<2)
        return false;
    gen a,b,r,d,U;
    bool chk=false,upd;
    for (i=1;i<s && !is_inf(T);++i) {
        upd=false;
        if (v[i].is_symb_of_sommet(at_exp) && is_linear_wrt(v[i]._SYMBptr->feuille,x,a,b,contextptr) && !is_zero(a)) {
            U=ratnormal(cst_two_pi*cst_i/a,contextptr);
            if (!is_zero(ratnormal(im(U,contextptr),contextptr)))
                return false;
            U=_abs(U,contextptr);
            upd=true;
        } else if (v[i].is_symb_of_sommet(at_floor) && is_linear_wrt(v[i]._SYMBptr->feuille,x,a,b,contextptr) &&
                !is_zero(a) && is_const_wrt(b,x,contextptr)) {
            U=ratnormal(_inv(_abs(a,contextptr),contextptr));
            upd=true;
            chk=true;
        } else if (v[i].type==_SYMB && v[i]._SYMBptr->feuille.type!=_VECT) {
            if (!is_periodic_wrt(v[i]._SYMBptr->feuille,x,T,contextptr))
                return false;
        } else return false;
        if (upd) {
            if (is_undef(T))
                T=U;
            else {
                r=ratnormal(T/U,contextptr);
                if (!is_inZ(_numer(r,contextptr),contextptr) || !is_inZ(d=_denom(r,contextptr),contextptr))
                    return false;
                T=T*d;
            }
        }
    }
    if (chk) {
        gen s=simplify_floor(g-subst(g,x,x+T,false,contextptr),contextptr);
        return is_zero(simplify(s,contextptr)) || is_zero(_trigsimplify(s,contextptr));
    }
    return !hasx;
}

/* Return a period of the given expression if it is periodic with respect
 * to the given real variable, else return +inf.
 * If the returned value is zero, it means that any positive real number is
 * a period (e.g. for constant functions). */
gen _period(const gen &g,GIAC_CONTEXT) {
    if (g.type==_STRNG && g.subtype==-1) return g;
    gen e,x=identificateur("x"),T(undef);
    if (g.type!=_VECT || g.subtype!=_SEQ__VECT)
        e=g;
    else {
        if (g._VECTptr->size()!=2)
            return gendimerr(contextptr);
        if ((x=g._VECTptr->back()).type!=_IDNT)
            return gentypeerr(contextptr);
        e=g._VECTptr->front();
    }
    e=simplify_floor(recursive_normal(e,contextptr),contextptr);
    if (!is_periodic_wrt(e,x,T,contextptr))
        return plus_inf;
    return is_undef(T)?gen(0):T;
}
static const char _period_s[]="period";
static const char _STUB_period_s[]="period";
static define_unary_function_eval (__STUB_PERIOD,&_period,_STUB_period_s);
define_unary_function_ptr5(at_period,alias_at_period,&__STUB_PERIOD,0,true);
define_unary_function_ptr5(at_playsnd, alias_at_playsnd, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_plotimf, alias_at_plotimf, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_plotspectrum, alias_at_plotspectrum, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_plotwav, alias_at_plotwav, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_poisson_window, alias_at_poisson_window, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_readwav, alias_at_readwav, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_rect, alias_at_rect, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_resample, alias_at_resample, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_riemann_window, alias_at_riemann_window, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_rms, alias_at_rms, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_samplerate, alias_at_samplerate, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_set_channel_data, alias_at_set_channel_data, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_sign2Heaviside, alias_at_sign2Heaviside, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_simplifyDirac, alias_at_simplifyDirac, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_simplifyFloor, alias_at_simplifyFloor, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_sinc, alias_at_sinc, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_soundsec, alias_at_soundsec, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_splice, alias_at_splice, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_stereo2mono, alias_at_stereo2mono, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_stft, alias_at_stft, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_threshold, alias_at_threshold, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_tri, alias_at_tri, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_triangle_window, alias_at_triangle_window, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_trim, alias_at_trim, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_tukey_window, alias_at_tukey_window, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_welch_window, alias_at_welch_window, STUB_SIGNAL_PTR, 0, 0);
define_unary_function_ptr5(at_writewav, alias_at_writewav, STUB_SIGNAL_PTR, 0, 0);

gen flatten_piecewise(const gen & g,GIAC_CONTEXT){ return giac_module_disabled("Signal processing module is disabled in this build"); }
// signalprocessing.cc:297 (verbatim): required by extrema critical-point
// filtering (optimization.cc) when GRAPH kept + SIGNAL pruned.
bool is_logical(const gen & g) {
    return g.is_symb_of_sommet(at_and) || g.is_symb_of_sommet(at_ou) ||
        g.is_symb_of_sommet(at_superieur_egal) || g.is_symb_of_sommet(at_inferieur_egal) ||
        g.is_symb_of_sommet(at_superieur_strict) || g.is_symb_of_sommet(at_inferieur_strict) ||
        g.is_symb_of_sommet(at_same) || g.is_symb_of_sommet(at_equal);
}

// signalprocessing.cc:268 (verbatim)
bool is_real_vector(const vecteur &v,GIAC_CONTEXT) {
    const_iterateur it=v.begin(),itend=v.end();
    for (;it!=itend;++it) {
        if (!is_real_number(*it,contextptr))
            return false;
    }
    return true;
}
gen to_piecewise(const gen & g_orig,const identificateur & x,GIAC_CONTEXT){ (void)g_orig;(void)x; return giac_module_disabled("Signal processing module is disabled in this build"); }
// signalprocessing.cc:277 (verbatim)
gen to_real_number(const gen &g,GIAC_CONTEXT) {
    gen ret=_evalf(g,contextptr);
    if (ret.type!=_DOUBLE_)
        return evalf_double(ret,1,contextptr);
    return ret;
}
gen (*load_image_ptr)(const char * fname,GIAC_CONTEXT)=0;
audio_clip * audio_clip::from_gen(const gen & g){ (void)g; return 0; }
void audio_clip::normalize(double dbfs){ (void)dbfs; }
rgba_image * rgba_image::from_gen(const gen & g){ (void)g; return 0; }
rgba_image::~rgba_image(){}
rgba_image::rgba_image(int d,int w,int h,GIAC_CONTEXT) : gen_user(),ctx(contextptr),_filename(),_tmp(false),_d(d),_w(w),_h(h),_data(0) {}
rgba_image::rgba_image(int d,int w,const std::string & data,GIAC_CONTEXT) : gen_user(),ctx(contextptr),_filename(),_tmp(false),_d(d),_w(w),_h(0),_data(0) {}
rgba_image::rgba_image(const std::vector<const gen*> & data,GIAC_CONTEXT) : gen_user(),ctx(contextptr),_filename(),_tmp(false),_d(0),_w(0),_h(0),_data(0) { (void)data; }
rgba_image::rgba_image(const rgba_image & other,int x,int y,int w,int h) : gen_user(),ctx(other.ctx),_filename(),_tmp(false),_d(other._d),_w(other._w),_h(other._h),_data(0) { (void)x;(void)y;(void)w;(void)h; }
void rgba_image::flatten(vecteur & res) const { res.clear(); }
bool rgba_image::assure_on_disk(){ return false; }
std::string rgba_image::print(GIAC_CONTEXT) const { return std::string(); }
std::string rgba_image::texprint(GIAC_CONTEXT) const { return std::string(); }
gen rgba_image::giac_constructor(GIAC_CONTEXT) const { return gensizeerr(gettext("Signal processing module is disabled in this build")); }
bool rgba_image::operator==(const gen & g) const { (void)g; return false; }
gen rgba_image::operator()(const gen & g,GIAC_CONTEXT) const { (void)g; return gensizeerr(gettext("Signal processing module is disabled in this build")); }
gen rgba_image::operator[](const gen & g){ (void)g; return gensizeerr(gettext("Signal processing module is disabled in this build")); }
rgba_image rgba_image::to_negative() const { return *this; }
std::string rgba_image::color_type_string() const { return std::string(); }
gen generrtype(const char* msg) {
    string m(msg);
    m.append(".");
    return gentypeerr(m.c_str());
}
gen generrdim(const char* msg) {
    string m(msg);
    m.append(".");
    return gendimerr(m.c_str());
}
gen generrarg(int i) {
    return generr(string(gettext("Invalid argument")+string(" ")+print_INT_(i)).c_str());
}
#endif // GIAC_NO_SIGNAL

#if defined GIAC_NO_MAPLE
// ===================== Maple syntax (maple.cc) =====================
static gen giac_stub_maple_unary(const gen &,GIAC_CONTEXT){
  return giac_module_disabled("Maple syntax module is disabled in this build");
}
static define_unary_function_eval (__STUB_MAPLE,giac_stub_maple_unary,"stub");
#define STUB_MAPLE_PTR (&__STUB_MAPLE)
define_unary_function_ptr5(at_array, alias_at_array, STUB_MAPLE_PTR, 0, 0);
// at_copy implements the "copy" command; parser_symb_sto (usual.cc) uses it for
// every list assignment (a:=[...]), so it must stay functional.
static gen giac_stub_copy(const gen & g,GIAC_CONTEXT){
  // full implementation copied from maple.cc _copy
  if ( g.type==_STRNG && g.subtype==-1) return  g;
  if (g.type==_VECT){
    vecteur v(*g._VECTptr);
    iterateur it=v.begin(),itend=v.end();
    for (;it!=itend;++it)
      *it=giac_stub_copy(*it,contextptr);
    return gen(v,g.subtype);
  }
  if (g.type==_MAP)
    return gen(*g._MAPptr);
  return g;
}
static define_unary_function_eval (__STUB_COPY,giac_stub_copy,"copy");
define_unary_function_ptr5(at_copy, alias_at_copy, &__STUB_COPY, 0, true);
define_unary_function_ptr5(at_gcdex, alias_at_gcdex, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_interp, alias_at_interp, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_reverse, alias_at_reverse, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_revlist, alias_at_revlist, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_time, alias_at_time, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_zip, alias_at_zip, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_about, alias_at_about, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_close, alias_at_close, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_count, alias_at_count, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_evala, alias_at_evala, STUB_MAPLE_PTR, 0, 0);
static gen giac_stub_at_evalc(const gen & g,GIAC_CONTEXT){ return _evalc(g,contextptr); }
static define_unary_function_eval (__STUB_EVALC,giac_stub_at_evalc,"evalc");
define_unary_function_ptr5(at_evalc, alias_at_evalc, &__STUB_EVALC, 0, true);
define_unary_function_ptr5(at_fopen, alias_at_fopen, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_pivot, alias_at_pivot, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_trunc, alias_at_trunc, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_Inverse, alias_at_Inverse, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_JordanBlock, alias_at_JordanBlock, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_Nullspace, alias_at_Nullspace, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_Phi, alias_at_Phi, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_Resultant, alias_at_Resultant, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_accumulate_head_tail, alias_at_accumulate_head_tail, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_animate, alias_at_animate, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_animate3d, alias_at_animate3d, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_assign, alias_at_assign, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_binprint, alias_at_binprint, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_blockmatrix, alias_at_blockmatrix, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_border, alias_at_border, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_cat, alias_at_cat, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_col, alias_at_col, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_colspace, alias_at_colspace, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_companion, alias_at_companion, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_count_eq, alias_at_count_eq, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_count_inf, alias_at_count_inf, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_count_sup, alias_at_count_sup, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_cpp, alias_at_cpp, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_cprint, alias_at_cprint, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_delcols, alias_at_delcols, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_delrows, alias_at_delrows, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_div, alias_at_div, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_divide, alias_at_divide, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_even, alias_at_even, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_fclose, alias_at_fclose, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_fft, alias_at_fft, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_fprint, alias_at_fprint, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_gaussjord, alias_at_gaussjord, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_giac, alias_at_giac, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_giac_bin, alias_at_giac_bin, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_giac_hex, alias_at_giac_hex, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_hexprint, alias_at_hexprint, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_ifft, alias_at_ifft, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_igcd, alias_at_igcd, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_igcdex, alias_at_igcdex, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_implicitplot3d, alias_at_implicitplot3d, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_indets, alias_at_indets, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_inverse, alias_at_inverse, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_len, alias_at_len, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_length, alias_at_length, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_lhs, alias_at_lhs, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_makemod, alias_at_makemod, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_modp, alias_at_modp, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_nops, alias_at_nops, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_nullspace, alias_at_nullspace, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_octprint, alias_at_octprint, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_odd, alias_at_odd, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_open, alias_at_open, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_pade, alias_at_pade, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_powermod, alias_at_powermod, STUB_MAPLE_PTR, 0, 0);
static gen giac_stub_ratnormal(const gen & g,GIAC_CONTEXT){ return ratnormal(g,contextptr); }
static define_unary_function_eval (__STUB_RATNORMAL,giac_stub_ratnormal,"ratnormal");
define_unary_function_ptr5(at_ratnormal, alias_at_ratnormal, &__STUB_RATNORMAL, 0, true);
gen _ratnormal(const gen & g,GIAC_CONTEXT){
  // full implementation copied from maple.cc:316
  if ( g.type==_STRNG && g.subtype==-1) return  g;
  return ratnormal(g,contextptr);
}
define_unary_function_ptr5(at_readrgb, alias_at_readrgb, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_restart, alias_at_restart, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_restart_modes, alias_at_restart_modes, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_restart_vars, alias_at_restart_vars, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_reverse_rsolve, alias_at_reverse_rsolve, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_rhs, alias_at_rhs, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_row, alias_at_row, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_rowspace, alias_at_rowspace, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_rsolve, alias_at_rsolve, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_seqsolve, alias_at_seqsolve, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_whattype, alias_at_whattype, STUB_MAPLE_PTR, 0, 0);
define_unary_function_ptr5(at_writergb, alias_at_writergb, STUB_MAPLE_PTR, 0, 0);


gen _evalc(const gen & g,GIAC_CONTEXT){
  // full implementation copied from maple.cc:1394 (required by _sum trig path)
  if ( g.type==_STRNG && g.subtype==-1) return  g;
  if (g.type==_VECT)
    return apply(g,_evalc,contextptr);
  gen tmp(_exp2pow(_lin(recursive_normal(g,contextptr),contextptr),contextptr));
  vecteur l(lop(tmp,at_arg));
  if (!l.empty()){
    vecteur lp=*giac::apply(l,gen_feuille)._VECTptr;
    lp=*apply(lp,contextptr,arg_CPLX)._VECTptr;
    tmp=subst(tmp,l,lp,false,contextptr);
  }
  tmp=recursive_normal(tmp,contextptr);
  vecteur vtmp(lvar(tmp));
  if (vtmp.size()==1 && vtmp[0].is_symb_of_sommet(at_exp)){
    tmp=ratnormal(_halftan(_exp2trig(tmp,contextptr),contextptr),contextptr);
  }
  gen r,i;
  reim(tmp,r,i,contextptr);
  gen tmp2=_lin(inv(tmp,contextptr),contextptr);
  gen re2,im2;
  reim(tmp2,re2,im2,contextptr);
  if (lvar(makevecteur(re2,im2)).size()<lvar(makevecteur(r,i)).size())
    reim(inv(ratnormal(re2,contextptr)+cst_i*ratnormal(im2,contextptr),contextptr),r,i,contextptr);
  if (is_zero(i))
    return r;
  if (is_zero(r))
    return cst_i*i;
  return symbolic(at_plus,gen(makevecteur(r,cst_i*i),_SEQ__VECT));
}
gen _about(const gen & g,GIAC_CONTEXT){
  // full implementation copied from maple.cc:324 (used by in_limit for assumption checks)
  if ( g.type==_STRNG && g.subtype==-1) return  g;
  if (g.type==_VECT)
    return apply(g,contextptr,_about);
  if (g.type==_IDNT)
    return g._IDNTptr->eval(1,g,contextptr);
  return g;
}
gen _count_eq(const gen & args,GIAC_CONTEXT){ return giac_stub_maple_unary(args,contextptr); }
gen _revlist(const gen & args,GIAC_CONTEXT){ return giac_stub_maple_unary(args,contextptr); }
gen product(const polynome & P,const vecteur & v,const gen & n,gen & remains,GIAC_CONTEXT){
  // full implementation copied from maple.cc:3113 (required by _product in ti89 path)
  polynome Pcont;
  factorization f;
  gen divan=1,res,extra_div=1;
  if (!factor(P,Pcont,f,/* is_primitive*/false,/* with_sqrt*/true,/* complex */true,divan,extra_div) || extra_div!=1){
    remains=r2e(P,v,contextptr);
    return 1;
  }
  res = pow(divan,-n,contextptr);
  factorization::const_iterator it=f.begin(),itend=f.end();
  for (;it!=itend;++it){
    gen tmp=r2e(it->fact,v,contextptr);
    if (it->fact.lexsorted_degree()!=1){
      remains = remains * pow(tmp,it->mult);
    }
    else {
      gen a=derive(tmp,n,contextptr);
      if (is_undef(a))
	return a;
      gen b=normal(tmp-a*n,contextptr);
      res  = res * pow(a,it->mult*n,contextptr) * pow(symbolic(at_factorial,n+b/a-1),it->mult,contextptr);
    }
  }
  return res*pow(r2e(Pcont,v,contextptr),n,contextptr);
}

// product(P,n=a..b) where the first variable in v is n
gen product(const polynome & P,const vecteur & v,const gen & n,const gen & a,const gen & b,GIAC_CONTEXT){
  // full implementation copied from maple.cc:3142
  gen remains(1),res=product(P,v,n,remains,contextptr);
  res=subst(res,n,b+1,false,contextptr)/subst(res,n,a,false,contextptr);
  if (is_one(remains))
    return res;
  else
    return res*symbolic(at_product,gen(makevecteur(remains,n,a,b),_SEQ__VECT));
}
double realtime(){ return 0.0; }
gen _blockmatrix(const gen & args,GIAC_CONTEXT){ return giac_stub_maple_unary(args,contextptr); }
gen _cat(const gen & args,GIAC_CONTEXT){ return giac_stub_maple_unary(args,contextptr); }
gen _fft(const gen & args,GIAC_CONTEXT){ return giac_stub_maple_unary(args,contextptr); }
gen _lhs(const gen & args,GIAC_CONTEXT){ return giac_stub_maple_unary(args,contextptr); }
gen _rhs(const gen & args,GIAC_CONTEXT){ return giac_stub_maple_unary(args,contextptr); }
gen _zip(const gen & args,GIAC_CONTEXT){ return giac_stub_maple_unary(args,contextptr); }
cpureal_t clock_realtime(){ cpureal_t r = {0.0, 0.0}; return r; }
gen _copy(const gen & args,GIAC_CONTEXT){ return giac_stub_maple_unary(args,contextptr); }
gen _delcols(const gen & args,GIAC_CONTEXT){ return giac_stub_maple_unary(args,contextptr); }
gen _delrows(const gen & args,GIAC_CONTEXT){ return giac_stub_maple_unary(args,contextptr); }
gen _even(const gen & args,GIAC_CONTEXT){ return giac_stub_maple_unary(args,contextptr); }
gen _ifft(const gen & args,GIAC_CONTEXT){ return giac_stub_maple_unary(args,contextptr); }
gen _rsolve(const gen & args,GIAC_CONTEXT){ return giac_stub_maple_unary(args,contextptr); }
gen _trunc(const gen & args,GIAC_CONTEXT){ return giac_stub_maple_unary(args,contextptr); }


#endif // GIAC_NO_MAPLE

#if defined GIAC_NO_HELP
// ===================== Help database (help.cc) =====================
const char default_helpfile[] = giac_aide_location; // help.cc:715
bool alpha_order(const aide & a1,const aide & a2){ (void)a1;(void)a2; return false; }
bool has_static_help(const char * & cmd_name,int lang,const char * & howto,const char * & syntax,const char * & examples,const char * & related){ (void)cmd_name;(void)lang;(void)howto;(void)syntax;(void)examples;(void)related; return false; }
aide helpon(const std::string & demande,const std::vector<aide> & v,int language,int count,bool with_op){ (void)demande;(void)v;(void)language;(void)count;(void)with_op; return aide(); }
std::string writehelp(const aide & cur_aide,int language){ (void)cur_aide;(void)language; return std::string(); }
std::vector<aide> readhelp(const char * f_name,int & count,bool warn){ (void)f_name;(void)warn; count=0; return std::vector<aide>(); }
void readhelp(std::vector<aide> & v,const char * f_name,int & count,bool warn){ (void)f_name;(void)warn; v.clear(); count=0; }
std::string localize(const std::string & s,int language){
  // Localization table lives in help.cc (pruned module). Returning the
  // original string matches the official behaviour for the default English
  // locale; type()/DOM_* output stays intact.
  (void)language;
  return s;
}
std::string unlocalize(const std::string & s){ return s; }
bool isalphan(char ch){
  if (ch>='0' && ch<='9')
    return true;
  if (ch>='a' && ch<='z')
    return true;
  if (ch>='A' && ch<='Z')
    return true;
  if (unsigned(ch)>128)
    return true;
  if (ch=='_' || ch=='.' || ch=='~')
    return true;
  return false;
}
std::string printint(int i){ (void)i; return std::string(); }
std::string xcasroot_dir(const char * arg){ (void)arg; return std::string(); }
std::multimap<std::string,std::string> html_mtt;
std::vector<std::string> html_vtt;
std::multimap<std::string,std::string> html_mall;
std::vector<std::string> html_vall;
static gen giac_stub_help_unary(const gen &,GIAC_CONTEXT){
  return giac_module_disabled("Help database module is disabled in this build");
}
static define_unary_function_eval (__STUB_HELP,giac_stub_help_unary,"stub");
#define STUB_HELP_PTR (&__STUB_HELP)
std::vector<std::string> html_help(std::multimap<std::string,std::string> & mtt,const std::string & s){ (void)mtt;(void)s; return std::vector<std::string>(); }
std::string html_help_init(const char * arg,int language,bool verbose,bool force_rebuild){ (void)arg;(void)language;(void)verbose;(void)force_rebuild; return std::string(); }
#endif // GIAC_NO_HELP

#if defined GIAC_NO_DESOLVE
// ===================== Differential equations (desolve.cc) =====================
static gen giac_stub_desolve_unary(const gen &,GIAC_CONTEXT){
  return giac_module_disabled("Differential equation module is disabled in this build");
}
static define_unary_function_eval (__STUB_DESOLVE,giac_stub_desolve_unary,"stub");
#define STUB_DESOLVE_PTR (&__STUB_DESOLVE)
define_unary_function_ptr5(at_Kronecker, alias_at_Kronecker, STUB_DESOLVE_PTR, 0, 0);

gen diffeq_constante(int i,GIAC_CONTEXT){ (void)i; return giac_stub_desolve_unary(gen(0),contextptr); }
// desolve.cc:2513 (required by optimization.o when GRAPH kept + DESOLVE pruned)
bool is_constant_wrt_vars(const gen & e,const vecteur & vars,GIAC_CONTEXT){
  for (const_iterateur it=vars.begin();it!=vars.end();++it) {
    if (!is_constant_wrt(e,*it,contextptr))
      return false;
  }
  return true;
}
bool separate_variables(const gen & f,const gen & x,const gen & y,gen & xfact,gen & yfact,int step_info,GIAC_CONTEXT){ (void)f;(void)x;(void)y;(void)step_info; xfact=yfact=0; return false; }
bool separate_variables(const gen & f,const gen & x,const gen & y,gen & xfact,gen & yfact,GIAC_CONTEXT){ (void)f;(void)x;(void)y; xfact=yfact=0; return false; }
define_unary_function_ptr5(at_desolve, alias_at_desolve, STUB_DESOLVE_PTR, 0, 0);
define_unary_function_ptr5(at_dsolve, alias_at_dsolve, STUB_DESOLVE_PTR, 0, 0);
define_unary_function_ptr5(at_ilaplace, alias_at_ilaplace, STUB_DESOLVE_PTR, 0, 0);
define_unary_function_ptr5(at_invlaplace, alias_at_invlaplace, STUB_DESOLVE_PTR, 0, 0);
define_unary_function_ptr5(at_invztrans, alias_at_invztrans, STUB_DESOLVE_PTR, 0, 0);
define_unary_function_ptr5(at_kovacicsols, alias_at_kovacicsols, STUB_DESOLVE_PTR, 0, 0);
define_unary_function_ptr5(at_laplace, alias_at_laplace, STUB_DESOLVE_PTR, 0, 0);
define_unary_function_ptr5(at_ztrans, alias_at_ztrans, STUB_DESOLVE_PTR, 0, 0);

#endif // GIAC_NO_DESOLVE

#if defined GIAC_NO_KEXTRA
// ===================== Kernel extras (kdisplay.cc, kadd.cc, graphic.c) =====================
// No core source references symbols from this module (desktop builds); only
// quickjs's qjsgiac.c references js_add_graphic (graphic.c) when QuickJS is
// enabled while KEXTRA is pruned. Provide a no-op definition.
struct JSContext;
extern "C" void js_add_graphic(struct JSContext * ctx){ (void)ctx; }
#endif // GIAC_NO_KEXTRA

#if defined GIAC_NO_PLOT
// ===================== Plotting (plot.cc) =====================
static gen giac_stub_plot_unary(const gen &,GIAC_CONTEXT){
  return giac_module_disabled("Plotting module is disabled in this build");
}
static define_unary_function_eval (__STUB_PLOT,giac_stub_plot_unary,"stub");
#define STUB_PLOT_PTR (&__STUB_PLOT)
define_unary_function_ptr5(at_pnt, alias_at_pnt, STUB_PLOT_PTR, 0, 0);
define_unary_function_ptr5(at_pixon, alias_at_pixon, STUB_PLOT_PTR, 0, 0);
define_unary_function_ptr5(at_erase, alias_at_erase, STUB_PLOT_PTR, 0, 0);
define_unary_function_ptr5(at_animation, alias_at_animation, STUB_PLOT_PTR, 0, 0);
void pixon_print(const gen &g,std::string & S,GIAC_CONTEXT){ (void)g;(void)S; }
define_unary_function_ptr5(at_DrawInv, alias_at_DrawInv, STUB_PLOT_PTR, 0, 0);
define_unary_function_ptr5(at_archive, alias_at_archive, STUB_PLOT_PTR, 0, 0);
define_unary_function_ptr5(at_couleur, alias_at_couleur, STUB_PLOT_PTR, 0, 0);
define_unary_function_ptr5(at_display, alias_at_display, STUB_PLOT_PTR, 0, 0);
define_unary_function_ptr5(at_ellipse, alias_at_ellipse, STUB_PLOT_PTR, 0, 0);
define_unary_function_ptr5(at_legende, alias_at_legende, STUB_PLOT_PTR, 0, 0);
gen _parameter(const gen & args,GIAC_CONTEXT){ return giac_stub_plot_unary(args,contextptr); }
gen _paramplot(const gen & args,const context * contextptr){ return giac_stub_plot_unary(args,contextptr); }
gen _perimetre(const gen & args,GIAC_CONTEXT){ return giac_stub_plot_unary(args,contextptr); }
gen _plotparam(const gen & args,GIAC_CONTEXT){ return giac_stub_plot_unary(args,contextptr); }
gen _rectangle(const gen & args,GIAC_CONTEXT){ return giac_stub_plot_unary(args,contextptr); }
gen _xyztrange(const gen & args,GIAC_CONTEXT){ return giac_stub_plot_unary(args,contextptr); }
define_unary_function_ptr5(at_DrawParm, alias_at_DrawParm, STUB_PLOT_PTR, 0, 0);
define_unary_function_ptr5(at_DrwCtour, alias_at_DrwCtour, STUB_PLOT_PTR, 0, 0);
define_unary_function_ptr5(at_equation, alias_at_equation, STUB_PLOT_PTR, 0, 0);
define_unary_function_ptr5(at_funcplot, alias_at_funcplot, STUB_PLOT_PTR, 0, 0);
define_unary_function_ptr5(at_innertln, alias_at_innertln, STUB_PLOT_PTR, 0, 0);
define_unary_function_ptr5(at_longueur, alias_at_longueur, STUB_PLOT_PTR, 0, 0);
define_unary_function_ptr5(at_plotfunc, alias_at_plotfunc, STUB_PLOT_PTR, 0, 0);
define_unary_function_ptr5(at_plotseq, alias_at_plotseq, STUB_PLOT_PTR, 0, 0);
define_unary_function_ptr5(at_segment, alias_at_segment, STUB_PLOT_PTR, 0, 0);
define_unary_function_ptr5(at_triangle, alias_at_triangle, STUB_PLOT_PTR, 0, 0);
extern double class_minimum;
double class_size = 1.0; // plot.cc:174
gen dotvecteur(const gen & a,const gen & b,GIAC_CONTEXT){ (void)a;(void)b; return 0; }
int est_aligne(const gen & a,const gen & b,const gen & c,GIAC_CONTEXT){ (void)a;(void)b;(void)c; return 0; }
std::string gen2string(const gen & g){ (void)g; return std::string(); }
gen mkrand2d3d(int dim,int nargs,gen (* f)(const gen &,const context *),GIAC_CONTEXT){ (void)dim;(void)nargs;(void)f; return 0; }
extern int pixon_size;
int pixon_size = 1; // plot.cc:2883
gen pnt_attrib(const gen & point,const vecteur & attributs,GIAC_CONTEXT){ (void)point;(void)attributs; return point; }
gen projection(const gen & a,const gen & b,const gen & c,GIAC_CONTEXT){ (void)a;(void)b;(void)c; return 0; }
gen projection(const gen & a,const gen & b,GIAC_CONTEXT){ (void)a;(void)b; return 0; }
  vecteur quote_eval(const vecteur & v,const vecteur & quoted,GIAC_CONTEXT){
    /*
      vecteur l(quoted);
      lidnt(v,l);
      int qs=quoted.size();
      l=vecteur(l.begin()+qs,l.end());
      vecteur lnew=*eval(l,1,contextptr)._VECTptr;
      vecteur w=subst(v,l,lnew,true,contextptr);
      return w;
    */
    const_iterateur it=quoted.begin(),itend=quoted.end();
    vector<int> save;
    for (;it!=itend;++it){
      gen tmp=*it;
      if (is_equal(tmp))
	tmp=tmp._SYMBptr->feuille._VECTptr->front();
      if (tmp.type!=_IDNT)
	save.push_back(-1);
      else {
	if (contextptr && contextptr->quoted_global_vars){
	  gen ckassume=tmp._IDNTptr->eval(1,tmp,contextptr);
	  if (ckassume.type==_VECT && ckassume.subtype==_ASSUME__VECT)
	    save.push_back(-1);
	  else {
	    contextptr->quoted_global_vars->push_back(tmp);
	    save.push_back(0);
	  }
	}
	else {
	  if (tmp._IDNTptr->quoted){
	    save.push_back(*tmp._IDNTptr->quoted);
	    *tmp._IDNTptr->quoted=1;
	  }
	  else
	    save.push_back(0);
	}
      }
    }
    vecteur res(v);
    int s=int(v.size());
    for (int i=0;i<s;++i){
#ifndef NO_STDEXCEPT
      try {
#endif
	bool done=false;
	if (v[i].is_symb_of_sommet(at_prod) && v[i]._SYMBptr->feuille.type==_VECT){ // hack for polarplot using re(rho)
	  vecteur vi = *v[i]._SYMBptr->feuille._VECTptr;
	  if (!vi.empty() && vi.front().is_symb_of_sommet(at_re)){
	    vi.front()=vi.front()._SYMBptr->feuille;
	    gen tmp=eval(vi,contextptr);
	    if (tmp.type==_VECT){
	      vi=*tmp._VECTptr;
	      vi.front()=symbolic(at_re,vi.front());
	      res[i]=_prod(vi,contextptr);
	      done=true;
	    }
	  }
	}
	if (!done){
#if 0
	  vecteur lv=lidnt(v[i]);
	  vecteur lw(lv);
	  for (int j=0;j<int(lw.size());++j){
	    gen g=eval(lv[j],1,contextptr);
	    g=ifte2when(g,contextptr); 
	    lw[j]=g;
	  }
	  res[i]=quotesubst(v[i],lv,lw,contextptr); // otherwise plots with if else fails (error not catched with emscripten)
#endif
	  res[i]=eval(v[i],contextptr); 
	}
#ifndef NO_STDEXCEPT
      } catch (std::runtime_error & ){
	last_evaled_argptr(contextptr)=NULL;
	//    *logptr(contextptr) << e.what() << '\n';
      }
#endif
    }
    it=quoted.begin();
    for (int i=0;it!=itend;++it,++i){
      if (save[i]>=0){
	if (contextptr && contextptr->quoted_global_vars)
	  contextptr->quoted_global_vars->pop_back();
	else {
	  gen tmp=*it;
	  if (is_equal(tmp))
	    tmp=tmp._SYMBptr->feuille._VECTptr->front();
	  if (tmp.type==_IDNT && tmp._IDNTptr->quoted)
	    *tmp._IDNTptr->quoted=save[i]>0?save[i]:0;
	}
      }
    }
    return res;
  }
static void plotpreprocess(gen & g,vecteur & quoted,GIAC_CONTEXT){
  // full implementation copied from plot.cc:888
  gen tmp=eval(g,contextptr);
  if (tmp.type==_IDNT){
    g=tmp;
    quoted=vecteur(1,tmp);
    return;
  }
  if (tmp.type==_VECT){
    bool done=true;
    const_iterateur it=tmp._VECTptr->begin(),itend=tmp._VECTptr->end();
    if (it!=itend){
      for (;it!=itend;++it){
	if (it->type!=_IDNT && !it->is_symb_of_sommet(at_at))
	  break;
      }
      if (it==itend){
	g=tmp;
	quoted=*tmp._VECTptr;
      }
      else
	done=false;
    }
    else
      done=false;
    if (!done){
      if (g.type==_VECT)
	quoted=*g._VECTptr;
      else
	quoted=vecteur(1,g);
    }
  }
  else {
    quoted=vecteur(1,g);
  }
}

vecteur plotpreprocess(const gen & args,GIAC_CONTEXT){
  // full implementation copied from plot.cc:1023 (required by solvepreprocess)
  vecteur v;
  if (args.type==_FUNC)
    return makevecteur(args(vx_var,contextptr),vx_var);
  gen var,res;
  if (args.type!=_VECT && is_algebraic_program(args,var,res))
    return makevecteur(args,symb_interval(gnuplot_xmin,gnuplot_xmax));
  int nd;
  if ( (nd=is_distribution(args)) ){
    gen a,b;
    if (distrib_support(nd,a,b,true))
      return makevecteur(args,symb_interval(a,b));
  }
  if ((args.type!=_VECT) || (args.subtype!=_SEQ__VECT) )
    v=makevecteur(args,vx_var);
  else {
    v=*args._VECTptr;
    if (v.empty())
      return vecteur(1,gensizeerr(contextptr));
    if (v.size()==1)
      v.push_back(vx_var);
  }
  // find quoted variables from v[1]
  vecteur quoted;
  if ( v[1].type==_SYMB && (v[1]._SYMBptr->sommet==at_equal || v[1]._SYMBptr->sommet==at_equal2 ||v[1]._SYMBptr->sommet==at_same ))
    plotpreprocess(v[1]._SYMBptr->feuille._VECTptr->front(),quoted,contextptr);
  else
    plotpreprocess(v[1],quoted,contextptr);
  return quote_eval(v,quoted,contextptr);
}
gen put_attributs(const gen & g,const vecteur & attributs,GIAC_CONTEXT){ (void)g;(void)attributs; return g; }
int read_attributs(const vecteur & v,vecteur & attributs,GIAC_CONTEXT){ (void)v; attributs.clear(); return 0; }
void unvect(gen & a){
  // full implementation copied from plot.cc:5684
  if (a.type==_VECT && a.subtype==_VECTOR__VECT && a._VECTptr->size()==2)
    a=a._VECTptr->back()-a._VECTptr->front();
}
gen scalar_product(const gen & a0,const gen & b0,GIAC_CONTEXT){
  // full implementation copied from plot.cc:5689
  gen a=remove_at_pnt(a0);
  gen b=remove_at_pnt(b0);
  unvect(a); unvect(b);
  if (a.type==_VECT && b.type==_VECT)
    return scalarproduct(*a._VECTptr,*b._VECTptr,contextptr);
  gen ax,ay; reim(a,ax,ay,contextptr);
  gen bx,by; reim(b,bx,by,contextptr);
  return ax*bx+ay*by;
}
gen symb_pnt_name(const gen & x,const gen & y,const gen & name,GIAC_CONTEXT){ (void)x;(void)y;(void)name; return giac_stub_plot_unary(gen(0),contextptr); }
define_unary_function_ptr5(at_hyperplan, alias_at_hyperplan, STUB_PLOT_PTR, 0, 0);
define_unary_function_ptr5(at_longueur2, alias_at_longueur2, STUB_PLOT_PTR, 0, 0);
define_unary_function_ptr5(at_parameter, alias_at_parameter, STUB_PLOT_PTR, 0, 0);
define_unary_function_ptr5(at_plotparam, alias_at_plotparam, STUB_PLOT_PTR, 0, 0);
define_unary_function_ptr5(at_rectangle, alias_at_rectangle, STUB_PLOT_PTR, 0, 0);
define_unary_function_ptr5(at_xyztrange, alias_at_xyztrange, STUB_PLOT_PTR, 0, 0);
gen _coordonnees(const gen & args,GIAC_CONTEXT){ return giac_stub_plot_unary(args,contextptr); }
bool centre_rayon(const gen & a,gen & x,gen & y,bool check,GIAC_CONTEXT,bool b){ (void)a;(void)check;(void)b; x=y=0; return false; }
bool check3dpoint(const gen & g){ (void)g; return false; }
gen distance2pp(const gen & a,const gen & b,GIAC_CONTEXT){ (void)a;(void)b; return 0; }
gen funcplotfunc(const gen & g,int i,GIAC_CONTEXT){ (void)g;(void)i; return giac_stub_plot_unary(g,contextptr); }
vecteur gen2vecteur(const gen & args){
  // full implementation copied from plot.cc:6893 (used by core solve code)
  if (args.type==_VECT)
    return *args._VECTptr;
  else
    return vecteur(1,args);
}
extern double gnuplot_tmax;
double gnuplot_tmax = 6.0;
gen makecomplex(const gen & a,const gen & b){
  // full implementation copied from plot.cc:4532
  if ( (a.type>=_CPLX && a.type!=_FLOAT_) || (b.type>=_CPLX && b.type!=_FLOAT_) )
    return a+cst_i*b;
  return gen(a,b);
}
vecteur merge_pixon(const vecteur & v){ (void)v; return v; }
void read_option(const vecteur & v,double xmin,double xmax,double ymin,double ymax,double zmin,double zmax,vecteur & attributs, int & nstep,int & jstep,int & kstep,GIAC_CONTEXT){ (void)v;(void)xmin;(void)xmax;(void)ymin;(void)ymax;(void)zmin;(void)zmax; attributs.clear(); nstep=jstep=kstep=0; }
vecteur seq2vecteur(const gen & g){
  // full implementation copied from plot.cc:8258
  if (g.type==_VECT && g.subtype==_SEQ__VECT)
    return *g._VECTptr;
  else
    return vecteur(1,g);
}
gen translation(const gen & a,const gen & b,GIAC_CONTEXT){ (void)a;(void)b; return 0; }
define_unary_function_ptr5(at_plot_style, alias_at_plot_style, STUB_PLOT_PTR, 0, 0);
extern double class_minimum;
double class_minimum = 0.0;
extern double gnuplot_tmin;
double gnuplot_tmin = -6.0;
extern double gnuplot_xmax;
double gnuplot_xmax = 5.0;
extern double gnuplot_xmin;
double gnuplot_xmin = -5.0;
extern double gnuplot_ymax;
double gnuplot_ymax = 5.0;
extern double gnuplot_ymin;
double gnuplot_ymin = -5.0;
extern double gnuplot_zmax;
double gnuplot_zmax = 5.0;
extern double gnuplot_zmin;
double gnuplot_zmin = -5.0;
gen _plotimplicit(const gen & args,GIAC_CONTEXT){ return giac_stub_plot_unary(args,contextptr); }
gen hypersurface(const gen & args,const gen & equation,const gen & vars){ (void)args;(void)equation;(void)vars; return 0; }
vecteur interpolygone(const vecteur & p,const gen & bb,GIAC_CONTEXT){ (void)p;(void)bb; return vecteur(); }
unary_function_ptr plot_sommets[]={*at_pnt,*at_parameter,*at_cercle,*at_curve,*at_animation,0};
unary_function_ptr not_point_sommets[]={*at_cercle,*at_curve,*at_hyperplan,*at_hypersphere,*at_hypersurface,0};
unary_function_ptr notexprint_plot_sommets[]={*at_funcplot,*at_paramplot,*at_polarplot,*at_implicitplot,*at_contourplot,*at_odeplot,*at_interactive_odeplot,*at_fieldplot,*at_seqplot,*at_ellipse,*at_hyperbole,*at_parabole,0};
unary_function_ptr implicittex_plot_sommets[]={*at_plot,*at_plot3d,*at_plotfunc,*at_plotparam,*at_plotpolar,*at_plotimplicit,*at_plotcontour,*at_DrawInv,*at_DrawFunc,*at_DrawParm,*at_DrawPol,*at_DrwCtour,*at_plotode,*at_plotfield,*at_interactive_plotode,*at_plotseq,*at_Graph,0};
unary_function_ptr point_sommet_tab_op[]={*at_point,*at_element,*at_inter_unique,*at_centre,*at_isobarycentre,*at_barycentre,0};
unary_function_ptr nosplit_polygon_function[]={*at_inter_unique,*at_inter,*at_distanceat,*at_distanceatraw,*at_rotation,*at_projection,*at_symetrie,*at_polaire_reciproque,*at_areaat,*at_areaatraw,*at_perimeterat,*at_perimeteratraw,*at_slopeat,*at_slopeatraw,*at_tangent,*at_cercle,0};
unary_function_ptr measure_functions[]={*at_angleat,*at_angleatraw,*at_areaat,*at_areaatraw,*at_perimeterat,*at_perimeteratraw,*at_slopeat,*at_slopeatraw,*at_distanceat,*at_distanceatraw,0};
unary_function_ptr transformation_functions[]={*at_projection,*at_rotation,*at_translation,*at_homothetie,*at_similitude,*at_inversion,*at_symetrie,*at_polaire_reciproque,0};
gen plotimplicit(const gen& f_orig,const gen&x,const gen & y,double xmin,double xmax,double ymin,double ymax,int nxstep,int nystep,double eps,const vecteur & attributs,bool unfactored,bool cklinear,const context * contextptr,int ckgeo2d){ (void)f_orig;(void)x;(void)y;(void)xmin;(void)xmax;(void)ymin;(void)ymax;(void)nxstep;(void)nystep;(void)eps;(void)attributs;(void)unfactored;(void)cklinear;(void)ckgeo2d; return giac_stub_plot_unary(gen(0),contextptr); }
std::string print_DOUBLE_(double d,unsigned ndigits){ (void)d;(void)ndigits; return std::string(); }
gen symb_segment(const gen & x,const gen & y,const vecteur & v,int i,GIAC_CONTEXT){ (void)x;(void)y;(void)v;(void)i; return giac_stub_plot_unary(gen(0),contextptr); }
define_unary_function_ptr5(at_coordonnees, alias_at_coordonnees, STUB_PLOT_PTR, 0, 0);
define_unary_function_ptr5(at_demi_droite, alias_at_demi_droite, STUB_PLOT_PTR, 0, 0);
define_unary_function_ptr5(at_hypersphere, alias_at_hypersphere, STUB_PLOT_PTR, 0, 0);
define_unary_function_ptr5(at_hypersurface, alias_at_hypersurface, STUB_PLOT_PTR, 0, 0);
gen _polygone_ouvert(const gen & args,GIAC_CONTEXT){ return giac_stub_plot_unary(args,contextptr); }
void ck_parameter_t(GIAC_CONTEXT){ }
void ck_parameter_u(GIAC_CONTEXT){ }
void ck_parameter_v(GIAC_CONTEXT){ }
void ck_parameter_x(GIAC_CONTEXT){ }
void ck_parameter_y(GIAC_CONTEXT){ }
void ck_parameter_z(GIAC_CONTEXT){ }
int colormap_color(int pal,double t,GIAC_CONTEXT){ (void)pal;(void)t; return 0; }
bool equation2geo2d(const gen & f0,const gen & x,const gen & y,gen & g,double tmin,double tmax,double tstep,const gen & pointon,int allowed,const context * contextptr){ (void)f0;(void)x;(void)y;(void)tmin;(void)tmax;(void)tstep;(void)pointon;(void)allowed; g=0; return false; }
bool est_cocyclique(const gen & a,const gen & b,const gen & c,const gen & d,GIAC_CONTEXT){ (void)a;(void)b;(void)c;(void)d; return false; }
bool est_coplanaire(const gen & a,const gen & b,const gen & c,const gen & d,GIAC_CONTEXT){ (void)a;(void)b;(void)c;(void)d; return false; }
int gnuplot_show_pnt(const symbolic & e,GIAC_CONTEXT){ (void)e; return 0; }
bool is_pnt_or_pixon(const gen & g){ (void)g; return false; }
gen parameter2point(const vecteur & v,GIAC_CONTEXT){ (void)v; return giac_stub_plot_unary(gen(0),contextptr); }
gen paramplotparam(const gen & g,int i,GIAC_CONTEXT){ (void)g;(void)i; return giac_stub_plot_unary(g,contextptr); }
symbolic symb_curve(const gen & source,const gen & plot){ (void)source;(void)plot; return symbolic(at_curve,makevecteur(source,plot)); }
const int _GROUP__VECT_subtype[]={_GROUP__VECT,_LINE__VECT,_HALFLINE__VECT,_VECTOR__VECT,_POLYEDRE__VECT,_POINT__VECT,0}; // plot.cc:166
int set_nonblock_flag (int desc, int value){ (void)desc;(void)value; return 0; }
void autoname_plus_plus(std::string & autoname){ (void)autoname; }
void local_sto_double(double value,const identificateur & i,GIAC_CONTEXT){ (void)value;(void)i; }
void local_sto_double_increment(double value,const identificateur & i,GIAC_CONTEXT){ (void)value;(void)i; }
void blend(unsigned char r1,unsigned char g1,unsigned char b1,unsigned char r2,unsigned char g2,unsigned char b2,double t,unsigned char &r,unsigned char &g,unsigned char &b){ (void)r1;(void)g1;(void)b1;(void)r2;(void)g2;(void)b2;(void)t; r=g=b=0; }
int gnuplot_pixels_per_eval = 401; // plot.cc:178
int graph_output_type(const gen & g){ (void)g; return 0; }
bool is_colormap_index(int pal){ (void)pal; return false; }
std::ostream & archive(std::ostream & os,const gen & e,GIAC_CONTEXT){ (void)e; return os; }
gen unarchive(std::istream & is,GIAC_CONTEXT){ (void)is; return 0; }
gen _affixe(const gen & args,GIAC_CONTEXT){ return giac_stub_plot_unary(args,contextptr); }
gen _aire(const gen & args,GIAC_CONTEXT){ return giac_stub_plot_unary(args,contextptr); }
gen _arc(const gen & args,GIAC_CONTEXT){ return giac_stub_plot_unary(args,contextptr); }
gen _bezier(const gen & args,GIAC_CONTEXT){ return giac_stub_plot_unary(args,contextptr); }
gen _cercle(const gen & args,GIAC_CONTEXT){ return giac_stub_plot_unary(args,contextptr); }
gen _droite(const gen & args,GIAC_CONTEXT){ return giac_stub_plot_unary(args,contextptr); }
gen _milieu(const gen & args,GIAC_CONTEXT){ return giac_stub_plot_unary(args,contextptr); }
gen _pixoff(const gen & args,GIAC_CONTEXT){ return giac_stub_plot_unary(args,contextptr); }
gen _pixon(const gen & args,GIAC_CONTEXT){ return giac_stub_plot_unary(args,contextptr); }
gen _plot(const gen & args,GIAC_CONTEXT){ return giac_stub_plot_unary(args,contextptr); }
gen _point(const gen & args,GIAC_CONTEXT){ return giac_stub_plot_unary(args,contextptr); }
gen _vector(const gen & args,GIAC_CONTEXT){ return giac_stub_plot_unary(args,contextptr); }
gen _ecris(const gen & args,GIAC_CONTEXT){ return giac_stub_plot_unary(args,contextptr); }
gen _saisir(const gen & args,GIAC_CONTEXT){ return giac_stub_plot_unary(args,contextptr); }
gen _position(const gen & args,GIAC_CONTEXT){ return giac_stub_plot_unary(args,contextptr); }
gen _equation(const gen & args,GIAC_CONTEXT){ return giac_stub_plot_unary(args,contextptr); }
gen _plotfunc(const gen & args,GIAC_CONTEXT){ return giac_stub_plot_unary(args,contextptr); }
gen _couleur(const gen & args,GIAC_CONTEXT){ return giac_stub_plot_unary(args,contextptr); }
gen _legende(const gen & args,GIAC_CONTEXT){ return giac_stub_plot_unary(args,contextptr); }
gen _parameq(const gen & args,GIAC_CONTEXT){ return giac_stub_plot_unary(args,contextptr); }
gen _segment(const gen & args,GIAC_CONTEXT){ return giac_stub_plot_unary(args,contextptr); }
gen _tangent(const gen & args,GIAC_CONTEXT){ return giac_stub_plot_unary(args,contextptr); }
gen _polygone(const gen & args,GIAC_CONTEXT){ return giac_stub_plot_unary(args,contextptr); }
gen _symetrie(const gen & args,GIAC_CONTEXT){ return giac_stub_plot_unary(args,contextptr); }
gen abs_norm(const gen & a,GIAC_CONTEXT){ (void)a; return 0; }
gen abs_norm2(const gen & a,GIAC_CONTEXT){ (void)a; return 0; }
vecteur inter(const gen & a,const gen & b,GIAC_CONTEXT){ (void)a;(void)b; return vecteur(); }
gen apply3d(const gen & args,const gen & v,GIAC_CONTEXT,gen (* f)(const gen &,const gen &,GIAC_CONTEXT)){ (void)args;(void)v;(void)f; return 0; }
gen curve_surface_apply(const gen & args,const gen & v,gen (* f)(const gen &,const gen &,GIAC_CONTEXT),GIAC_CONTEXT){ (void)args;(void)v;(void)f; return 0; }
gen droite_by_equation(const vecteur & v,bool est_plan,GIAC_CONTEXT){ (void)v;(void)est_plan; return 0; }
bool est_parallele_vecteur(const vecteur & v,const vecteur & w,gen & r,GIAC_CONTEXT){ (void)v;(void)w; r=0; return false; }
void read_tmintmaxtstep(vecteur & vargs,gen & t,int vstart,double &tmin,double & tmax,double &tstep,bool & tminmax_defined,bool & tstep_defined,GIAC_CONTEXT){ (void)vargs;(void)t;(void)vstart;(void)tminmax_defined;(void)tstep_defined; tmin=tmax=tstep=0; }
vecteur remove_not_in_segment(const gen & a,const gen & b,int subtype,const vecteur & v,GIAC_CONTEXT){ (void)a;(void)b;(void)subtype;(void)v; return vecteur(); }
void rewrite_with_t_real(gen & eq,const gen & t,GIAC_CONTEXT){ (void)eq;(void)t; }
bool chk_double_interval(const gen & g,double & inf,double & sup,GIAC_CONTEXT){ (void)g; inf=sup=0; return false; }
bool colormap_color_rgb(int pal,double t,int &c,int &r,int &g,int &b,GIAC_CONTEXT){ (void)pal;(void)t; c=r=g=b=0; return false; }
std::vector<logo_turtle> vecteur2turtlevect(const vecteur & v){ (void)v; return std::vector<logo_turtle>(); }

gen _tourne_droite(const gen & args,GIAC_CONTEXT){ return giac_stub_plot_unary(args,contextptr); }
gen _tourne_gauche(const gen & args,GIAC_CONTEXT){ return giac_stub_plot_unary(args,contextptr); }
bool get_sol(gen & sol,GIAC_CONTEXT){ (void)sol; return false; }
gen readvar(const gen & g){ (void)g; return 0; }
int erase_pos(GIAC_CONTEXT){ return 0; }
vecteur get_style(const vecteur & v,std::string & legende){ (void)v; legende.clear(); return vecteur(); }
gen readrange(const gen & g,double a,double b,gen & c,double & d,GIAC_CONTEXT){ (void)g;(void)a;(void)b;(void)d; c=0; return 0; }
gen xyztrange(double xmin,double xmax,double ymin,double ymax,double zmin,double zmax,double tmin,double tmax,double wxmin,double wxmax,double wymin, double wymax, int axes,double class_minimum,double class_size,bool gnuplot_hidden3d,bool gnuplot_pm3d){ (void)xmin;(void)xmax;(void)ymin;(void)ymax;(void)zmin;(void)zmax;(void)tmin;(void)tmax;(void)wxmin;(void)wxmax;(void)wymin;(void)wymax;(void)axes;(void)class_minimum;(void)class_size;(void)gnuplot_hidden3d;(void)gnuplot_pm3d; return 0; }
void rgb2xyz(double R,double G,double B,double &x,double &y,double &z){ (void)R;(void)G;(void)B; x=y=z=0; }
void xyz2rgb(double x,double y,double z,double &R,double &G,double &B){ (void)x;(void)y;(void)z; R=G=B=0; }
gen symb_pnt(const gen & g,GIAC_CONTEXT){ return giac_stub_plot_unary(g,contextptr); }
gen symb_pnt(const gen & g,const gen & attributs,GIAC_CONTEXT){ (void)g;(void)attributs; return giac_stub_plot_unary(g,contextptr); }
unary_function_eval __click(0,&giac_stub_plot_unary,"click");
gen plotparam2curve(const gen & g){ return g; }
gen paramplot(const gen & g,GIAC_CONTEXT){ return giac_stub_plot_unary(g,contextptr); }
define_unary_function_ptr5(at_Graph, alias_at_Graph, STUB_PLOT_PTR, 0, 0);
define_unary_function_ptr5(at_barycentre, alias_at_barycentre, STUB_PLOT_PTR, 0, 0);
define_unary_function_ptr5(at_centre, alias_at_centre, STUB_PLOT_PTR, 0, 0);
define_unary_function_ptr5(at_cercle, alias_at_cercle, STUB_PLOT_PTR, 0, 0);
define_unary_function_ptr5(at_click, alias_at_click, STUB_PLOT_PTR, 0, 0);
define_unary_function_ptr5(at_curve, alias_at_curve, STUB_PLOT_PTR, 0, 0);
define_unary_function_ptr5(at_droite, alias_at_droite, STUB_PLOT_PTR, 0, 0);
define_unary_function_ptr5(at_plot, alias_at_plot, STUB_PLOT_PTR, 0, 0);
define_unary_function_ptr5(at_plot3d, alias_at_plot3d, STUB_PLOT_PTR, 0, 0);
define_unary_function_ptr5(at_point, alias_at_point, STUB_PLOT_PTR, 0, 0);
define_unary_function_ptr5(at_tail, alias_at_tail, STUB_PLOT_PTR, 0, 0);
define_unary_function_ptr5(at_vector, alias_at_vector, STUB_PLOT_PTR, 0, 0);
extern double global_window_xmax;
double global_window_xmax = 5.0;
extern double global_window_xmin;
double global_window_xmin = -5.0;
extern double global_window_ymax;
double global_window_ymax = 5.0;
extern double global_window_ymin;
double global_window_ymin = -5.0;
bool readrange(const gen & g,double defaultxmin,double defaultxmax,gen & x, double & xmin, double & xmax,GIAC_CONTEXT){ (void)g;(void)defaultxmin;(void)defaultxmax; x=0; xmin=xmax=0; return false; }
gen remove_at_pnt(const gen & e){ return e; }
#endif // GIAC_NO_PLOT

} // namespace giac
