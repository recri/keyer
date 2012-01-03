  { "freq", "frequency of tone in hertz", "700.0", options_handle_freq, option_float, offsetof(options_t, freq) },
  { "gain", "level of tone in decibels", "-30.0", options_handle_gain, option_float, offsetof(options_t, gain) },
  { "rise", "rise time in milliseconds", "5.0", options_handle_rise, option_float, offsetof(options_t, rise) },
  { "fall", "fall time in milliseconds", "5.0", options_handle_fall, option_float, offsetof(options_t, fall) },
  { "ramp", "rise/fall time in milliseconds", "5.0", options_handle_ramp, option_float, 0 },

