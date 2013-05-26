#
# the si570 is used in many amateur radio products
# this package defines the default parameters and
# the computations required to program the oscillator
#
package provide si570 1.0

namespace eval si570 {
    # the part number on an Si570 specifies the I2C address and the startup frequency
    # these are the ones that usually turn up in amateur radios
    set I2C_ADDR	0x55
    set STARTUP_FREQ	56.32

    # the actual crystal freq is trimmed to make the actual startup frequency correct
    set XTAL_FREQ	114.285

    # within the limits defined by this
    set XTAL_DEVIATION_PPM 2000

    # these are limits used to calculate registers
    set DCO_HIGH	5670.0
    set DCO_LOW		4850.0

    # conversion factor
    set FACTOR 268435456.0

    # divider mapping
    # this is just i+4, except that i == 4 or 6 are unimplemented
    array set HS_DIV_MAP {
	0 4
	1 5
	2 6
	3 7
	4 -1
	5 9
	6 -1
	7 11
    }
}

#
# okay, some interesting facts
# there are 548 divider values ranging from 4 to 1408
#
# divider 4 range 1212.500 1405.000 MHz, range/4 303.125 351.250, range/16 75.781 87.812
# divider 5 range 970.000 1124.000 MHz, range/4 242.500 281.000, range/16 60.625 70.250
# divider 6 range 808.333 936.667 MHz, range/4 202.083 234.167, range/16 50.521 58.542
# divider 7 range 692.857 802.857 MHz, range/4 173.214 200.714, range/16 43.304 50.179
# divider 8 range 606.250 702.500 MHz, range/4 151.562 175.625, range/16 37.891 43.906
# divider 9 range 538.889 624.444 MHz, range/4 134.722 156.111, range/16 33.681 39.028
# divider 10 range 485.000 562.000 MHz, range/4 121.250 140.500, range/16 30.312 35.125
# divider 11 range 440.909 510.909 MHz, range/4 110.227 127.727, range/16 27.557 31.932
# divider 12 range 404.167 468.333 MHz, range/4 101.042 117.083, range/16 25.260 29.271
# divider 14 range 346.429 401.429 MHz, range/4 86.607 100.357, range/16 21.652 25.089
# divider 15 range 323.333 374.667 MHz, range/4 80.833 93.667, range/16 20.208 23.417
# divider 16 range 303.125 351.250 MHz, range/4 75.781 87.812, range/16 18.945 21.953
# divider 18 range 269.444 312.222 MHz, range/4 67.361 78.055, range/16 16.840 19.514
# divider 20 range 242.500 281.000 MHz, range/4 60.625 70.250, range/16 15.156 17.562
# divider 21 range 230.952 267.619 MHz, range/4 57.738 66.905, range/16 14.434 16.726
# divider 22 range 220.455 255.455 MHz, range/4 55.114 63.864, range/16 13.778 15.966
# divider 24 range 202.083 234.167 MHz, range/4 50.521 58.542, range/16 12.630 14.635
# divider 25 range 194.000 224.800 MHz, range/4 48.500 56.200, range/16 12.125 14.050
# divider 27 range 179.630 208.148 MHz, range/4 44.907 52.037, range/16 11.227 13.009
# divider 28 range 173.214 200.714 MHz, range/4 43.303 50.178, range/16 10.826 12.545
# divider 30 range 161.667 187.333 MHz, range/4 40.417 46.833, range/16 10.104 11.708
# divider 32 range 151.562 175.625 MHz, range/4 37.891 43.906, range/16 9.473 10.977
# divider 33 range 146.970 170.303 MHz, range/4 36.742 42.576, range/16 9.186 10.644
# divider 35 range 138.571 160.571 MHz, range/4 34.643 40.143, range/16 8.661 10.036
# divider 36 range 134.722 156.111 MHz, range/4 33.681 39.028, range/16 8.420 9.757
# divider 40 range 121.250 140.500 MHz, range/4 30.312 35.125, range/16 7.578 8.781
# divider 42 range 115.476 133.810 MHz, range/4 28.869 33.453, range/16 7.217 8.363
# divider 44 range 110.227 127.727 MHz, range/4 27.557 31.932, range/16 6.889 7.983
# divider 45 range 107.778 124.889 MHz, range/4 26.945 31.222, range/16 6.736 7.806
# divider 48 range 101.042 117.083 MHz, range/4 25.261 29.271, range/16 6.315 7.318
# divider 49 range 98.980 114.694 MHz, range/4 24.745 28.674, range/16 6.186 7.168
# divider 50 range 97.000 112.400 MHz, range/4 24.250 28.100, range/16 6.062 7.025
# divider 52 range 93.269 108.077 MHz, range/4 23.317 27.019, range/16 5.829 6.755
# divider 54 range 89.815 104.074 MHz, range/4 22.454 26.018, range/16 5.613 6.505
# divider 55 range 88.182 102.182 MHz, range/4 22.046 25.546, range/16 5.511 6.386
# divider 56 range 86.607 100.357 MHz, range/4 21.652 25.089, range/16 5.413 6.272
# divider 60 range 80.833 93.667 MHz, range/4 20.208 23.417, range/16 5.052 5.854
# divider 63 range 76.984 89.206 MHz, range/4 19.246 22.302, range/16 4.811 5.575
# divider 64 range 75.781 87.812 MHz, range/4 18.945 21.953, range/16 4.736 5.488
# divider 65 range 74.615 86.462 MHz, range/4 18.654 21.616, range/16 4.663 5.404
# divider 66 range 73.485 85.152 MHz, range/4 18.371 21.288, range/16 4.593 5.322
# divider 68 range 71.324 82.647 MHz, range/4 17.831 20.662, range/16 4.458 5.165
# divider 70 range 69.286 80.286 MHz, range/4 17.322 20.072, range/16 4.330 5.018
# divider 72 range 67.361 78.056 MHz, range/4 16.840 19.514, range/16 4.210 4.878
# divider 75 range 64.667 74.933 MHz, range/4 16.167 18.733, range/16 4.042 4.683
# divider 76 range 63.816 73.947 MHz, range/4 15.954 18.487, range/16 3.989 4.622
# divider 77 range 62.987 72.987 MHz, range/4 15.747 18.247, range/16 3.937 4.562
# divider 78 range 62.179 72.051 MHz, range/4 15.545 18.013, range/16 3.886 4.503
# divider 80 range 60.625 70.250 MHz, range/4 15.156 17.562, range/16 3.789 4.391
# divider 81 range 59.877 69.383 MHz, range/4 14.969 17.346, range/16 3.742 4.336
# divider 84 range 57.738 66.905 MHz, range/4 14.434 16.726, range/16 3.609 4.182
# divider 85 range 57.059 66.118 MHz, range/4 14.265 16.529, range/16 3.566 4.132
# divider 88 range 55.114 63.864 MHz, range/4 13.778 15.966, range/16 3.445 3.991
# divider 90 range 53.889 62.444 MHz, range/4 13.472 15.611, range/16 3.368 3.903
# divider 91 range 53.297 61.758 MHz, range/4 13.324 15.440, range/16 3.331 3.860
# divider 92 range 52.717 61.087 MHz, range/4 13.179 15.272, range/16 3.295 3.818
# divider 95 range 51.053 59.158 MHz, range/4 12.763 14.790, range/16 3.191 3.697
# divider 96 range 50.521 58.542 MHz, range/4 12.630 14.636, range/16 3.158 3.659
# divider 98 range 49.490 57.347 MHz, range/4 12.373 14.337, range/16 3.093 3.584
# divider 99 range 48.990 56.768 MHz, range/4 12.248 14.192, range/16 3.062 3.548
# divider 100 range 48.500 56.200 MHz, range/4 12.125 14.050, range/16 3.031 3.513
# divider 102 range 47.549 55.098 MHz, range/4 11.887 13.774, range/16 2.972 3.444
# divider 104 range 46.635 54.038 MHz, range/4 11.659 13.509, range/16 2.915 3.377
# divider 105 range 46.190 53.524 MHz, range/4 11.547 13.381, range/16 2.887 3.345
# divider 108 range 44.907 52.037 MHz, range/4 11.227 13.009, range/16 2.807 3.252
# divider 110 range 44.091 51.091 MHz, range/4 11.023 12.773, range/16 2.756 3.193
# divider 112 range 43.304 50.179 MHz, range/4 10.826 12.545, range/16 2.707 3.136
# divider 114 range 42.544 49.298 MHz, range/4 10.636 12.325, range/16 2.659 3.081
# divider 115 range 42.174 48.870 MHz, range/4 10.543 12.217, range/16 2.636 3.054
# divider 116 range 41.810 48.448 MHz, range/4 10.453 12.112, range/16 2.613 3.028
# divider 117 range 41.453 48.034 MHz, range/4 10.363 12.008, range/16 2.591 3.002
# divider 119 range 40.756 47.227 MHz, range/4 10.189 11.807, range/16 2.547 2.952
# divider 120 range 40.417 46.833 MHz, range/4 10.104 11.708, range/16 2.526 2.927
# divider 121 range 40.083 46.446 MHz, range/4 10.021 11.611, range/16 2.505 2.903
# divider 124 range 39.113 45.323 MHz, range/4 9.778 11.331, range/16 2.445 2.833
# divider 125 range 38.800 44.960 MHz, range/4 9.700 11.240, range/16 2.425 2.810
# divider 126 range 38.492 44.603 MHz, range/4 9.623 11.151, range/16 2.406 2.788
# divider 128 range 37.891 43.906 MHz, range/4 9.473 10.976, range/16 2.368 2.744
# divider 130 range 37.308 43.231 MHz, range/4 9.327 10.808, range/16 2.332 2.702
# divider 132 range 36.742 42.576 MHz, range/4 9.185 10.644, range/16 2.296 2.661
# divider 133 range 36.466 42.256 MHz, range/4 9.117 10.564, range/16 2.279 2.641
# divider 135 range 35.926 41.630 MHz, range/4 8.982 10.408, range/16 2.245 2.602
# divider 136 range 35.662 41.324 MHz, range/4 8.915 10.331, range/16 2.229 2.583
# divider 138 range 35.145 40.725 MHz, range/4 8.786 10.181, range/16 2.197 2.545
# divider 140 range 34.643 40.143 MHz, range/4 8.661 10.036, range/16 2.165 2.509
# divider 143 range 33.916 39.301 MHz, range/4 8.479 9.825, range/16 2.120 2.456
# divider 144 range 33.681 39.028 MHz, range/4 8.420 9.757, range/16 2.105 2.439
# divider 145 range 33.448 38.759 MHz, range/4 8.362 9.690, range/16 2.091 2.422
# divider 147 range 32.993 38.231 MHz, range/4 8.248 9.558, range/16 2.062 2.389
# divider 148 range 32.770 37.973 MHz, range/4 8.193 9.493, range/16 2.048 2.373
# divider 150 range 32.333 37.467 MHz, range/4 8.083 9.367, range/16 2.021 2.342
# divider 152 range 31.908 36.974 MHz, range/4 7.977 9.243, range/16 1.994 2.311
# divider 153 range 31.699 36.732 MHz, range/4 7.925 9.183, range/16 1.981 2.296
# divider 154 range 31.494 36.494 MHz, range/4 7.873 9.123, range/16 1.968 2.281
# divider 155 range 31.290 36.258 MHz, range/4 7.822 9.065, range/16 1.956 2.266
# divider 156 range 31.090 36.026 MHz, range/4 7.772 9.007, range/16 1.943 2.252
# divider 160 range 30.312 35.125 MHz, range/4 7.578 8.781, range/16 1.895 2.195
# divider 161 range 30.124 34.907 MHz, range/4 7.531 8.727, range/16 1.883 2.182
# divider 162 range 29.938 34.691 MHz, range/4 7.484 8.673, range/16 1.871 2.168
# divider 164 range 29.573 34.268 MHz, range/4 7.393 8.567, range/16 1.848 2.142
# divider 165 range 29.394 34.061 MHz, range/4 7.348 8.515, range/16 1.837 2.129
# divider 168 range 28.869 33.452 MHz, range/4 7.217 8.363, range/16 1.804 2.091
# divider 170 range 28.529 33.059 MHz, range/4 7.132 8.265, range/16 1.783 2.066
# divider 171 range 28.363 32.865 MHz, range/4 7.091 8.216, range/16 1.773 2.054
# divider 172 range 28.198 32.674 MHz, range/4 7.050 8.168, range/16 1.762 2.042
# divider 174 range 27.874 32.299 MHz, range/4 6.968 8.075, range/16 1.742 2.019
# divider 175 range 27.714 32.114 MHz, range/4 6.928 8.028, range/16 1.732 2.007
# divider 176 range 27.557 31.932 MHz, range/4 6.889 7.983, range/16 1.722 1.996
# divider 180 range 26.944 31.222 MHz, range/4 6.736 7.806, range/16 1.684 1.951
# divider 182 range 26.648 30.879 MHz, range/4 6.662 7.720, range/16 1.665 1.930
# divider 184 range 26.359 30.543 MHz, range/4 6.590 7.636, range/16 1.647 1.909
# divider 185 range 26.216 30.378 MHz, range/4 6.554 7.595, range/16 1.639 1.899
# divider 186 range 26.075 30.215 MHz, range/4 6.519 7.554, range/16 1.630 1.888
# divider 187 range 25.936 30.053 MHz, range/4 6.484 7.513, range/16 1.621 1.878
# divider 188 range 25.798 29.894 MHz, range/4 6.449 7.473, range/16 1.612 1.868
# divider 189 range 25.661 29.735 MHz, range/4 6.415 7.434, range/16 1.604 1.858
# divider 190 range 25.526 29.579 MHz, range/4 6.381 7.395, range/16 1.595 1.849
# divider 192 range 25.260 29.271 MHz, range/4 6.315 7.318, range/16 1.579 1.829
# divider 195 range 24.872 28.821 MHz, range/4 6.218 7.205, range/16 1.554 1.801
# divider 196 range 24.745 28.673 MHz, range/4 6.186 7.168, range/16 1.547 1.792
# divider 198 range 24.495 28.384 MHz, range/4 6.124 7.096, range/16 1.531 1.774
# divider 200 range 24.250 28.100 MHz, range/4 6.062 7.025, range/16 1.516 1.756
# divider 203 range 23.892 27.685 MHz, range/4 5.973 6.921, range/16 1.493 1.730
# divider 204 range 23.775 27.549 MHz, range/4 5.944 6.887, range/16 1.486 1.722
# divider 205 range 23.659 27.415 MHz, range/4 5.915 6.854, range/16 1.479 1.713
# divider 207 range 23.430 27.150 MHz, range/4 5.857 6.787, range/16 1.464 1.697
# divider 208 range 23.317 27.019 MHz, range/4 5.829 6.755, range/16 1.457 1.689
# divider 209 range 23.206 26.890 MHz, range/4 5.801 6.723, range/16 1.450 1.681
# divider 210 range 23.095 26.762 MHz, range/4 5.774 6.691, range/16 1.443 1.673
# divider 212 range 22.877 26.509 MHz, range/4 5.719 6.627, range/16 1.430 1.657
# divider 215 range 22.558 26.140 MHz, range/4 5.639 6.535, range/16 1.410 1.634
# divider 216 range 22.454 26.019 MHz, range/4 5.614 6.505, range/16 1.403 1.626
# divider 217 range 22.350 25.899 MHz, range/4 5.588 6.475, range/16 1.397 1.619
# divider 220 range 22.045 25.545 MHz, range/4 5.511 6.386, range/16 1.378 1.597
# divider 222 range 21.847 25.315 MHz, range/4 5.462 6.329, range/16 1.365 1.582
# divider 224 range 21.652 25.089 MHz, range/4 5.413 6.272, range/16 1.353 1.568
# divider 225 range 21.556 24.978 MHz, range/4 5.389 6.245, range/16 1.347 1.561
# divider 228 range 21.272 24.649 MHz, range/4 5.318 6.162, range/16 1.329 1.541
# divider 230 range 21.087 24.435 MHz, range/4 5.272 6.109, range/16 1.318 1.527
# divider 231 range 20.996 24.329 MHz, range/4 5.249 6.082, range/16 1.312 1.521
# divider 232 range 20.905 24.224 MHz, range/4 5.226 6.056, range/16 1.307 1.514
# divider 234 range 20.726 24.017 MHz, range/4 5.181 6.004, range/16 1.295 1.501
# divider 235 range 20.638 23.915 MHz, range/4 5.160 5.979, range/16 1.290 1.495
# divider 236 range 20.551 23.814 MHz, range/4 5.138 5.954, range/16 1.284 1.488
# divider 238 range 20.378 23.613 MHz, range/4 5.095 5.903, range/16 1.274 1.476
# divider 240 range 20.208 23.417 MHz, range/4 5.052 5.854, range/16 1.263 1.464
# divider 242 range 20.041 23.223 MHz, range/4 5.010 5.806, range/16 1.253 1.451
# divider 243 range 19.959 23.128 MHz, range/4 4.990 5.782, range/16 1.247 1.446
# divider 244 range 19.877 23.033 MHz, range/4 4.969 5.758, range/16 1.242 1.440
# divider 245 range 19.796 22.939 MHz, range/4 4.949 5.735, range/16 1.237 1.434
# divider 246 range 19.715 22.846 MHz, range/4 4.929 5.712, range/16 1.232 1.428
# divider 248 range 19.556 22.661 MHz, range/4 4.889 5.665, range/16 1.222 1.416
# divider 250 range 19.400 22.480 MHz, range/4 4.850 5.620, range/16 1.212 1.405
# divider 252 range 19.246 22.302 MHz, range/4 4.811 5.575, range/16 1.203 1.394
# divider 253 range 19.170 22.213 MHz, range/4 4.793 5.553, range/16 1.198 1.388
# divider 255 range 19.020 22.039 MHz, range/4 4.755 5.510, range/16 1.189 1.377
# divider 256 range 18.945 21.953 MHz, range/4 4.736 5.488, range/16 1.184 1.372
# divider 258 range 18.798 21.783 MHz, range/4 4.699 5.446, range/16 1.175 1.361
# divider 259 range 18.726 21.699 MHz, range/4 4.681 5.425, range/16 1.170 1.356
# divider 260 range 18.654 21.615 MHz, range/4 4.663 5.404, range/16 1.166 1.351
# divider 261 range 18.582 21.533 MHz, range/4 4.646 5.383, range/16 1.161 1.346
# divider 264 range 18.371 21.288 MHz, range/4 4.593 5.322, range/16 1.148 1.331
# divider 265 range 18.302 21.208 MHz, range/4 4.575 5.302, range/16 1.144 1.325
# divider 266 range 18.233 21.128 MHz, range/4 4.558 5.282, range/16 1.140 1.321
# divider 268 range 18.097 20.970 MHz, range/4 4.524 5.242, range/16 1.131 1.311
# divider 270 range 17.963 20.815 MHz, range/4 4.491 5.204, range/16 1.123 1.301
# divider 272 range 17.831 20.662 MHz, range/4 4.458 5.165, range/16 1.114 1.291
# divider 273 range 17.766 20.586 MHz, range/4 4.441 5.146, range/16 1.110 1.287
# divider 275 range 17.636 20.436 MHz, range/4 4.409 5.109, range/16 1.102 1.277
# divider 276 range 17.572 20.362 MHz, range/4 4.393 5.090, range/16 1.098 1.273
# divider 279 range 17.384 20.143 MHz, range/4 4.346 5.036, range/16 1.087 1.259
# divider 280 range 17.321 20.071 MHz, range/4 4.330 5.018, range/16 1.083 1.254
# divider 282 range 17.199 19.929 MHz, range/4 4.300 4.982, range/16 1.075 1.246
# divider 284 range 17.077 19.789 MHz, range/4 4.269 4.947, range/16 1.067 1.237
# divider 285 range 17.018 19.719 MHz, range/4 4.255 4.930, range/16 1.064 1.232
# divider 286 range 16.958 19.650 MHz, range/4 4.239 4.912, range/16 1.060 1.228
# divider 287 range 16.899 19.582 MHz, range/4 4.225 4.896, range/16 1.056 1.224
# divider 288 range 16.840 19.514 MHz, range/4 4.210 4.878, range/16 1.052 1.220
# divider 290 range 16.724 19.379 MHz, range/4 4.181 4.845, range/16 1.045 1.211
# divider 292 range 16.610 19.247 MHz, range/4 4.152 4.812, range/16 1.038 1.203
# divider 294 range 16.497 19.116 MHz, range/4 4.124 4.779, range/16 1.031 1.195
# divider 295 range 16.441 19.051 MHz, range/4 4.110 4.763, range/16 1.028 1.191
# divider 296 range 16.385 18.986 MHz, range/4 4.096 4.747, range/16 1.024 1.187
# divider 297 range 16.330 18.923 MHz, range/4 4.082 4.731, range/16 1.021 1.183
# divider 300 range 16.167 18.733 MHz, range/4 4.042 4.683, range/16 1.010 1.171
# divider 301 range 16.113 18.671 MHz, range/4 4.028 4.668, range/16 1.007 1.167
# divider 304 range 15.954 18.487 MHz, range/4 3.989 4.622, range/16 0.997 1.155
# divider 305 range 15.902 18.426 MHz, range/4 3.975 4.606, range/16 0.994 1.152
# divider 306 range 15.850 18.366 MHz, range/4 3.962 4.591, range/16 0.991 1.148
# divider 308 range 15.747 18.247 MHz, range/4 3.937 4.562, range/16 0.984 1.140
# divider 310 range 15.645 18.129 MHz, range/4 3.911 4.532, range/16 0.978 1.133
# divider 312 range 15.545 18.013 MHz, range/4 3.886 4.503, range/16 0.972 1.126
# divider 315 range 15.397 17.841 MHz, range/4 3.849 4.460, range/16 0.962 1.115
# divider 316 range 15.348 17.785 MHz, range/4 3.837 4.446, range/16 0.959 1.112
# divider 318 range 15.252 17.673 MHz, range/4 3.813 4.418, range/16 0.953 1.105
# divider 319 range 15.204 17.618 MHz, range/4 3.801 4.404, range/16 0.950 1.101
# divider 320 range 15.156 17.562 MHz, range/4 3.789 4.391, range/16 0.947 1.098
# divider 322 range 15.062 17.453 MHz, range/4 3.765 4.363, range/16 0.941 1.091
# divider 324 range 14.969 17.346 MHz, range/4 3.742 4.337, range/16 0.936 1.084
# divider 325 range 14.923 17.292 MHz, range/4 3.731 4.323, range/16 0.933 1.081
# divider 328 range 14.787 17.134 MHz, range/4 3.697 4.284, range/16 0.924 1.071
# divider 329 range 14.742 17.082 MHz, range/4 3.686 4.271, range/16 0.921 1.068
# divider 330 range 14.697 17.030 MHz, range/4 3.674 4.258, range/16 0.919 1.064
# divider 332 range 14.608 16.928 MHz, range/4 3.652 4.232, range/16 0.913 1.058
# divider 333 range 14.565 16.877 MHz, range/4 3.641 4.219, range/16 0.910 1.055
# divider 335 range 14.478 16.776 MHz, range/4 3.619 4.194, range/16 0.905 1.048
# divider 336 range 14.435 16.726 MHz, range/4 3.609 4.181, range/16 0.902 1.045
# divider 340 range 14.265 16.529 MHz, range/4 3.566 4.132, range/16 0.892 1.033
# divider 341 range 14.223 16.481 MHz, range/4 3.556 4.120, range/16 0.889 1.030
# divider 342 range 14.181 16.433 MHz, range/4 3.545 4.108, range/16 0.886 1.027
# divider 343 range 14.140 16.385 MHz, range/4 3.535 4.096, range/16 0.884 1.024
# divider 344 range 14.099 16.337 MHz, range/4 3.525 4.084, range/16 0.881 1.021
# divider 345 range 14.058 16.290 MHz, range/4 3.514 4.072, range/16 0.879 1.018
# divider 348 range 13.937 16.149 MHz, range/4 3.484 4.037, range/16 0.871 1.009
# divider 350 range 13.857 16.057 MHz, range/4 3.464 4.014, range/16 0.866 1.004
# divider 351 range 13.818 16.011 MHz, range/4 3.454 4.003, range/16 0.864 1.001
# divider 352 range 13.778 15.966 MHz, range/4 3.445 3.991, range/16 0.861 0.998
# divider 354 range 13.701 15.876 MHz, range/4 3.425 3.969, range/16 0.856 0.992
# divider 355 range 13.662 15.831 MHz, range/4 3.416 3.958, range/16 0.854 0.989
# divider 356 range 13.624 15.787 MHz, range/4 3.406 3.947, range/16 0.852 0.987
# divider 357 range 13.585 15.742 MHz, range/4 3.396 3.936, range/16 0.849 0.984
# divider 360 range 13.472 15.611 MHz, range/4 3.368 3.903, range/16 0.842 0.976
# divider 363 range 13.361 15.482 MHz, range/4 3.340 3.870, range/16 0.835 0.968
# divider 364 range 13.324 15.440 MHz, range/4 3.331 3.860, range/16 0.833 0.965
# divider 365 range 13.288 15.397 MHz, range/4 3.322 3.849, range/16 0.831 0.962
# divider 366 range 13.251 15.355 MHz, range/4 3.313 3.839, range/16 0.828 0.960
# divider 368 range 13.179 15.272 MHz, range/4 3.295 3.818, range/16 0.824 0.955
# divider 369 range 13.144 15.230 MHz, range/4 3.286 3.808, range/16 0.822 0.952
# divider 370 range 13.108 15.189 MHz, range/4 3.277 3.797, range/16 0.819 0.949
# divider 371 range 13.073 15.148 MHz, range/4 3.268 3.787, range/16 0.817 0.947
# divider 372 range 13.038 15.108 MHz, range/4 3.260 3.777, range/16 0.815 0.944
# divider 374 range 12.968 15.027 MHz, range/4 3.242 3.757, range/16 0.810 0.939
# divider 375 range 12.933 14.987 MHz, range/4 3.233 3.747, range/16 0.808 0.937
# divider 376 range 12.899 14.947 MHz, range/4 3.225 3.737, range/16 0.806 0.934
# divider 378 range 12.831 14.868 MHz, range/4 3.208 3.717, range/16 0.802 0.929
# divider 380 range 12.763 14.789 MHz, range/4 3.191 3.697, range/16 0.798 0.924
# divider 384 range 12.630 14.635 MHz, range/4 3.158 3.659, range/16 0.789 0.915
# divider 385 range 12.597 14.597 MHz, range/4 3.149 3.649, range/16 0.787 0.912
# divider 387 range 12.532 14.522 MHz, range/4 3.133 3.631, range/16 0.783 0.908
# divider 388 range 12.500 14.485 MHz, range/4 3.125 3.621, range/16 0.781 0.905
# divider 390 range 12.436 14.410 MHz, range/4 3.109 3.603, range/16 0.777 0.901
# divider 392 range 12.372 14.337 MHz, range/4 3.093 3.584, range/16 0.773 0.896
# divider 395 range 12.278 14.228 MHz, range/4 3.070 3.557, range/16 0.767 0.889
# divider 396 range 12.247 14.192 MHz, range/4 3.062 3.548, range/16 0.765 0.887
# divider 399 range 12.155 14.085 MHz, range/4 3.039 3.521, range/16 0.760 0.880
# divider 400 range 12.125 14.050 MHz, range/4 3.031 3.513, range/16 0.758 0.878
# divider 402 range 12.065 13.980 MHz, range/4 3.016 3.495, range/16 0.754 0.874
# divider 404 range 12.005 13.911 MHz, range/4 3.001 3.478, range/16 0.750 0.869
# divider 405 range 11.975 13.877 MHz, range/4 2.994 3.469, range/16 0.748 0.867
# divider 406 range 11.946 13.842 MHz, range/4 2.986 3.461, range/16 0.747 0.865
# divider 407 range 11.916 13.808 MHz, range/4 2.979 3.452, range/16 0.745 0.863
# divider 408 range 11.887 13.775 MHz, range/4 2.972 3.444, range/16 0.743 0.861
# divider 410 range 11.829 13.707 MHz, range/4 2.957 3.427, range/16 0.739 0.857
# divider 412 range 11.772 13.641 MHz, range/4 2.943 3.410, range/16 0.736 0.853
# divider 413 range 11.743 13.608 MHz, range/4 2.936 3.402, range/16 0.734 0.851
# divider 414 range 11.715 13.575 MHz, range/4 2.929 3.394, range/16 0.732 0.848
# divider 415 range 11.687 13.542 MHz, range/4 2.922 3.385, range/16 0.730 0.846
# divider 416 range 11.659 13.510 MHz, range/4 2.915 3.377, range/16 0.729 0.844
# divider 418 range 11.603 13.445 MHz, range/4 2.901 3.361, range/16 0.725 0.840
# divider 420 range 11.548 13.381 MHz, range/4 2.887 3.345, range/16 0.722 0.836
# divider 423 range 11.466 13.286 MHz, range/4 2.866 3.321, range/16 0.717 0.830
# divider 424 range 11.439 13.255 MHz, range/4 2.860 3.314, range/16 0.715 0.828
# divider 425 range 11.412 13.224 MHz, range/4 2.853 3.306, range/16 0.713 0.827
# divider 426 range 11.385 13.192 MHz, range/4 2.846 3.298, range/16 0.712 0.825
# divider 427 range 11.358 13.162 MHz, range/4 2.840 3.291, range/16 0.710 0.823
# divider 428 range 11.332 13.131 MHz, range/4 2.833 3.283, range/16 0.708 0.821
# divider 429 range 11.305 13.100 MHz, range/4 2.826 3.275, range/16 0.707 0.819
# divider 430 range 11.279 13.070 MHz, range/4 2.820 3.268, range/16 0.705 0.817
# divider 432 range 11.227 13.009 MHz, range/4 2.807 3.252, range/16 0.702 0.813
# divider 434 range 11.175 12.949 MHz, range/4 2.794 3.237, range/16 0.698 0.809
# divider 435 range 11.149 12.920 MHz, range/4 2.787 3.230, range/16 0.697 0.807
# divider 436 range 11.124 12.890 MHz, range/4 2.781 3.223, range/16 0.695 0.806
# divider 438 range 11.073 12.831 MHz, range/4 2.768 3.208, range/16 0.692 0.802
# divider 440 range 11.023 12.773 MHz, range/4 2.756 3.193, range/16 0.689 0.798
# divider 441 range 10.998 12.744 MHz, range/4 2.749 3.186, range/16 0.687 0.796
# divider 444 range 10.923 12.658 MHz, range/4 2.731 3.164, range/16 0.683 0.791
# divider 445 range 10.899 12.629 MHz, range/4 2.725 3.157, range/16 0.681 0.789
# divider 448 range 10.826 12.545 MHz, range/4 2.707 3.136, range/16 0.677 0.784
# divider 450 range 10.778 12.489 MHz, range/4 2.695 3.122, range/16 0.674 0.781
# divider 451 range 10.754 12.461 MHz, range/4 2.688 3.115, range/16 0.672 0.779
# divider 452 range 10.730 12.434 MHz, range/4 2.683 3.108, range/16 0.671 0.777
# divider 455 range 10.659 12.352 MHz, range/4 2.665 3.088, range/16 0.666 0.772
# divider 456 range 10.636 12.325 MHz, range/4 2.659 3.081, range/16 0.665 0.770
# divider 459 range 10.566 12.244 MHz, range/4 2.642 3.061, range/16 0.660 0.765
# divider 460 range 10.543 12.217 MHz, range/4 2.636 3.054, range/16 0.659 0.764
# divider 462 range 10.498 12.165 MHz, range/4 2.624 3.041, range/16 0.656 0.760
# divider 464 range 10.453 12.112 MHz, range/4 2.613 3.028, range/16 0.653 0.757
# divider 465 range 10.430 12.086 MHz, range/4 2.607 3.022, range/16 0.652 0.755
# divider 468 range 10.363 12.009 MHz, range/4 2.591 3.002, range/16 0.648 0.751
# divider 469 range 10.341 11.983 MHz, range/4 2.585 2.996, range/16 0.646 0.749
# divider 470 range 10.319 11.957 MHz, range/4 2.580 2.989, range/16 0.645 0.747
# divider 472 range 10.275 11.907 MHz, range/4 2.569 2.977, range/16 0.642 0.744
# divider 473 range 10.254 11.882 MHz, range/4 2.563 2.970, range/16 0.641 0.743
# divider 474 range 10.232 11.857 MHz, range/4 2.558 2.964, range/16 0.639 0.741
# divider 475 range 10.211 11.832 MHz, range/4 2.553 2.958, range/16 0.638 0.740
# divider 476 range 10.189 11.807 MHz, range/4 2.547 2.952, range/16 0.637 0.738
# divider 477 range 10.168 11.782 MHz, range/4 2.542 2.946, range/16 0.635 0.736
# divider 480 range 10.104 11.708 MHz, range/4 2.526 2.927, range/16 0.631 0.732
# divider 483 range 10.041 11.636 MHz, range/4 2.510 2.909, range/16 0.628 0.727
# divider 484 range 10.021 11.612 MHz, range/4 2.505 2.903, range/16 0.626 0.726
# divider 485 range 10.000 11.588 MHz, range/4 2.500 2.897, range/16 0.625 0.724
# divider 486 range 9.979 11.564 MHz, range/4 2.495 2.891, range/16 0.624 0.723
# divider 488 range 9.939 11.516 MHz, range/4 2.485 2.879, range/16 0.621 0.720
# divider 490 range 9.898 11.469 MHz, range/4 2.474 2.867, range/16 0.619 0.717
# divider 492 range 9.858 11.423 MHz, range/4 2.465 2.856, range/16 0.616 0.714
# divider 495 range 9.798 11.354 MHz, range/4 2.450 2.838, range/16 0.612 0.710
# divider 496 range 9.778 11.331 MHz, range/4 2.445 2.833, range/16 0.611 0.708
# divider 497 range 9.759 11.308 MHz, range/4 2.440 2.827, range/16 0.610 0.707
# divider 498 range 9.739 11.285 MHz, range/4 2.435 2.821, range/16 0.609 0.705
# divider 500 range 9.700 11.240 MHz, range/4 2.425 2.810, range/16 0.606 0.703
# divider 504 range 9.623 11.151 MHz, range/4 2.406 2.788, range/16 0.601 0.697
# divider 505 range 9.604 11.129 MHz, range/4 2.401 2.782, range/16 0.600 0.696
# divider 506 range 9.585 11.107 MHz, range/4 2.396 2.777, range/16 0.599 0.694
# divider 508 range 9.547 11.063 MHz, range/4 2.387 2.766, range/16 0.597 0.691
# divider 510 range 9.510 11.020 MHz, range/4 2.377 2.755, range/16 0.594 0.689
# divider 511 range 9.491 10.998 MHz, range/4 2.373 2.749, range/16 0.593 0.687
# divider 512 range 9.473 10.977 MHz, range/4 2.368 2.744, range/16 0.592 0.686
# divider 513 range 9.454 10.955 MHz, range/4 2.364 2.739, range/16 0.591 0.685
# divider 515 range 9.417 10.913 MHz, range/4 2.354 2.728, range/16 0.589 0.682
# divider 516 range 9.399 10.891 MHz, range/4 2.350 2.723, range/16 0.587 0.681
# divider 517 range 9.381 10.870 MHz, range/4 2.345 2.717, range/16 0.586 0.679
# divider 518 range 9.363 10.849 MHz, range/4 2.341 2.712, range/16 0.585 0.678
# divider 520 range 9.327 10.808 MHz, range/4 2.332 2.702, range/16 0.583 0.675
# divider 522 range 9.291 10.766 MHz, range/4 2.323 2.692, range/16 0.581 0.673
# divider 525 range 9.238 10.705 MHz, range/4 2.309 2.676, range/16 0.577 0.669
# divider 528 range 9.186 10.644 MHz, range/4 2.296 2.661, range/16 0.574 0.665
# divider 530 range 9.151 10.604 MHz, range/4 2.288 2.651, range/16 0.572 0.663
# divider 531 range 9.134 10.584 MHz, range/4 2.284 2.646, range/16 0.571 0.661
# divider 532 range 9.117 10.564 MHz, range/4 2.279 2.641, range/16 0.570 0.660
# divider 534 range 9.082 10.524 MHz, range/4 2.271 2.631, range/16 0.568 0.658
# divider 535 range 9.065 10.505 MHz, range/4 2.266 2.626, range/16 0.567 0.657
# divider 539 range 8.998 10.427 MHz, range/4 2.249 2.607, range/16 0.562 0.652
# divider 540 range 8.981 10.407 MHz, range/4 2.245 2.602, range/16 0.561 0.650
# divider 545 range 8.899 10.312 MHz, range/4 2.225 2.578, range/16 0.556 0.644
# divider 546 range 8.883 10.293 MHz, range/4 2.221 2.573, range/16 0.555 0.643
# divider 549 range 8.834 10.237 MHz, range/4 2.208 2.559, range/16 0.552 0.640
# divider 550 range 8.818 10.218 MHz, range/4 2.204 2.554, range/16 0.551 0.639
# divider 552 range 8.786 10.181 MHz, range/4 2.196 2.545, range/16 0.549 0.636
# divider 553 range 8.770 10.163 MHz, range/4 2.192 2.541, range/16 0.548 0.635
# divider 555 range 8.739 10.126 MHz, range/4 2.185 2.531, range/16 0.546 0.633
# divider 558 range 8.692 10.072 MHz, range/4 2.173 2.518, range/16 0.543 0.629
# divider 560 range 8.661 10.036 MHz, range/4 2.165 2.509, range/16 0.541 0.627
# divider 561 range 8.645 10.018 MHz, range/4 2.161 2.505, range/16 0.540 0.626
# divider 564 range 8.599 9.965 MHz, range/4 2.150 2.491, range/16 0.537 0.623
# divider 565 range 8.584 9.947 MHz, range/4 2.146 2.487, range/16 0.536 0.622
# divider 567 range 8.554 9.912 MHz, range/4 2.139 2.478, range/16 0.535 0.620
# divider 570 range 8.509 9.860 MHz, range/4 2.127 2.465, range/16 0.532 0.616
# divider 572 range 8.479 9.825 MHz, range/4 2.120 2.456, range/16 0.530 0.614
# divider 574 range 8.449 9.791 MHz, range/4 2.112 2.448, range/16 0.528 0.612
# divider 575 range 8.435 9.774 MHz, range/4 2.109 2.443, range/16 0.527 0.611
# divider 576 range 8.420 9.757 MHz, range/4 2.105 2.439, range/16 0.526 0.610
# divider 580 range 8.362 9.690 MHz, range/4 2.091 2.422, range/16 0.523 0.606
# divider 581 range 8.348 9.673 MHz, range/4 2.087 2.418, range/16 0.522 0.605
# divider 582 range 8.333 9.656 MHz, range/4 2.083 2.414, range/16 0.521 0.604
# divider 583 range 8.319 9.640 MHz, range/4 2.080 2.410, range/16 0.520 0.603
# divider 585 range 8.291 9.607 MHz, range/4 2.073 2.402, range/16 0.518 0.600
# divider 588 range 8.248 9.558 MHz, range/4 2.062 2.389, range/16 0.515 0.597
# divider 590 range 8.220 9.525 MHz, range/4 2.055 2.381, range/16 0.514 0.595
# divider 594 range 8.165 9.461 MHz, range/4 2.041 2.365, range/16 0.510 0.591
# divider 595 range 8.151 9.445 MHz, range/4 2.038 2.361, range/16 0.509 0.590
# divider 600 range 8.083 9.367 MHz, range/4 2.021 2.342, range/16 0.505 0.585
# divider 602 range 8.056 9.336 MHz, range/4 2.014 2.334, range/16 0.503 0.584
# divider 603 range 8.043 9.320 MHz, range/4 2.011 2.330, range/16 0.503 0.583
# divider 605 range 8.017 9.289 MHz, range/4 2.004 2.322, range/16 0.501 0.581
# divider 606 range 8.003 9.274 MHz, range/4 2.001 2.318, range/16 0.500 0.580
# divider 609 range 7.964 9.228 MHz, range/4 1.991 2.307, range/16 0.498 0.577
# divider 610 range 7.951 9.213 MHz, range/4 1.988 2.303, range/16 0.497 0.576
# divider 612 range 7.925 9.183 MHz, range/4 1.981 2.296, range/16 0.495 0.574
# divider 615 range 7.886 9.138 MHz, range/4 1.972 2.284, range/16 0.493 0.571
# divider 616 range 7.873 9.123 MHz, range/4 1.968 2.281, range/16 0.492 0.570
# divider 618 range 7.848 9.094 MHz, range/4 1.962 2.273, range/16 0.490 0.568
# divider 620 range 7.823 9.065 MHz, range/4 1.956 2.266, range/16 0.489 0.567
# divider 621 range 7.810 9.050 MHz, range/4 1.952 2.263, range/16 0.488 0.566
# divider 623 range 7.785 9.021 MHz, range/4 1.946 2.255, range/16 0.487 0.564
# divider 624 range 7.772 9.006 MHz, range/4 1.943 2.252, range/16 0.486 0.563
# divider 625 range 7.760 8.992 MHz, range/4 1.940 2.248, range/16 0.485 0.562
# divider 627 range 7.735 8.963 MHz, range/4 1.934 2.241, range/16 0.483 0.560
# divider 630 range 7.698 8.921 MHz, range/4 1.925 2.230, range/16 0.481 0.558
# divider 635 range 7.638 8.850 MHz, range/4 1.909 2.212, range/16 0.477 0.553
# divider 636 range 7.626 8.836 MHz, range/4 1.907 2.209, range/16 0.477 0.552
# divider 637 range 7.614 8.823 MHz, range/4 1.903 2.206, range/16 0.476 0.551
# divider 638 range 7.602 8.809 MHz, range/4 1.901 2.202, range/16 0.475 0.551
# divider 639 range 7.590 8.795 MHz, range/4 1.897 2.199, range/16 0.474 0.550
# divider 640 range 7.578 8.781 MHz, range/4 1.895 2.195, range/16 0.474 0.549
# divider 642 range 7.555 8.754 MHz, range/4 1.889 2.188, range/16 0.472 0.547
# divider 644 range 7.531 8.727 MHz, range/4 1.883 2.182, range/16 0.471 0.545
# divider 648 range 7.485 8.673 MHz, range/4 1.871 2.168, range/16 0.468 0.542
# divider 649 range 7.473 8.659 MHz, range/4 1.868 2.165, range/16 0.467 0.541
# divider 651 range 7.450 8.633 MHz, range/4 1.863 2.158, range/16 0.466 0.540
# divider 654 range 7.416 8.593 MHz, range/4 1.854 2.148, range/16 0.464 0.537
# divider 657 range 7.382 8.554 MHz, range/4 1.845 2.139, range/16 0.461 0.535
# divider 658 range 7.371 8.541 MHz, range/4 1.843 2.135, range/16 0.461 0.534
# divider 660 range 7.348 8.515 MHz, range/4 1.837 2.129, range/16 0.459 0.532
# divider 665 range 7.293 8.451 MHz, range/4 1.823 2.113, range/16 0.456 0.528
# divider 666 range 7.282 8.438 MHz, range/4 1.821 2.110, range/16 0.455 0.527
# divider 671 range 7.228 8.376 MHz, range/4 1.807 2.094, range/16 0.452 0.523
# divider 672 range 7.217 8.363 MHz, range/4 1.804 2.091, range/16 0.451 0.523
# divider 675 range 7.185 8.326 MHz, range/4 1.796 2.082, range/16 0.449 0.520
# divider 678 range 7.153 8.289 MHz, range/4 1.788 2.072, range/16 0.447 0.518
# divider 679 range 7.143 8.277 MHz, range/4 1.786 2.069, range/16 0.446 0.517
# divider 682 range 7.111 8.240 MHz, range/4 1.778 2.060, range/16 0.444 0.515
# divider 684 range 7.091 8.216 MHz, range/4 1.773 2.054, range/16 0.443 0.513
# divider 686 range 7.070 8.192 MHz, range/4 1.768 2.048, range/16 0.442 0.512
# divider 690 range 7.029 8.145 MHz, range/4 1.757 2.036, range/16 0.439 0.509
# divider 693 range 6.999 8.110 MHz, range/4 1.750 2.027, range/16 0.437 0.507
# divider 696 range 6.968 8.075 MHz, range/4 1.742 2.019, range/16 0.435 0.505
# divider 700 range 6.929 8.029 MHz, range/4 1.732 2.007, range/16 0.433 0.502
# divider 702 range 6.909 8.006 MHz, range/4 1.727 2.002, range/16 0.432 0.500
# divider 704 range 6.889 7.983 MHz, range/4 1.722 1.996, range/16 0.431 0.499
# divider 707 range 6.860 7.949 MHz, range/4 1.715 1.987, range/16 0.429 0.497
# divider 708 range 6.850 7.938 MHz, range/4 1.712 1.984, range/16 0.428 0.496
# divider 711 range 6.821 7.904 MHz, range/4 1.705 1.976, range/16 0.426 0.494
# divider 714 range 6.793 7.871 MHz, range/4 1.698 1.968, range/16 0.425 0.492
# divider 715 range 6.783 7.860 MHz, range/4 1.696 1.965, range/16 0.424 0.491
# divider 720 range 6.736 7.806 MHz, range/4 1.684 1.952, range/16 0.421 0.488
# divider 721 range 6.727 7.795 MHz, range/4 1.682 1.949, range/16 0.420 0.487
# divider 726 range 6.680 7.741 MHz, range/4 1.670 1.935, range/16 0.417 0.484
# divider 728 range 6.662 7.720 MHz, range/4 1.665 1.930, range/16 0.416 0.482
# divider 729 range 6.653 7.709 MHz, range/4 1.663 1.927, range/16 0.416 0.482
# divider 732 range 6.626 7.678 MHz, range/4 1.657 1.919, range/16 0.414 0.480
# divider 735 range 6.599 7.646 MHz, range/4 1.650 1.911, range/16 0.412 0.478
# divider 737 range 6.581 7.626 MHz, range/4 1.645 1.907, range/16 0.411 0.477
# divider 738 range 6.572 7.615 MHz, range/4 1.643 1.904, range/16 0.411 0.476
# divider 742 range 6.536 7.574 MHz, range/4 1.634 1.893, range/16 0.408 0.473
# divider 744 range 6.519 7.554 MHz, range/4 1.630 1.889, range/16 0.407 0.472
# divider 747 range 6.493 7.523 MHz, range/4 1.623 1.881, range/16 0.406 0.470
# divider 748 range 6.484 7.513 MHz, range/4 1.621 1.878, range/16 0.405 0.470
# divider 749 range 6.475 7.503 MHz, range/4 1.619 1.876, range/16 0.405 0.469
# divider 750 range 6.467 7.493 MHz, range/4 1.617 1.873, range/16 0.404 0.468
# divider 756 range 6.415 7.434 MHz, range/4 1.604 1.859, range/16 0.401 0.465
# divider 759 range 6.390 7.404 MHz, range/4 1.597 1.851, range/16 0.399 0.463
# divider 762 range 6.365 7.375 MHz, range/4 1.591 1.844, range/16 0.398 0.461
# divider 763 range 6.356 7.366 MHz, range/4 1.589 1.841, range/16 0.397 0.460
# divider 765 range 6.340 7.346 MHz, range/4 1.585 1.837, range/16 0.396 0.459
# divider 768 range 6.315 7.318 MHz, range/4 1.579 1.829, range/16 0.395 0.457
# divider 770 range 6.299 7.299 MHz, range/4 1.575 1.825, range/16 0.394 0.456
# divider 774 range 6.266 7.261 MHz, range/4 1.567 1.815, range/16 0.392 0.454
# divider 777 range 6.242 7.233 MHz, range/4 1.560 1.808, range/16 0.390 0.452
# divider 781 range 6.210 7.196 MHz, range/4 1.552 1.799, range/16 0.388 0.450
# divider 783 range 6.194 7.178 MHz, range/4 1.548 1.794, range/16 0.387 0.449
# divider 784 range 6.186 7.168 MHz, range/4 1.546 1.792, range/16 0.387 0.448
# divider 791 range 6.131 7.105 MHz, range/4 1.533 1.776, range/16 0.383 0.444
# divider 792 range 6.124 7.096 MHz, range/4 1.531 1.774, range/16 0.383 0.444
# divider 798 range 6.078 7.043 MHz, range/4 1.520 1.761, range/16 0.380 0.440
# divider 801 range 6.055 7.016 MHz, range/4 1.514 1.754, range/16 0.378 0.439
# divider 803 range 6.040 6.999 MHz, range/4 1.510 1.750, range/16 0.378 0.437
# divider 805 range 6.025 6.981 MHz, range/4 1.506 1.745, range/16 0.377 0.436
# divider 810 range 5.988 6.938 MHz, range/4 1.497 1.734, range/16 0.374 0.434
# divider 812 range 5.973 6.921 MHz, range/4 1.493 1.730, range/16 0.373 0.433
# divider 814 range 5.958 6.904 MHz, range/4 1.490 1.726, range/16 0.372 0.431
# divider 819 range 5.922 6.862 MHz, range/4 1.480 1.716, range/16 0.370 0.429
# divider 825 range 5.879 6.812 MHz, range/4 1.470 1.703, range/16 0.367 0.426
# divider 826 range 5.872 6.804 MHz, range/4 1.468 1.701, range/16 0.367 0.425
# divider 828 range 5.857 6.787 MHz, range/4 1.464 1.697, range/16 0.366 0.424
# divider 833 range 5.822 6.747 MHz, range/4 1.456 1.687, range/16 0.364 0.422
# divider 836 range 5.801 6.722 MHz, range/4 1.450 1.681, range/16 0.363 0.420
# divider 837 range 5.795 6.714 MHz, range/4 1.449 1.679, range/16 0.362 0.420
# divider 840 range 5.774 6.690 MHz, range/4 1.444 1.673, range/16 0.361 0.418
# divider 846 range 5.733 6.643 MHz, range/4 1.433 1.661, range/16 0.358 0.415
# divider 847 range 5.726 6.635 MHz, range/4 1.431 1.659, range/16 0.358 0.415
# divider 854 range 5.679 6.581 MHz, range/4 1.420 1.645, range/16 0.355 0.411
# divider 855 range 5.673 6.573 MHz, range/4 1.418 1.643, range/16 0.355 0.411
# divider 858 range 5.653 6.550 MHz, range/4 1.413 1.637, range/16 0.353 0.409
# divider 861 range 5.633 6.527 MHz, range/4 1.408 1.632, range/16 0.352 0.408
# divider 864 range 5.613 6.505 MHz, range/4 1.403 1.626, range/16 0.351 0.407
# divider 868 range 5.588 6.475 MHz, range/4 1.397 1.619, range/16 0.349 0.405
# divider 869 range 5.581 6.467 MHz, range/4 1.395 1.617, range/16 0.349 0.404
# divider 873 range 5.556 6.438 MHz, range/4 1.389 1.609, range/16 0.347 0.402
# divider 875 range 5.543 6.423 MHz, range/4 1.386 1.606, range/16 0.346 0.401
# divider 880 range 5.511 6.386 MHz, range/4 1.378 1.597, range/16 0.344 0.399
# divider 882 range 5.499 6.372 MHz, range/4 1.375 1.593, range/16 0.344 0.398
# divider 889 range 5.456 6.322 MHz, range/4 1.364 1.581, range/16 0.341 0.395
# divider 891 range 5.443 6.308 MHz, range/4 1.361 1.577, range/16 0.340 0.394
# divider 896 range 5.413 6.272 MHz, range/4 1.353 1.568, range/16 0.338 0.392
# divider 900 range 5.389 6.244 MHz, range/4 1.347 1.561, range/16 0.337 0.390
# divider 902 range 5.377 6.231 MHz, range/4 1.344 1.558, range/16 0.336 0.389
# divider 909 range 5.336 6.183 MHz, range/4 1.334 1.546, range/16 0.334 0.386
# divider 913 range 5.312 6.156 MHz, range/4 1.328 1.539, range/16 0.332 0.385
# divider 918 range 5.283 6.122 MHz, range/4 1.321 1.530, range/16 0.330 0.383
# divider 924 range 5.249 6.082 MHz, range/4 1.312 1.520, range/16 0.328 0.380
# divider 927 range 5.232 6.063 MHz, range/4 1.308 1.516, range/16 0.327 0.379
# divider 935 range 5.187 6.011 MHz, range/4 1.297 1.503, range/16 0.324 0.376
# divider 936 range 5.182 6.004 MHz, range/4 1.296 1.501, range/16 0.324 0.375
# divider 945 range 5.132 5.947 MHz, range/4 1.283 1.487, range/16 0.321 0.372
# divider 946 range 5.127 5.941 MHz, range/4 1.282 1.485, range/16 0.320 0.371
# divider 954 range 5.084 5.891 MHz, range/4 1.271 1.473, range/16 0.318 0.368
# divider 957 range 5.068 5.873 MHz, range/4 1.267 1.468, range/16 0.317 0.367
# divider 963 range 5.036 5.836 MHz, range/4 1.259 1.459, range/16 0.315 0.365
# divider 968 range 5.010 5.806 MHz, range/4 1.252 1.452, range/16 0.313 0.363
# divider 972 range 4.990 5.782 MHz, range/4 1.248 1.446, range/16 0.312 0.361
# divider 979 range 4.954 5.741 MHz, range/4 1.238 1.435, range/16 0.310 0.359
# divider 981 range 4.944 5.729 MHz, range/4 1.236 1.432, range/16 0.309 0.358
# divider 990 range 4.899 5.677 MHz, range/4 1.225 1.419, range/16 0.306 0.355
# divider 999 range 4.855 5.626 MHz, range/4 1.214 1.407, range/16 0.303 0.352
# divider 1001 range 4.845 5.614 MHz, range/4 1.211 1.403, range/16 0.303 0.351
# divider 1008 range 4.812 5.575 MHz, range/4 1.203 1.394, range/16 0.301 0.348
# divider 1012 range 4.792 5.553 MHz, range/4 1.198 1.388, range/16 0.299 0.347
# divider 1017 range 4.769 5.526 MHz, range/4 1.192 1.381, range/16 0.298 0.345
# divider 1023 range 4.741 5.494 MHz, range/4 1.185 1.373, range/16 0.296 0.343
# divider 1026 range 4.727 5.478 MHz, range/4 1.182 1.369, range/16 0.295 0.342
# divider 1034 range 4.691 5.435 MHz, range/4 1.173 1.359, range/16 0.293 0.340
# divider 1035 range 4.686 5.430 MHz, range/4 1.171 1.357, range/16 0.293 0.339
# divider 1044 range 4.646 5.383 MHz, range/4 1.161 1.346, range/16 0.290 0.336
# divider 1045 range 4.641 5.378 MHz, range/4 1.160 1.345, range/16 0.290 0.336
# divider 1053 range 4.606 5.337 MHz, range/4 1.151 1.334, range/16 0.288 0.334
# divider 1056 range 4.593 5.322 MHz, range/4 1.148 1.331, range/16 0.287 0.333
# divider 1062 range 4.567 5.292 MHz, range/4 1.142 1.323, range/16 0.285 0.331
# divider 1067 range 4.545 5.267 MHz, range/4 1.136 1.317, range/16 0.284 0.329
# divider 1071 range 4.528 5.247 MHz, range/4 1.132 1.312, range/16 0.283 0.328
# divider 1078 range 4.499 5.213 MHz, range/4 1.125 1.303, range/16 0.281 0.326
# divider 1080 range 4.491 5.204 MHz, range/4 1.123 1.301, range/16 0.281 0.325
# divider 1089 range 4.454 5.161 MHz, range/4 1.113 1.290, range/16 0.278 0.323
# divider 1098 range 4.417 5.118 MHz, range/4 1.104 1.280, range/16 0.276 0.320
# divider 1100 range 4.409 5.109 MHz, range/4 1.102 1.277, range/16 0.276 0.319
# divider 1107 range 4.381 5.077 MHz, range/4 1.095 1.269, range/16 0.274 0.317
# divider 1111 range 4.365 5.059 MHz, range/4 1.091 1.265, range/16 0.273 0.316
# divider 1116 range 4.346 5.036 MHz, range/4 1.087 1.259, range/16 0.272 0.315
# divider 1122 range 4.323 5.009 MHz, range/4 1.081 1.252, range/16 0.270 0.313
# divider 1125 range 4.311 4.996 MHz, range/4 1.078 1.249, range/16 0.269 0.312
# divider 1133 range 4.281 4.960 MHz, range/4 1.070 1.240, range/16 0.268 0.310
# divider 1134 range 4.277 4.956 MHz, range/4 1.069 1.239, range/16 0.267 0.310
# divider 1143 range 4.243 4.917 MHz, range/4 1.061 1.229, range/16 0.265 0.307
# divider 1144 range 4.240 4.913 MHz, range/4 1.060 1.228, range/16 0.265 0.307
# divider 1152 range 4.210 4.878 MHz, range/4 1.052 1.220, range/16 0.263 0.305
# divider 1155 range 4.199 4.866 MHz, range/4 1.050 1.216, range/16 0.262 0.304
# divider 1166 range 4.160 4.820 MHz, range/4 1.040 1.205, range/16 0.260 0.301
# divider 1177 range 4.121 4.775 MHz, range/4 1.030 1.194, range/16 0.258 0.298
# divider 1188 range 4.082 4.731 MHz, range/4 1.020 1.183, range/16 0.255 0.296
# divider 1199 range 4.045 4.687 MHz, range/4 1.011 1.172, range/16 0.253 0.293
# divider 1210 range 4.008 4.645 MHz, range/4 1.002 1.161, range/16 0.251 0.290
# divider 1221 range 3.972 4.603 MHz, range/4 0.993 1.151, range/16 0.248 0.288
# divider 1232 range 3.937 4.562 MHz, range/4 0.984 1.141, range/16 0.246 0.285
# divider 1243 range 3.902 4.521 MHz, range/4 0.976 1.130, range/16 0.244 0.283
# divider 1254 range 3.868 4.482 MHz, range/4 0.967 1.121, range/16 0.242 0.280
# divider 1265 range 3.834 4.443 MHz, range/4 0.959 1.111, range/16 0.240 0.278
# divider 1276 range 3.801 4.404 MHz, range/4 0.950 1.101, range/16 0.238 0.275
# divider 1287 range 3.768 4.367 MHz, range/4 0.942 1.092, range/16 0.235 0.273
# divider 1298 range 3.737 4.330 MHz, range/4 0.934 1.083, range/16 0.234 0.271
# divider 1309 range 3.705 4.293 MHz, range/4 0.926 1.073, range/16 0.232 0.268
# divider 1320 range 3.674 4.258 MHz, range/4 0.918 1.065, range/16 0.230 0.266
# divider 1331 range 3.644 4.222 MHz, range/4 0.911 1.056, range/16 0.228 0.264
# divider 1342 range 3.614 4.188 MHz, range/4 0.903 1.047, range/16 0.226 0.262
# divider 1353 range 3.585 4.154 MHz, range/4 0.896 1.038, range/16 0.224 0.260
# divider 1364 range 3.556 4.120 MHz, range/4 0.889 1.030, range/16 0.222 0.258
# divider 1375 range 3.527 4.087 MHz, range/4 0.882 1.022, range/16 0.220 0.255
# divider 1386 range 3.499 4.055 MHz, range/4 0.875 1.014, range/16 0.219 0.253
# divider 1397 range 3.472 4.023 MHz, range/4 0.868 1.006, range/16 0.217 0.251
# divider 1408 range 3.445 3.991 MHz, range/4 0.861 0.998, range/16 0.215 0.249
#

