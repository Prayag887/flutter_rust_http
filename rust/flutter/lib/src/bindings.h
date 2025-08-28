#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

typedef struct Buffer {
  uint8_t *ptr;
  uintptr_t len;
} Buffer;

bool init_http_client(void);

struct Buffer execute_request_binary(uint8_t *request_ptr, uintptr_t request_len);

struct Buffer execute_requests_batch_binary(uint8_t *requests_ptr, uintptr_t requests_len);

void free_buffer(uint8_t *ptr, uintptr_t len);

void shutdown_http_client(void);
