  { "verbose", "amount of diagnostic output", "0", options_handle_verbose, option_int, offsetof(options_t, verbose) },

  { "chan", "midi channel used for keyer", "1", options_handle_chan, option_int, offsetof(options_t, chan) },
  { "note", "base midi note used for keyer", "0", options_handle_note, option_int, offsetof(options_t, note) },

  { "server", "jack server name", "default", options_handle_server, option_string, offsetof(options_t, server) },
  { "client", "jack client name", NULL, options_handle_client, option_string, offsetof(options_t, client) },