# the default si570 i2c address
proc si570::default_addr {} { return $si570::I2C_ADDR }
# the default si570 startup frequency
proc si570::default_startup {} { return $si570::STARTUP_FREQ }
# the default si570 crystal frequency
proc si570::default_xtal {} { return $si570::XTAL_FREQ }
 
## compute the HS_DIV, N1, and RFREQ for the registers
proc si570::registers_to_variables {regs_or_vars} {
    switch [llength $regs_or_vars] {
	3 - 4 { return $regs_or_vars }
	6 {
	    lassign $regs_or_vars b0 b1 b2 b3 b4 b5
	    set HS_DIV [expr {($b0 & 0xE0) >> 5}]
	    set N1 [expr {(($b0 & 0x1f) << 2) | (($b1 & 0xc0 ) >> 6)}]
	    set RFREQ_int [expr {(($b1 & 0x3f) << 4) | (($b2 & 0xf0) >> 4)}]
	    set RFREQ_frac [expr {(((((($b2 & 0xf) << 8) | $b3) << 8) | $b4) << 8) | $b5}]
	    set RFREQ [expr {$RFREQ_int + $RFREQ_frac / $::si570::FACTOR}]
	    return [list $HS_DIV $N1 $RFREQ]
	}
	default { error "si570::registers_to_variables: invalid registers $registers" }
    }
}

