#pragma once

#include <cstdint>
#include <jni.h>

// ==========================================================================
// Client-side Dart Bridge using Flutter Embedder
// ==========================================================================
// This bridge runs on the Render thread and uses Flutter Embedder for GUI.
// Client functions are called from the Render thread ONLY, so we can use
// direct FFI calls without mutex/isolate switching.

extern "C" {

// Frame callback type for receiving rendered frames
typedef void (*FrameCallback)(const void* pixels, size_t width, size_t height, size_t row_bytes);

// ==========================================================================
// Lifecycle
// ==========================================================================

// Initialize the Flutter engine for client-side rendering
// assets_path: Path to Flutter app assets (flutter_assets directory)
// icu_data_path: Path to icudtl.dat file
// aot_library_path: Path to AOT compiled library (can be null for JIT mode)
bool dart_client_init(const char* assets_path, const char* icu_data_path, const char* aot_library_path);

// Shutdown the Flutter engine
void dart_client_shutdown();

// Process pending Flutter tasks (pumps the event loop)
// Should be called regularly from the render thread
void dart_client_process_tasks();

// Set JVM reference for JNI callbacks
void dart_client_set_jvm(JavaVM* jvm);

// Set the callback for receiving rendered frames
void dart_client_set_frame_callback(FrameCallback callback);

// Get the Dart VM service URL for hot reload/debugging
const char* dart_client_get_service_url();

// ==========================================================================
// Window/Input Events (sent from Java to Flutter)
// ==========================================================================

// Send window size change to Flutter
void dart_client_send_window_metrics(int32_t width, int32_t height, double pixel_ratio);

// Send pointer/mouse event to Flutter
// phase: 0=cancel, 1=up, 2=down, 3=move, 4=add, 5=remove, 6=hover
void dart_client_send_pointer_event(int32_t phase, double x, double y, int64_t buttons);

// Send keyboard event to Flutter
// type: 0=down, 1=up
void dart_client_send_key_event(int32_t type, int64_t physical_key, int64_t logical_key,
                                  const char* characters, int32_t modifiers);

// ==========================================================================
// Screen/GUI Callback Types (client-only)
// ==========================================================================

// Screen callbacks
typedef void (*ScreenInitCallback)(int64_t screen_id, int32_t width, int32_t height);
typedef void (*ScreenTickCallback)(int64_t screen_id);
typedef void (*ScreenRenderCallback)(int64_t screen_id, int32_t mouse_x, int32_t mouse_y, float partial_tick);
typedef void (*ScreenCloseCallback)(int64_t screen_id);
typedef bool (*ScreenKeyPressedCallback)(int64_t screen_id, int32_t key_code, int32_t scan_code, int32_t modifiers);
typedef bool (*ScreenKeyReleasedCallback)(int64_t screen_id, int32_t key_code, int32_t scan_code, int32_t modifiers);
typedef bool (*ScreenCharTypedCallback)(int64_t screen_id, int32_t code_point, int32_t modifiers);
typedef bool (*ScreenMouseClickedCallback)(int64_t screen_id, double mouse_x, double mouse_y, int32_t button);
typedef bool (*ScreenMouseReleasedCallback)(int64_t screen_id, double mouse_x, double mouse_y, int32_t button);
typedef bool (*ScreenMouseDraggedCallback)(int64_t screen_id, double mouse_x, double mouse_y, int32_t button, double drag_x, double drag_y);
typedef bool (*ScreenMouseScrolledCallback)(int64_t screen_id, double mouse_x, double mouse_y, double delta_x, double delta_y);

// Widget callbacks
typedef void (*WidgetPressedCallback)(int64_t screen_id, int64_t widget_id);
typedef void (*WidgetTextChangedCallback)(int64_t screen_id, int64_t widget_id, const char* text);

// Container screen callbacks
typedef void (*ContainerScreenInitCallback)(int64_t screen_id, int32_t width, int32_t height,
                                             int32_t left_pos, int32_t top_pos, int32_t image_width, int32_t image_height);
typedef void (*ContainerScreenRenderBgCallback)(int64_t screen_id, int32_t mouse_x, int32_t mouse_y,
                                                  float partial_tick, int32_t left_pos, int32_t top_pos);
typedef void (*ContainerScreenCloseCallback)(int64_t screen_id);

// Container menu callbacks
typedef int32_t (*ContainerSlotClickCallback)(int64_t menu_id, int32_t slot_index, int32_t button, int32_t click_type, const char* carried_item);
typedef const char* (*ContainerQuickMoveCallback)(int64_t menu_id, int32_t slot_index);
typedef bool (*ContainerMayPlaceCallback)(int64_t menu_id, int32_t slot_index, const char* item_data);
typedef bool (*ContainerMayPickupCallback)(int64_t menu_id, int32_t slot_index);

// Container lifecycle event callbacks (for event-driven container open/close)
typedef void (*ContainerOpenCallback)(int32_t menu_id, int32_t slot_count);
typedef void (*ContainerCloseCallback)(int32_t menu_id);

// ==========================================================================
// Callback Registration (called from Dart via FFI)
// ==========================================================================

void client_register_screen_init_handler(ScreenInitCallback cb);
void client_register_screen_tick_handler(ScreenTickCallback cb);
void client_register_screen_render_handler(ScreenRenderCallback cb);
void client_register_screen_close_handler(ScreenCloseCallback cb);
void client_register_screen_key_pressed_handler(ScreenKeyPressedCallback cb);
void client_register_screen_key_released_handler(ScreenKeyReleasedCallback cb);
void client_register_screen_char_typed_handler(ScreenCharTypedCallback cb);
void client_register_screen_mouse_clicked_handler(ScreenMouseClickedCallback cb);
void client_register_screen_mouse_released_handler(ScreenMouseReleasedCallback cb);
void client_register_screen_mouse_dragged_handler(ScreenMouseDraggedCallback cb);
void client_register_screen_mouse_scrolled_handler(ScreenMouseScrolledCallback cb);

void client_register_widget_pressed_handler(WidgetPressedCallback cb);
void client_register_widget_text_changed_handler(WidgetTextChangedCallback cb);

void client_register_container_screen_init_handler(ContainerScreenInitCallback cb);
void client_register_container_screen_render_bg_handler(ContainerScreenRenderBgCallback cb);
void client_register_container_screen_close_handler(ContainerScreenCloseCallback cb);

void client_register_container_slot_click_handler(ContainerSlotClickCallback cb);
void client_register_container_quick_move_handler(ContainerQuickMoveCallback cb);
void client_register_container_may_place_handler(ContainerMayPlaceCallback cb);
void client_register_container_may_pickup_handler(ContainerMayPickupCallback cb);

// Container lifecycle event callbacks (for event-driven container open/close)
void client_register_container_open_handler(ContainerOpenCallback cb);
void client_register_container_close_handler(ContainerCloseCallback cb);

// ==========================================================================
// Event Dispatch (called from Java via JNI)
// Client-side uses direct FFI calls (single thread, no isolate switching)
// ==========================================================================

void client_dispatch_screen_init(int64_t screen_id, int32_t width, int32_t height);
void client_dispatch_screen_tick(int64_t screen_id);
void client_dispatch_screen_render(int64_t screen_id, int32_t mouse_x, int32_t mouse_y, float partial_tick);
void client_dispatch_screen_close(int64_t screen_id);
bool client_dispatch_screen_key_pressed(int64_t screen_id, int32_t key_code, int32_t scan_code, int32_t modifiers);
bool client_dispatch_screen_key_released(int64_t screen_id, int32_t key_code, int32_t scan_code, int32_t modifiers);
bool client_dispatch_screen_char_typed(int64_t screen_id, int32_t code_point, int32_t modifiers);
bool client_dispatch_screen_mouse_clicked(int64_t screen_id, double mouse_x, double mouse_y, int32_t button);
bool client_dispatch_screen_mouse_released(int64_t screen_id, double mouse_x, double mouse_y, int32_t button);
bool client_dispatch_screen_mouse_dragged(int64_t screen_id, double mouse_x, double mouse_y, int32_t button, double drag_x, double drag_y);
bool client_dispatch_screen_mouse_scrolled(int64_t screen_id, double mouse_x, double mouse_y, double delta_x, double delta_y);

void client_dispatch_widget_pressed(int64_t screen_id, int64_t widget_id);
void client_dispatch_widget_text_changed(int64_t screen_id, int64_t widget_id, const char* text);

void client_dispatch_container_screen_init(int64_t screen_id, int32_t width, int32_t height,
                                            int32_t left_pos, int32_t top_pos, int32_t image_width, int32_t image_height);
void client_dispatch_container_screen_render_bg(int64_t screen_id, int32_t mouse_x, int32_t mouse_y,
                                                  float partial_tick, int32_t left_pos, int32_t top_pos);
void client_dispatch_container_screen_close(int64_t screen_id);

int32_t client_dispatch_container_slot_click(int64_t menu_id, int32_t slot_index, int32_t button, int32_t click_type, const char* carried_item);
const char* client_dispatch_container_quick_move(int64_t menu_id, int32_t slot_index);
bool client_dispatch_container_may_place(int64_t menu_id, int32_t slot_index, const char* item_data);
bool client_dispatch_container_may_pickup(int64_t menu_id, int32_t slot_index);

// Container lifecycle event dispatch (for event-driven container open/close)
void client_dispatch_container_open(int32_t menu_id, int32_t slot_count);
void client_dispatch_container_close(int32_t menu_id);

// ==========================================================================
// Network Packet Functions (Client-side)
// ==========================================================================

// Callback type for packet received from server (S2C)
typedef void (*ClientPacketReceivedCallback)(int32_t packet_type, const uint8_t* data, int32_t data_length);

// Callback type for sending packets to server (C2S) - called by Dart
typedef void (*SendPacketToServerCallback)(int32_t packet_type, const uint8_t* data, int32_t data_length);

// Register the callback for receiving packets from server (called from Dart via FFI)
void client_register_packet_received_handler(ClientPacketReceivedCallback cb);

// Set the callback for sending packets to server (called from Dart via FFI)
void client_set_send_packet_to_server_callback(SendPacketToServerCallback cb);

// Dispatch a packet from server to client Dart/Flutter runtime (called from Java via JNI)
void client_dispatch_server_packet(int32_t packet_type, const uint8_t* data, int32_t data_length);

// Send a packet from client to server - invokes the Java callback (called from Dart via FFI)
void client_send_packet_to_server(int32_t packet_type, const uint8_t* data, int32_t data_length);

// ==========================================================================
// Slot Position Reporting (Flutter -> Java)
// ==========================================================================

// Update slot positions for a container menu
// data format: [slotIndex, x, y, width, height, slotIndex, x, y, width, height, ...]
// All values are int32, positions in physical pixels
void client_update_slot_positions(int32_t menu_id, const int32_t* data, int32_t data_length);

} // extern "C"
