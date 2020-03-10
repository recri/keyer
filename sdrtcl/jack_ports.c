#if 0
/*
** functions for making a patch panel display
** connect to a jack server and register these, and other, callbacks
** to be notified of client, port, and connection life cycle events.
** but can't see the activate/deactivate state because only the activated appear.
*/
typedef void (*JackClientRegistrationCallback)(const char* name, int register, void *arg);
int jack_set_client_registration_callback (jack_client_t *,
                       JackClientRegistrationCallback
                                           registration_callback, void *arg);

typedef void (*JackPortRegistrationCallback)(jack_port_id_t port, int register, void *arg);
int jack_set_port_registration_callback (jack_client_t *,
                                          JackPortRegistrationCallback
                                          registration_callback, void *arg);

typedef void (*JackPortConnectCallback)(jack_port_id_t a, jack_port_id_t b, int connect, void* arg);
int jack_set_port_connect_callback (jack_client_t *,
                                    JackPortConnectCallback
                                    connect_callback, void *arg)

typedef int (*JackPortRenameCallback)(jack_port_id_t port, const char* old_name, const char* new_name, void *arg);
int jack_set_port_rename_callback (jack_client_t *,
                                   JackPortRenameCallback
                                   rename_callback, void *arg)

typedef int (*JackGraphOrderCallback)(void *arg);
int jack_set_graph_order_callback (jack_client_t *,
                                   JackGraphOrderCallback graph_callback,
                                   void *)

typedef int (*JackXRunCallback)(void *arg);
int jack_set_xrun_callback (jack_client_t *,
                            JackXRunCallback xrun_callback, void *arg)
#endif
