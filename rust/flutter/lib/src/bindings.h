#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

typedef struct ByteBuffer {
  uint8_t *ptr;
  uintptr_t length;
  uintptr_t capacity;
} ByteBuffer;

void free_byte_buffer(struct ByteBuffer buffer);

bool init_http_client(void);

struct ByteBuffer execute_request_bytes(const char *request_json);

struct ByteBuffer execute_batch_requests_bytes(const char *requests_json);

void free_string(char *ptr);
