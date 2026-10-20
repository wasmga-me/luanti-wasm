#pragma once

#include <functional>
#include <pthread.h>

#include <mutex>

// wasmga.me: held while the server writes its world, so the play page's copy
// of the player's files (wg_request_files) never catches a world half written.
extern std::mutex wg_files_mutex;
