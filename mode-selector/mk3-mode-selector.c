#define _GNU_SOURCE

#include "mk3.h"

#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <linux/input.h>
#include <poll.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <time.h>
#include <unistd.h>

#define SCREEN_WIDTH 480
#define SCREEN_HEIGHT 272
#define MAX_MODES 8
#define MAX_INPUTS 32
#define DEFAULT_CONFIG "/var/lib/mk3-mode/config"

typedef struct {
    char target[64];
    char label[64];
} mode_entry_t;

typedef struct {
    mode_entry_t modes[MAX_MODES];
    int count;
    int selected;
    int default_index;
    bool shift;
    bool activate;
    bool save_default;
    bool dirty;
} selector_state_t;

typedef struct {
    int fds[MAX_INPUTS];
    int count;
} keyboard_set_t;

static const uint8_t font[][5] = {
    {0x7e,0x11,0x11,0x11,0x7e}, {0x7f,0x49,0x49,0x49,0x36},
    {0x3e,0x41,0x41,0x41,0x22}, {0x7f,0x41,0x41,0x22,0x1c},
    {0x7f,0x49,0x49,0x49,0x41}, {0x7f,0x09,0x09,0x09,0x01},
    {0x3e,0x41,0x49,0x49,0x7a}, {0x7f,0x08,0x08,0x08,0x7f},
    {0x00,0x41,0x7f,0x41,0x00}, {0x20,0x40,0x41,0x3f,0x01},
    {0x7f,0x08,0x14,0x22,0x41}, {0x7f,0x40,0x40,0x40,0x40},
    {0x7f,0x02,0x0c,0x02,0x7f}, {0x7f,0x04,0x08,0x10,0x7f},
    {0x3e,0x41,0x41,0x41,0x3e}, {0x7f,0x09,0x09,0x09,0x06},
    {0x3e,0x41,0x51,0x21,0x5e}, {0x7f,0x09,0x19,0x29,0x46},
    {0x46,0x49,0x49,0x49,0x31}, {0x01,0x01,0x7f,0x01,0x01},
    {0x3f,0x40,0x40,0x40,0x3f}, {0x1f,0x20,0x40,0x20,0x1f},
    {0x3f,0x40,0x38,0x40,0x3f}, {0x63,0x14,0x08,0x14,0x63},
    {0x07,0x08,0x70,0x08,0x07}, {0x61,0x51,0x49,0x45,0x43},
};

static const uint8_t digits[][5] = {
    {0x3e,0x51,0x49,0x45,0x3e}, {0x00,0x42,0x7f,0x40,0x00},
    {0x42,0x61,0x51,0x49,0x46}, {0x21,0x41,0x45,0x4b,0x31},
    {0x18,0x14,0x12,0x7f,0x10}, {0x27,0x45,0x45,0x45,0x39},
    {0x3c,0x4a,0x49,0x49,0x30}, {0x01,0x71,0x09,0x05,0x03},
    {0x36,0x49,0x49,0x49,0x36}, {0x06,0x49,0x49,0x29,0x1e},
};

static int64_t monotonic_ms(void)
{
    struct timespec now;
    clock_gettime(CLOCK_MONOTONIC, &now);
    return (int64_t)now.tv_sec * 1000 + now.tv_nsec / 1000000;
}

static void trim(char* value)
{
    char* start = value;
    while (*start == ' ' || *start == '\t') ++start;
    if (start != value) memmove(value, start, strlen(start) + 1);
    size_t length = strlen(value);
    while (length && (value[length - 1] == ' ' || value[length - 1] == '\t' ||
                      value[length - 1] == '\n' || value[length - 1] == '\r'))
        value[--length] = '\0';
}

static void remove_target_suffix(char* target)
{
    const size_t length = strlen(target);
    if (length > 7 && strcmp(target + length - 7, ".target") == 0)
        target[length - 7] = '\0';
}

static bool safe_mode_name(const char* value)
{
    if (!value || !*value) return false;
    for (const unsigned char* p = (const unsigned char*)value; *p; ++p) {
        if (!((*p >= 'a' && *p <= 'z') || (*p >= 'A' && *p <= 'Z') ||
              (*p >= '0' && *p <= '9') || *p == '-' || *p == '_' || *p == '.'))
            return false;
    }
    return true;
}

