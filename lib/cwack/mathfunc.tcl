package provide cwack::mathfunc 1.0

package require snit

# some statistical helpers
namespace eval ::tcl::mathfunc {

    # standardized normal mu=0 sigma=1 at z
    proc snormal {z} { expr {exp(0.5*pow($z,2))/2.50662827463} }

    # normal with specfied mu and sigma at x
    proc normal {x mu sigma} { expr {snormal((double($x)-$mu)/$sigma)} }

    # From https://en.wikipedia.org/wiki/Error_function
    # Abramowitz and Stegun approximation to the error function
    # erf(x) = 1-1/(1 + a1*x + a2*x^2 + a3*x^3 + a4*x^4)^4, x>=0
    # (maximum error: 5×10−4)
    # where a1 = 0.278393, a2 = 0.230389, a3 = 0.000972, a4 = 0.078108

    # error function
    proc erf {x} {
        expr {$x < 0 ? -erf(-$x) :
              1.0-1.0/pow(1+0.278393*$x+0.230389*pow($x,2)+0.000972*pow($x,3)+0.078108*pow($x,4), 4)}
    }

    # standardized normal cumulative distribution function: mu = 0 and sigma = 1
    proc sncdf {z} { expr {(1.0-erf($z/sqrt(2)))/2} }

    # normal cumulative distribution function with specified mu and sigma
    proc ncdf {x mu sigma} { expr {sncdf((double($x)-$mu)/$sigma)} }
}

#
# * compute running mean and var from https://www.johndcook.com/blog/standard_deviation
# *
# * Initialize M1 = x1 and S1 = 0.
# *
# * For subsequent x‘s, use the recurrence formulas
# * 
# * Mk = Mk-1+ (xk – Mk-1)/k
# * Sk = Sk-1 + (xk – Mk-1)*(xk – Mk).
# *
# * For 2 ≤ k ≤ n, the kth estimate of the variance is s2 = Sk/(k – 1).
#
snit::type rsummary {
    variable sum
    constructor {args} {
        $self clear
        $self accumulate {*}$args
    }
    method clear {} { set sum [dict create mk 0 sk 0 k 0] }
    method accumulate {args} {
        dict with sum {
            foreach xk $args {
                if {$k == 0} {
                    set k 1
                    set mk $xk
                    set sk 0
                } else {
                    incr k
                    set mj $mk
                    set sj $sk
                    set mk [expr {double($mj)+($xk-$mj)/double($k)}]
                    set sk [expr {double($sj)+double($xk-$mj)*($xk-$mk)}]
                }
            }
        }
    }
    method mean {} { dict get $sum mk }
    method var {} { dict with sum { return [expr {$k >= 2 ? $sk/($k-1) : 0}] } }
    method sd {} { expr {sqrt([$self var])} }
    method n {} { dict get $sum k }
}
