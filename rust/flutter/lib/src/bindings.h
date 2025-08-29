#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

typedef struct BufferCap {
  uint8_t *ptr;
  uintptr_t len;
  uintptr_t cap;
} BufferCap;

typedef struct Buffer {
  uint8_t *ptr;
  uintptr_t len;
} Buffer;

bool init_http_client(void);

/**
 * Allocate a writable buffer in Rust and return pointer+capacity.
 * Dart will write UTF-8 JSON bytes into it.
 */
struct BufferCap allocate_request_buffer(uintptr_t capacity);

/**
 * After Dart writes into the buffer, call this to set the actual length.
 * You can skip this and pass `len` directly to execute if you track it on Dart side.
 */
void set_buffer_len(uint8_t *ptr, uintptr_t len, uintptr_t cap);

/**
 * Execute a single request taking ownership of the buffer (NO COPY).
 */
struct Buffer execute_request_binary_from_owned(uint8_t *ptr, uintptr_t len, uintptr_t cap);

/**
 * Execute a batch taking ownership of the buffer (NO COPY).
 */
struct Buffer execute_requests_batch_binary_from_owned(uint8_t *ptr, uintptr_t len, uintptr_t cap);

struct Buffer execute_request_binary(const uint8_t *request_ptr, uintptr_t request_len);

struct Buffer execute_requests_batch_binary(const uint8_t *requests_ptr, uintptr_t requests_len);

void free_buffer_with_capacity(uint8_t *ptr, uintptr_t len, uintptr_t cap);

void free_buffer(uint8_t *ptr, uintptr_t len);

void shutdown_http_client(void);