static int load_config(const char* path, selector_state_t* state)
{
    FILE* file = fopen(path, "r");
    if (!file) {
        fprintf(stderr, "Cannot read selector config %s: %s\n", path, strerror(errno));
        return -1;
    }

    char default_mode[64] = "maschinepi";
    char line[256];
    while (fgets(line, sizeof line, file)) {
        trim(line);
        if (!*line || line[0] == '#') continue;
        if (strncmp(line, "default_mode=", 13) == 0) {
            snprintf(default_mode, sizeof default_mode, "%.63s", line + 13);
            trim(default_mode);
            remove_target_suffix(default_mode);
            continue;
        }
        if (strncmp(line, "slot", 4) != 0 || state->count >= MAX_MODES) continue;
        char* equals = strchr(line, '=');
        char* separator = equals ? strchr(equals + 1, '|') : NULL;
        if (!equals || !separator) continue;
        *separator = '\0';
        char* target = equals + 1;
        char* label = separator + 1;
        trim(target);
        trim(label);
        remove_target_suffix(target);
        if (!safe_mode_name(target) || !*label) continue;
        snprintf(state->modes[state->count].target,
                 sizeof state->modes[state->count].target, "%s", target);
        snprintf(state->modes[state->count].label,
                 sizeof state->modes[state->count].label, "%s", label);
        ++state->count;
    }
    fclose(file);

    if (state->count == 0) {
        fprintf(stderr, "Selector config contains no valid slots\n");
        return -1;
    }
    state->default_index = 0;
    for (int i = 0; i < state->count; ++i)
        if (strcmp(state->modes[i].target, default_mode) == 0)
            state->default_index = i;
    state->selected = state->default_index;
    return 0;
}

static int save_default(const char* path, const selector_state_t* state)
{
    char temporary[512];
    snprintf(temporary, sizeof temporary, "%s.tmp.XXXXXX", path);
    int fd = mkstemp(temporary);
    if (fd < 0) return -1;
    FILE* file = fdopen(fd, "w");
    if (!file) {
        close(fd);
        unlink(temporary);
        return -1;
    }
    fprintf(file, "default_mode=%s\n", state->modes[state->selected].target);
    for (int i = 0; i < state->count; ++i)
        fprintf(file, "slot%d=%s.target|%s\n", i + 1,
                state->modes[i].target, state->modes[i].label);
    if (fflush(file) != 0 || fsync(fd) != 0 || fclose(file) != 0 ||
        rename(temporary, path) != 0) {
        unlink(temporary);
        return -1;
    }
    return 0;
}

static uint16_t rgb565(unsigned r, unsigned g, unsigned b)
{
    return (uint16_t)(((r & 0xf8) << 8) | ((g & 0xfc) << 3) | (b >> 3));
}

static const uint8_t* glyph_for(char character)
{
    if (character >= 'a' && character <= 'z') character -= 32;
    if (character >= 'A' && character <= 'Z') return font[character - 'A'];
    if (character >= '0' && character <= '9') return digits[character - '0'];
    return NULL;
}

static void fill_rect(uint16_t* frame, int x, int y, int width, int height, uint16_t color)
{
    for (int py = y; py < y + height && py < SCREEN_HEIGHT; ++py)
        for (int px = x; px < x + width && px < SCREEN_WIDTH; ++px)
            if (px >= 0 && py >= 0) frame[py * SCREEN_WIDTH + px] = color;
}

static void draw_char(uint16_t* frame, int x, int y, char character, int scale, uint16_t color)
{
    const uint8_t* glyph = glyph_for(character);
    if (!glyph) {
        if (character == '>') {
            for (int i = 0; i < 4 * scale; ++i)
                fill_rect(frame, x + i, y + i / 2, scale, scale, color);
        } else if (character == '-') {
            fill_rect(frame, x, y + 3 * scale, 5 * scale, scale, color);
        }
        return;
    }
    for (int column = 0; column < 5; ++column)
        for (int row = 0; row < 7; ++row)
            if (glyph[column] & (1u << row))
                fill_rect(frame, x + column * scale, y + row * scale,
                          scale, scale, color);
}