## compute the registers for the HS_DIV, N1, RFREQ
proc si570::variables_to_registers {regs_or_vars} {
    switch [llength $regs_or_vars] {
	3 - 4 {
	    lassign $regs_or_vars HS_DIV N1 RFREQ p
	    # chop these values up into registers
	    # |DDDNNNNN|NNIIIIII|IIIIFFFF|FFFFFFFF|FFFFFFFF|FFFFFFFF|
	    # D=HS_DIV
	    # N=N1
	    # I=RFREQ_int
	    # F=RFREQ_frac
	    set RFREQ_int [expr {int($RFREQ)}]
	    set RFREQ_frac [expr {int(($RFREQ-$RFREQ_int)*$::si570::FACTOR)}]
	    set b0 [expr {($HS_DIV << 5) | (($N1 >> 2) & 0x1f)}]
	    set b1 [expr {(($N1&0x3) << 6) | ($RFREQ_int >> 4)}]
	    set b2 [expr {(($RFREQ_int&0xF) << 4) | (($RFREQ_frac >> 24) & 0xF)}]
	    set b3 [expr {(($RFREQ_frac >> 16) & 0xFF)}]
	    set b4 [expr {(($RFREQ_frac >> 8) & 0xFF)}]
	    set b5 [expr {(($RFREQ_frac >> 0) & 0xFF)}]
	    return [list $b0 $b1 $b2 $b3 $b4 $b5]
	}
	6 { return $regs_or_vars }
	default { error "si570::variables_to_registers: invalid variables $variables" }
    }
}

