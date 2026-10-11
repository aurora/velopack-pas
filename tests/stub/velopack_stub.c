/*
 * Test double for the Velopack native library.
 *
 * Implements every function declared in third_party/velopack/Velopack.h with
 * simple, deterministic behavior so the Pascal binding can be tested without
 * the real library. The behavior is selected by the URL / path passed to
 * vpkc_new_update_manager:
 *
 *   "fail"       -> manager creation fails
 *   "noupdate"   -> vpkc_check_for_updates returns NO_UPDATE_AVAILABLE
 *   "empty"      -> REMOTE_IS_EMPTY
 *   "error"      -> UPDATE_ERROR
 *   anything else-> UPDATE_AVAILABLE (version 2.0.0, one delta)
 *
 * Extra exports prefixed vpkc_stub_ expose internals to the tests (live
 * object counts to detect leaks, struct layout, recorded calls).
 */
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "Velopack.h"

#define STUB_API __attribute__((visibility("default")))

static int g_live = 0;
static char g_last_error[256] = "";
static char g_apply_version[64] = "";
static int g_apply_silent = -1, g_apply_restart = -1;
static size_t g_apply_argc = 0;
static char g_apply_arg0[128] = "";
static int g_auto_apply = 1;
static vpkc_hook_callback_t g_hook_first_run = NULL;
static vpkc_hook_callback_t g_hook_after_install = NULL;
static vpkc_log_callback_t g_log_cb = NULL;
static void *g_log_ud = NULL;

typedef struct { char url[256]; } stub_manager_t;

static char *dup(const char *s) {
  size_t n = strlen(s) + 1;
  char *p = (char *)malloc(n);
  memcpy(p, s, n);
  return p;
}

static void set_error(const char *msg) {
  snprintf(g_last_error, sizeof g_last_error, "%s", msg);
}

static vpkc_asset_t *new_asset(const char *version, const char *type) {
  vpkc_asset_t *a = (vpkc_asset_t *)calloc(1, sizeof *a);
  a->PackageId = dup("StubApp");
  a->Version = dup(version);
  a->Type = dup(type);
  a->FileName = dup("StubApp-full.nupkg");
  a->SHA1 = dup("sha1-stub");
  a->SHA256 = dup("sha256-stub");
  a->Size = 5000000000ULL; /* > 32 bit to catch size truncation */
  a->NotesMarkdown = dup("# Notes \xc3\xbc");
  a->NotesHtml = dup("<h1>Notes</h1>");
  g_live++;
  return a;
}

static void free_asset_fields(vpkc_asset_t *a) {
  free(a->PackageId); free(a->Version); free(a->Type); free(a->FileName);
  free(a->SHA1); free(a->SHA256); free(a->NotesMarkdown); free(a->NotesHtml);
}

/* ---- sources: opaque tokens, only counted ---- */
static void *new_source(void) { g_live++; return malloc(1); }

vpkc_update_source_t *vpkc_new_source_file(const char *p) { (void)p; return new_source(); }
vpkc_update_source_t *vpkc_new_source_http_url(const char *u) { (void)u; return new_source(); }
vpkc_update_source_t *vpkc_new_source_http_url_with_options(const char *u, struct vpkc_http_options_t *o) { (void)u; (void)o; return new_source(); }
vpkc_update_source_t *vpkc_new_source_github(const char *u, const char *t, bool p) { (void)u; (void)t; (void)p; return new_source(); }
vpkc_update_source_t *vpkc_new_source_gitlab(const char *u, const char *t, bool p) { (void)u; (void)t; (void)p; return new_source(); }
vpkc_update_source_t *vpkc_new_source_gitea(const char *u, const char *t, bool p) { (void)u; (void)t; (void)p; return new_source(); }
vpkc_update_source_t *vpkc_new_source_velopack_flow(const char *u) { (void)u; return new_source(); }
vpkc_update_source_t *vpkc_new_source_custom_callback(vpkc_release_feed_delegate_t a, vpkc_free_release_feed_t b, vpkc_download_asset_delegate_t c, void *ud) { (void)a; (void)b; (void)c; (void)ud; return new_source(); }
void vpkc_source_report_progress(size_t id, int16_t p) { (void)id; (void)p; }
void vpkc_free_source(vpkc_update_source_t *s) { if (s) { free(s); g_live--; } }