static void draw_text(uint16_t* frame, int x, int y, const char* text,
                      int scale, uint16_t color)
{
    for (const char* p = text; *p; ++p) {
        draw_char(frame, x, y, *p, scale, color);
        x += 6 * scale;
    }
}

static void uppercase(char* destination, size_t size, const char* source)
{
    size_t i = 0;
    for (; source[i] && i + 1 < size; ++i) {
        char c = source[i];
        destination[i] = (c >= 'a' && c <= 'z') ? (char)(c - 32) : c;
    }
    destination[i] = '\0';
}

static void render_menu(mk3_t* device, const selector_state_t* state, const char* status)
{
    if (!device) return;
    uint16_t* left = calloc(SCREEN_WIDTH * SCREEN_HEIGHT, sizeof *left);
    uint16_t* right = calloc(SCREEN_WIDTH * SCREEN_HEIGHT, sizeof *right);
    if (!left || !right) {
        free(left);
        free(right);
        return;
    }

    const uint16_t orange = rgb565(255, 105, 0);
    const uint16_t white = rgb565(235, 235, 235);
    const uint16_t dim = rgb565(110, 110, 110);
    char label[64];
    uppercase(label, sizeof label, state->modes[state->selected].label);

    fill_rect(left, 0, 0, SCREEN_WIDTH, 8, orange);
    draw_text(left, 28, 66, label, 5, white);
    draw_text(left, 30, 178, "READY TO START", 2, orange);
    draw_text(left, 30, 226, status && *status ? status : "MODE SELECT", 2, dim);

    draw_text(right, 24, 22, "SELECT MODE", 3, orange);
    for (int i = 0; i < state->count; ++i) {
        char row[96];
        char row_label[64];
        uppercase(row_label, sizeof row_label, state->modes[i].label);
        snprintf(row, sizeof row, "%s%d %s", i == state->selected ? ">" : " ",
                 i + 1, row_label);
        if (i == state->selected)
            fill_rect(right, 18, 72 + i * 42, 440, 34, rgb565(75, 34, 0));
        draw_text(right, 28, 79 + i * 42, row, 3,
                  i == state->selected ? white : dim);
    }
    draw_text(right, 24, 202, "PUSH TO START", 2, white);
    draw_text(right, 24, 234, "D8 SET DEFAULT", 2, dim);

    mk3_display_disable_partial_rendering(device, true);
    (void)mk3_display_draw(device, 0, left);
    (void)mk3_display_draw(device, 1, right);
    free(left);
    free(right);
}

static void render_status(mk3_t* device, int progress, const char* message)
{
    if (!device) return;
    uint16_t* left = calloc(SCREEN_WIDTH * SCREEN_HEIGHT, sizeof *left);
    uint16_t* right = calloc(SCREEN_WIDTH * SCREEN_HEIGHT, sizeof *right);
    if (!left || !right) {
        free(left);
        free(right);
        return;
    }

    const uint16_t orange = rgb565(255, 105, 0);
    const uint16_t white = rgb565(235, 235, 235);
    const uint16_t dim = rgb565(90, 90, 90);
    char percent[16];
    char status[96];
    snprintf(percent, sizeof percent, "%d", progress);
    uppercase(status, sizeof status, message);

    fill_rect(left, 0, 0, SCREEN_WIDTH, 8, orange);
    draw_text(left, 28, 38, "SD CARD SETUP", 3, orange);
    draw_text(left, 30, 98, percent, 8, white);
    draw_text(left, 30, 190, "PERCENT", 3, dim);

    fill_rect(right, 0, 0, SCREEN_WIDTH, 8, orange);
    draw_text(right, 24, 38, "PREPARING STORAGE", 3, orange);
    draw_text(right, 24, 102, status, 2, white);
    fill_rect(right, 24, 158, 432, 30, dim);
    fill_rect(right, 28, 162, (424 * progress) / 100, 22, orange);
    draw_text(right, 24, 222, "DO NOT POWER OFF", 2, dim);

    mk3_display_disable_partial_rendering(device, true);
    (void)mk3_display_draw(device, 0, left);
    (void)mk3_display_draw(device, 1, right);
    free(left);
    free(right);
}

