#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

typedef struct SharedBuffer {
  uint8_t *data;
  uintptr_t len;
  uintptr_t capacity;
} SharedBuffer;

bool init_http_client(void);

struct SharedBuffer *allocate_buffer(uintptr_t size);

void free_buffer(struct SharedBuffer *ptr);

int32_t execute_request_direct(const char *request_json, struct SharedBuffer *response_buffer);

void free_string(char *ptr);