/* ---- update manager ---- */
static bool make_manager(const char *url, vpkc_update_manager_t **out) {
  stub_manager_t *m;
  if (strcmp(url, "fail") == 0) { set_error("stub: cannot create manager"); return false; }
  m = (stub_manager_t *)calloc(1, sizeof *m);
  snprintf(m->url, sizeof m->url, "%s", url);
  g_live++;
  *out = m;
  return true;
}

bool vpkc_new_update_manager(const char *u, struct vpkc_update_options_t *o, struct vpkc_locator_config_t *l, vpkc_update_manager_t **m) { (void)o; (void)l; return make_manager(u, m); }
bool vpkc_new_update_manager_flow(struct vpkc_update_options_t *o, struct vpkc_locator_config_t *l, vpkc_update_manager_t **m) { (void)o; (void)l; return make_manager("flow", m); }
bool vpkc_new_update_manager_with_source(vpkc_update_source_t *s, struct vpkc_update_options_t *o, struct vpkc_locator_config_t *l, vpkc_update_manager_t **m) { (void)s; (void)o; (void)l; return make_manager("source", m); }

static size_t put(const char *s, char *buf, size_t c) {
  size_t need = strlen(s) + 1;
  if (buf && c >= need) memcpy(buf, s, need);
  return need;
}
size_t vpkc_get_current_version(vpkc_update_manager_t *m, char *b, size_t c) { (void)m; return put("1.2.3", b, c); }
size_t vpkc_get_app_id(vpkc_update_manager_t *m, char *b, size_t c) { (void)m; return put("StubApp", b, c); }
bool vpkc_is_portable(vpkc_update_manager_t *m) { (void)m; return true; }

bool vpkc_update_pending_restart(vpkc_update_manager_t *m, struct vpkc_asset_t **a) {
  stub_manager_t *s = (stub_manager_t *)m;
  if (strstr(s->url, "pending") == NULL) return false;
  *a = new_asset("1.9.0", "Full");
  return true;
}

vpkc_update_check_t vpkc_check_for_updates(vpkc_update_manager_t *m, struct vpkc_update_info_t **out) {
  stub_manager_t *s = (stub_manager_t *)m;
  vpkc_update_info_t *info;
  if (strstr(s->url, "noupdate")) return NO_UPDATE_AVAILABLE;
  if (strstr(s->url, "empty")) return REMOTE_IS_EMPTY;
  if (strstr(s->url, "error")) { set_error("stub: check failed"); return UPDATE_ERROR; }
  info = (vpkc_update_info_t *)calloc(1, sizeof *info);
  info->TargetFullRelease = new_asset("2.0.0", "Full");
  info->DeltasToTarget = (vpkc_asset_t **)calloc(1, sizeof(vpkc_asset_t *));
  info->DeltasToTarget[0] = new_asset("2.0.0", "Delta");
  info->DeltasToTargetCount = 1;
  info->IsDowngrade = false;
  g_live++;
  *out = info;
  return UPDATE_AVAILABLE;
}

bool vpkc_download_updates(vpkc_update_manager_t *m, struct vpkc_update_info_t *u, vpkc_progress_callback_t cb, void *ud) {
  stub_manager_t *s = (stub_manager_t *)m;
  (void)u;
  if (strstr(s->url, "dlfail")) { set_error("stub: download failed"); return false; }
  if (cb) { cb(ud, 0); cb(ud, 50); cb(ud, 100); }
  return true;
}

bool vpkc_wait_exit_then_apply_updates(vpkc_update_manager_t *m, struct vpkc_asset_t *a, bool silent, bool restart, char **args, size_t argc) {
  (void)m;
  snprintf(g_apply_version, sizeof g_apply_version, "%s", a && a->Version ? a->Version : "");
  g_apply_silent = silent; g_apply_restart = restart; g_apply_argc = argc;
  snprintf(g_apply_arg0, sizeof g_apply_arg0, "%s", argc > 0 ? args[0] : "");
  return true;
}
bool vpkc_unsafe_apply_updates(vpkc_update_manager_t *m, struct vpkc_asset_t *a, bool silent, uint32_t pid, bool restart, char **args, size_t argc) {
  (void)pid;
  return vpkc_wait_exit_then_apply_updates(m, a, silent, restart, args, argc);
}