static void print_console_menu(const selector_state_t* state)
{
    fprintf(stderr, "\nMK3 mode selector (controller display unavailable)\n");
    for (int i = 0; i < state->count; ++i)
        fprintf(stderr, "%c %d: %s%s\n", i == state->selected ? '>' : ' ', i + 1,
                state->modes[i].label, i == state->default_index ? " [default]" : "");
    fprintf(stderr, "Arrow keys select, Enter starts, D saves default.\n");
}

static void button_callback(const char* name, bool pressed, void* userdata)
{
    selector_state_t* state = userdata;
    if (strcmp(name, "shift") == 0) state->shift = pressed;
    if (!pressed) return;
    if (strcmp(name, "navPush") == 0) state->activate = true;
    else if (strcmp(name, "d8") == 0) state->save_default = true;
    else if (name[0] == 'd' && name[1] >= '1' && name[1] <= '8' && name[2] == '\0') {
        const int index = name[1] - '1';
        if (index < state->count) {
            state->selected = index;
            state->activate = true;
            state->dirty = true;
        }
    }
}

static void stepper_callback(int8_t direction, uint8_t position, void* userdata)
{
    (void)position;
    selector_state_t* state = userdata;
    if (!state->count) return;
    state->selected = (state->selected + (direction > 0 ? 1 : state->count - 1)) % state->count;
    state->dirty = true;
}

static void keyboards_close(keyboard_set_t* keyboards)
{
    for (int i = 0; i < keyboards->count; ++i) close(keyboards->fds[i]);
    keyboards->count = 0;
}

static bool keyboards_scan(keyboard_set_t* keyboards)
{
    DIR* directory = opendir("/dev/input");
    if (!directory) return false;
    struct dirent* entry;
    while ((entry = readdir(directory)) && keyboards->count < MAX_INPUTS) {
        if (strncmp(entry->d_name, "event", 5) != 0) continue;
        if (strlen(entry->d_name) > 32) continue;
        char path[64];
        snprintf(path, sizeof path, "/dev/input/%s", entry->d_name);
        int fd = open(path, O_RDONLY | O_NONBLOCK | O_CLOEXEC);
        if (fd >= 0) keyboards->fds[keyboards->count++] = fd;
    }
    closedir(directory);
    return keyboards->count > 0;
}

static bool keyboard_shift_held(const keyboard_set_t* keyboards)
{
    unsigned long keys[(KEY_MAX + 8 * sizeof(unsigned long)) /
                       (8 * sizeof(unsigned long))];
    for (int i = 0; i < keyboards->count; ++i) {
        memset(keys, 0, sizeof keys);
        if (ioctl(keyboards->fds[i], EVIOCGKEY(sizeof keys), keys) < 0) continue;
        const int bits = 8 * (int)sizeof(unsigned long);
        if ((keys[KEY_LEFTSHIFT / bits] & (1ul << (KEY_LEFTSHIFT % bits))) ||
            (keys[KEY_RIGHTSHIFT / bits] & (1ul << (KEY_RIGHTSHIFT % bits))))
            return true;
    }
    return false;
}

static void keyboard_events(keyboard_set_t* keyboards, selector_state_t* state)
{
    struct input_event event;
    for (int i = 0; i < keyboards->count; ++i) {
        while (read(keyboards->fds[i], &event, sizeof event) == sizeof event) {
            if (event.type != EV_KEY || event.value != 1) continue;
            if (event.code == KEY_UP || event.code == KEY_LEFT) {
                state->selected = (state->selected + state->count - 1) % state->count;
                state->dirty = true;
            } else if (event.code == KEY_DOWN || event.code == KEY_RIGHT) {
                state->selected = (state->selected + 1) % state->count;
                state->dirty = true;
            } else if (event.code == KEY_ENTER || event.code == KEY_KPENTER) {
                state->activate = true;
            } else if (event.code == KEY_D) {
                state->save_default = true;
            } else if (event.code >= KEY_1 && event.code <= KEY_8) {
                int index = event.code - KEY_1;
                if (index < state->count) {
                    state->selected = index;
                    state->activate = true;
                }
            }
        }
    }
}

