//+------------------------------------------------------------------+
//|                         nexus_logger.h                            |
//|                  Nexus Confluence V3 - Logging System             |
//+------------------------------------------------------------------+
#ifndef NEXUS_LOGGER_H
#define NEXUS_LOGGER_H

#include "nexus_types.h"
#include <cstdarg>
#include <cstdio>
#include <cstring>

// Ring buffer for log messages that MQL5 can read
#define NX_LOG_RING_SIZE 64

class NexusLogger {
public:
    NexusLogger() : m_level(NX_LOG_OPERATIONAL), m_write_idx(0) {
        memset(m_ring, 0, sizeof(m_ring));
    }

    void SetLevel(int level) {
        m_level = level;
    }

    int GetLevel() const { return m_level; }

    // Format and store log message (only if level is sufficient)
    void Log(int level, const char* format, ...) {
        if (level > m_level) return;

        char buffer[NX_MAX_LOG_LEN];
        va_list args;
        va_start(args, format);
        vsnprintf(buffer, NX_MAX_LOG_LEN - 1, format, args);
        va_end(args);
        buffer[NX_MAX_LOG_LEN - 1] = '\0';

        // Store in ring buffer
        int idx = m_write_idx % NX_LOG_RING_SIZE;
        strncpy(m_ring[idx].message, buffer, NX_MAX_LOG_LEN - 1);
        m_ring[idx].level = level;
        m_write_idx++;
    }

    // Append log to a result buffer (used by NX_OnTick to fill NX_TickResult.log_message)
    void AppendToBuffer(char* dest, int dest_size) const {
        if (m_write_idx == 0) {
            dest[0] = '\0';
            return;
        }

        dest[0] = '\0';
        int start = (m_write_idx > NX_LOG_RING_SIZE) ? (m_write_idx - NX_LOG_RING_SIZE) : 0;
        int remaining = dest_size - 1;

        for (int i = start; i < m_write_idx && remaining > 0; i++) {
            int idx = i % NX_LOG_RING_SIZE;
            int len = (int)strlen(m_ring[idx].message);
            if (len + 1 > remaining) break;

            strncat(dest, m_ring[idx].message, remaining);
            remaining -= len;
            if (remaining > 1) {
                strncat(dest, "\n", remaining);
                remaining--;
            }
        }
    }

    // Clear log buffer for next tick
    void ClearBuffer() {
        m_write_idx = 0;
    }

    // Convenience methods
    void Executive(const char* format, ...) {
        if (m_level < NX_LOG_EXECUTIVE) return;
        char buffer[NX_MAX_LOG_LEN];
        va_list args;
        va_start(args, format);
        vsnprintf(buffer, NX_MAX_LOG_LEN - 1, format, args);
        va_end(args);
        Log(NX_LOG_EXECUTIVE, "[EXEC] %s", buffer);
    }

    void Operational(const char* format, ...) {
        if (m_level < NX_LOG_OPERATIONAL) return;
        char buffer[NX_MAX_LOG_LEN];
        va_list args;
        va_start(args, format);
        vsnprintf(buffer, NX_MAX_LOG_LEN - 1, format, args);
        va_end(args);
        Log(NX_LOG_OPERATIONAL, "[OPER] %s", buffer);
    }

    void Debug(const char* format, ...) {
        if (m_level < NX_LOG_DEBUG) return;
        char buffer[NX_MAX_LOG_LEN];
        va_list args;
        va_start(args, format);
        vsnprintf(buffer, NX_MAX_LOG_LEN - 1, format, args);
        va_end(args);
        Log(NX_LOG_DEBUG, "[DBG] %s", buffer);
    }

private:
    struct LogEntry {
        char message[NX_MAX_LOG_LEN];
        int  level;
    };

    int      m_level;
    int      m_write_idx;
    LogEntry m_ring[NX_LOG_RING_SIZE];
};

#endif // NEXUS_LOGGER_H
