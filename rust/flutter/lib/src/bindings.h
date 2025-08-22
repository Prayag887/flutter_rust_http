#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

bool init_http_client(void);

char *execute_request(const char *request_json);

char *execute_batch_requests(const char *requests_json);

void free_string(char *ptr);