static mk3_t* open_mk3(selector_state_t* state)
{
    mk3_t* device = mk3_open();
    if (device) {
        mk3_input_set_button_callback(device, button_callback, state);
        mk3_input_set_stepper_callback(device, stepper_callback, state);
    }
    return device;
}

static bool read_status(const char* path, int* progress, char* message,
                        size_t message_size, bool* done, bool* failed)
{
    FILE* file = fopen(path, "r");
    if (!file) return false;
    char line[192];
    bool result = false;
    if (fgets(line, sizeof line, file)) {
        trim(line);
        if (strcmp(line, "DONE") == 0) {
            *done = true;
            result = true;
        } else if (strcmp(line, "ERROR") == 0) {
            *done = true;
            *failed = true;
            result = true;
        } else {
            char* separator = strchr(line, '|');
            if (separator) {
                *separator = '\0';
                char* end = NULL;
                long value = strtol(line, &end, 10);
                if (end && *end == '\0') {
                    if (value < 0) value = 0;
                    if (value > 100) value = 100;
                    *progress = (int)value;
                    snprintf(message, message_size, "%s", separator + 1);
                    trim(message);
                    result = true;
                }
            }
        }
    }
    fclose(file);
    return result;
}

static void mark_status_ready(const char* path)
{
    if (!path) return;
    int fd = open(path, O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC, 0644);
    if (fd >= 0) close(fd);
}

static int run_status_display(selector_state_t* state, const char* status_file,
                              const char* ready_file, bool dry_run)
{
    int progress = 0;
    int rendered_progress = -1;
    char message[96] = "PREPARING STORAGE";
    char rendered_message[96] = "";
    bool done = false;
    bool failed = false;
    (void)read_status(status_file, &progress, message, sizeof message, &done, &failed);

    if (dry_run) {
        printf("status %d %s%s\n", progress, message,
               failed ? " error" : done ? " done" : "");
        return 0;
    }

    if (ready_file) unlink(ready_file);
    mk3_t* device = NULL;
    int64_t next_open = 0;
    while (!done) {
        (void)read_status(status_file, &progress, message, sizeof message, &done, &failed);
        if (done) break;

        if (!device && monotonic_ms() >= next_open) {
            device = open_mk3(state);
            next_open = monotonic_ms() + 250;
            if (device) {
                mark_status_ready(ready_file);
                rendered_progress = -1;
            }
        }
        if (device && (progress != rendered_progress ||
                       strcmp(message, rendered_message) != 0)) {
            render_status(device, progress, message);
            rendered_progress = progress;
            snprintf(rendered_message, sizeof rendered_message, "%s", message);
        }
        if (device && mk3_input_poll_ex(device) < 0) {
            mk3_close(device);
            device = NULL;
        }
        usleep(50000);
    }

    if (device) {
        render_status(device, failed ? progress : 100,
                      failed ? "STORAGE ERROR" : "STORAGE READY");
        usleep(failed ? 2000000 : 400000);
        mk3_close(device);
    }
    if (ready_file) unlink(ready_file);
    return 0;
}

static int select_by_name(selector_state_t* state, const char* name)
{
    char candidate[64];
    snprintf(candidate, sizeof candidate, "%s", name);
    remove_target_suffix(candidate);
    for (int i = 0; i < state->count; ++i) {
        if (strcmp(candidate, state->modes[i].target) == 0) {
            state->selected = i;
            return 0;
        }
    }
    return -1;
}

static int activate_mode(const selector_state_t* state, bool dry_run)
{
    char target[80];
    snprintf(target, sizeof target, "%s.target", state->modes[state->selected].target);
    if (dry_run) {
        printf("systemctl --no-block isolate %s\n", target);
        return 0;
    }
    execl("/usr/bin/systemctl", "systemctl", "--no-block", "isolate", target, (char*)NULL);
    fprintf(stderr, "Cannot start %s: %s\n", target, strerror(errno));
    return 1;
}