## compute the crystal frequency multiplier for the set of register values
proc si570::calculate_xtal_multiplier {regs_or_vars} {
    variable HS_DIV_MAP
    lassign [registers_to_variables $regs_or_vars] HS_DIV N1 RFREQ p
    return [expr {$RFREQ / (($N1 + 1) * $HS_DIV_MAP($HS_DIV))}]
}

## compute the crystal frequency from the registers and the factory startup frequency
proc si570::calculate_xtal {regs_or_vars startup} {
    return [expr {$startup / [calculate_xtal_multiplier $regs_or_vars]}]
}

## compute the frequency from the registers and the crystal frequency
proc si570::calculate_frequency {regs_or_vars xtal} {
    return [expr {$xtal * [calculate_xtal_multiplier $regs_or_vars]}]
}

## compute the divider for the registers or variables
proc si570::calculate_divider {regs_or_vars} {
    variable HS_DIV_MAP
    lassign [registers_to_variables $regs_or_vars] HS_DIV N1 RFREQ p
    return [expr {(($N1 + 1) * $HS_DIV_MAP($HS_DIV))}]
}
    
## compute the dco frequency for the registers or vars
proc si570::calculate_dco {regs_or_vars {xtal {}}} {
    if {$xtal eq {}} { set xtal [si570::default_xtal] }
    lassign [registers_to_variables $regs_or_vars] HS_DIV N1 RFREQ p
    return [expr {$RFREQ*$xtal}]
}