void vpkc_free_update_manager(vpkc_update_manager_t *m) { if (m) { free(m); g_live--; } }
void vpkc_free_asset(struct vpkc_asset_t *a) { if (a) { free_asset_fields(a); free(a); g_live--; } }
void vpkc_free_update_info(struct vpkc_update_info_t *i) {
  size_t k;
  if (!i) return;
  if (i->TargetFullRelease) vpkc_free_asset(i->TargetFullRelease);
  if (i->BaseRelease) vpkc_free_asset(i->BaseRelease);
  for (k = 0; k < i->DeltasToTargetCount; k++) vpkc_free_asset(i->DeltasToTarget[k]);
  free(i->DeltasToTarget);
  free(i);
  g_live--;
}

/* ---- VelopackApp ---- */
void vpkc_app_run(void *ud) {
  (void)ud;
  if (g_hook_first_run && getenv("STUB_FIRST_RUN")) g_hook_first_run(ud, "1.2.3");
  if (g_hook_after_install && getenv("STUB_AFTER_INSTALL")) g_hook_after_install(ud, "1.2.3");
}
void vpkc_app_set_auto_apply_on_startup(bool b) { g_auto_apply = b; }
void vpkc_app_set_args(char **a, size_t c) { (void)a; (void)c; }
void vpkc_app_set_locator(struct vpkc_locator_config_t *l) { (void)l; }
void vpkc_app_set_hook_after_install(vpkc_hook_callback_t cb) { g_hook_after_install = cb; }
void vpkc_app_set_hook_before_uninstall(vpkc_hook_callback_t cb) { (void)cb; }
void vpkc_app_set_hook_before_update(vpkc_hook_callback_t cb) { (void)cb; }
void vpkc_app_set_hook_after_update(vpkc_hook_callback_t cb) { (void)cb; }
void vpkc_app_set_hook_first_run(vpkc_hook_callback_t cb) { g_hook_first_run = cb; }
void vpkc_app_set_hook_restarted(vpkc_hook_callback_t cb) { (void)cb; }

/* ---- diagnostics ---- */
size_t vpkc_get_last_error(char *b, size_t c) { return put(g_last_error, b, c); }
void vpkc_set_logger(vpkc_log_callback_t cb, void *ud) { g_log_cb = cb; g_log_ud = ud; }

/* ---- test-only exports ---- */
STUB_API int vpkc_stub_live_objects(void) { return g_live; }
STUB_API int vpkc_stub_auto_apply(void) { return g_auto_apply; }
STUB_API const char *vpkc_stub_apply_version(void) { return g_apply_version; }
STUB_API int vpkc_stub_apply_silent(void) { return g_apply_silent; }
STUB_API int vpkc_stub_apply_restart(void) { return g_apply_restart; }
STUB_API size_t vpkc_stub_apply_argc(void) { return g_apply_argc; }
STUB_API const char *vpkc_stub_apply_arg0(void) { return g_apply_arg0; }
STUB_API void vpkc_stub_emit_log(const char *level, const char *msg) { if (g_log_cb) g_log_cb(g_log_ud, level, msg); }
STUB_API size_t vpkc_stub_sizeof_asset(void) { return sizeof(vpkc_asset_t); }
STUB_API size_t vpkc_stub_sizeof_update_info(void) { return sizeof(vpkc_update_info_t); }
STUB_API size_t vpkc_stub_sizeof_options(void) { return sizeof(vpkc_update_options_t); }
STUB_API size_t vpkc_stub_sizeof_locator(void) { return sizeof(vpkc_locator_config_t); }
STUB_API size_t vpkc_stub_sizeof_http_options(void) { return sizeof(vpkc_http_options_t); }
STUB_API size_t vpkc_stub_offsetof_asset_size(void) { return offsetof(vpkc_asset_t, Size); }
STUB_API size_t vpkc_stub_offsetof_info_is_downgrade(void) { return offsetof(vpkc_update_info_t, IsDowngrade); }
STUB_API size_t vpkc_stub_offsetof_options_max_deltas(void) { return offsetof(vpkc_update_options_t, MaximumDeltasBeforeFallback); }
