#pragma once

extern "C" void zig_assert(bool cond);
extern "C" void zig_debug_break();

#define IM_ASSERT(_EXPR) zig_assert(_EXPR)
#define IM_DEBUG_BREAK zig_debug_break