## frequency = xtal * xtal_multiplier
##	xtal_multiplier = frequency / xtal
##	xtal_multiplier = rfreq / ((n1 + 1) * hs_div_map(hs_div))
## dco = f * divider = f * ((n1 + 1) * hs_div_map(hs_div))
##
## rfreq = dco / xtal
## rfreq_min = dco_low / xtal = 42.437765236032725
## rfreq_max = dco_high / xtal = 49.17530734567091
##
## given a frequency, there is a minimum and a maximum divider that can tune it.
##

## compute the variables for a frequency and the specified crystal frequency
proc si570::find_solutions {frequency {xtal {}}} {
    if {$xtal eq {}} { set xtal [si570::default_xtal] }
    variable HS_DIV_MAP
    variable DCO_LOW
    variable DCO_HIGH
    set solutions {}
    ## for each of the possible dividers
    ## get the divider index (HS_DIV) and the divider value (HS_DIVIDER)
    foreach HS_DIV [lsort [array names HS_DIV_MAP]] {
	set HS_DIVIDER $HS_DIV_MAP($HS_DIV);
	## the negative divider values don't count
	if {$HS_DIVIDER <= 0} continue
	## calculate N1 at the midrange of the DCO
	set y [expr {($DCO_HIGH+$DCO_LOW) / (2 * $frequency * $HS_DIVIDER)}]
	if {$y < 1.5} {
	    set y 1.0
	} else {
	    set y [expr {2 * round($y / 2.0)}]
	}
	if {$y > 128} {
	    set y 128.0
	}
	set N1 [expr {int(floor($y) - 1)}]
	## set N1 [expr {int(floor(($DCO_HIGH+$DCO_LOW) / (2 * $frequency * $HS_DIVIDER)) - 1)}]
	if {$N1 < 0 || $N1 > 127} continue
	set f0 [expr {$frequency * ($N1+1) * $HS_DIVIDER}]
	if {$DCO_LOW <= $f0 && $f0 <= $DCO_HIGH} {
	    set RFREQ [expr {$f0 / $xtal}]
	    set p [variables_to_proportion $HS_DIV $N1 $RFREQ $xtal]
	    # set p [expr {($f0-$DCO_LOW)/($DCO_HIGH-$DCO_LOW)}]
	    lappend solutions [list $HS_DIV $N1 $RFREQ $p]
	}
    }
    return $solutions
}