int main(int argc, char** argv)
{
    const char* config = DEFAULT_CONFIG;
    const char* direct_mode = NULL;
    const char* set_mode = NULL;
    const char* status_file = NULL;
    const char* status_ready_file = NULL;
    bool dry_run = false;
    bool force_menu = false;
    int poll_ms = 1800;

    for (int i = 1; i < argc; ++i) {
        if (strcmp(argv[i], "--config") == 0 && i + 1 < argc) config = argv[++i];
        else if (strcmp(argv[i], "--select") == 0 && i + 1 < argc) direct_mode = argv[++i];
        else if (strcmp(argv[i], "--set-default") == 0 && i + 1 < argc) set_mode = argv[++i];
        else if (strcmp(argv[i], "--status-file") == 0 && i + 1 < argc) status_file = argv[++i];
        else if (strcmp(argv[i], "--status-ready-file") == 0 && i + 1 < argc) status_ready_file = argv[++i];
        else if (strcmp(argv[i], "--poll-ms") == 0 && i + 1 < argc) poll_ms = atoi(argv[++i]);
        else if (strcmp(argv[i], "--dry-run") == 0) dry_run = true;
        else if (strcmp(argv[i], "--force-menu") == 0) force_menu = true;
        else {
            fprintf(stderr, "Usage: %s [--config FILE] [--dry-run] [--force-menu] "
                            "[--poll-ms N] [--select MODE] [--set-default MODE] "
                            "[--status-file FILE [--status-ready-file FILE]]\n", argv[0]);
            return 2;
        }
    }

    selector_state_t state = {0};
    if (status_file)
        return run_status_display(&state, status_file, status_ready_file, dry_run);
    if (load_config(config, &state) != 0) return 1;
    if (set_mode) {
        if (select_by_name(&state, set_mode) != 0) return 2;
        if (save_default(config, &state) != 0) {
            fprintf(stderr, "Cannot save default mode: %s\n", strerror(errno));
            return 1;
        }
        if (!direct_mode) return 0;
    }
    if (direct_mode) {
        if (select_by_name(&state, direct_mode) != 0) return 2;
        return activate_mode(&state, dry_run);
    }

    keyboard_set_t keyboards = {0};
    keyboards_scan(&keyboards);
    mk3_t* device = NULL;
    const int64_t deadline = monotonic_ms() + (poll_ms > 0 ? poll_ms : 0);
    bool menu = force_menu || keyboard_shift_held(&keyboards);
    int64_t next_open = 0;
    while (!menu && monotonic_ms() < deadline) {
        if (!device && monotonic_ms() >= next_open) {
            device = open_mk3(&state);
            next_open = monotonic_ms() + 200;
        }
        if (device) (void)mk3_input_poll_ex(device);
        keyboard_events(&keyboards, &state);
        menu = state.shift || keyboard_shift_held(&keyboards);
        usleep(10000);
    }

    if (!menu) {
        state.selected = state.default_index;
        if (device) mk3_close(device);
        keyboards_close(&keyboards);
        return activate_mode(&state, dry_run);
    }

    state.dirty = true;
    print_console_menu(&state);
    while (!state.activate) {
        if (!device && monotonic_ms() >= next_open) {
            device = open_mk3(&state);
            next_open = monotonic_ms() + 500;
            if (device) state.dirty = true;
        }
        if (device && mk3_input_poll_ex(device) < 0) {
            mk3_close(device);
            device = NULL;
        }
        keyboard_events(&keyboards, &state);
        if (state.save_default) {
            if (save_default(config, &state) == 0) {
                state.default_index = state.selected;
                render_menu(device, &state, "DEFAULT SAVED");
                print_console_menu(&state);
            } else {
                fprintf(stderr, "Cannot save default mode: %s\n", strerror(errno));
            }
            state.save_default = false;
        }
        if (state.dirty) {
            render_menu(device, &state, "MODE SELECT");
            print_console_menu(&state);
            state.dirty = false;
        }
        usleep(10000);
    }

    render_menu(device, &state, "STARTING");
    if (device) mk3_close(device);
    keyboards_close(&keyboards);
    return activate_mode(&state, dry_run);
}