proc si570::choose_solution {solutions} {
    if {$solutions eq {}} {
	error "si570::choose_solution no solutions"
    }
    # take the lowest DCO == lowest RFREQ
    return [lindex [lsort -index 2 -real -increasing $solutions] 0]
}

## compute the registers for a frequency and the specified crystal frequency
proc si570::calculate_registers {frequency xtal} {
    return [variables_to_registers [choose_solution [find_solutions $frequency $xtal]]]
}

## check if the computed crystal frequency is within spec
proc si570::validate_xtal {xtal} {
    variable XTAL_FREQ
    variable XTAL_DEVIATION_PPM
    if {(1000000.0 * abs($xtal - $XTAL_FREQ) / $XTAL_FREQ) <= $XTAL_DEVIATION_PPM} {
	return $xtal
    } else {
	# The most likely possibility is that since power on,
	# the Si570 has been shifted from the factory default frequency.
	# Except we reset the Si570 before we did this.
	error "calculated crystal reference is outside of the spec for the Si570 device"
    }
}

## compute the position in the range of tunings with the same dividers
proc si570::variables_to_proportion {HS_DIV N1 RFREQ xtal} {
    variable DCO_LOW
    variable DCO_HIGH
    set f0 [expr {$RFREQ * $xtal}]
    return [format %.3f [expr {($f0-$DCO_LOW)/($DCO_HIGH-$DCO_LOW)}]]
}

