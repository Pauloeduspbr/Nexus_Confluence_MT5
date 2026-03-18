//+------------------------------------------------------------------+
//|                        nexus_license.h                            |
//|              Nexus Confluence V3 - License System                 |
//|                  Copyright 2024-2026, Nexus EA                   |
//+------------------------------------------------------------------+
#ifndef NEXUS_LICENSE_H
#define NEXUS_LICENSE_H

#include "nexus_types.h"
#include <cstring>
#include <cstdio>
#include <cstdint>

#ifdef _WIN32
#include <windows.h>
#endif

//+------------------------------------------------------------------+
//| License Configuration                                             |
//+------------------------------------------------------------------+

// Compile with -DNEXUS_OPEN to disable license checks (creator build)
// Default commercial build: license required

#ifdef NEXUS_OPEN
    // ============================================================
    // OPEN BUILD — No license required (creator/developer use)
    // ============================================================
    static inline int NX_CheckLicense(int account_number, const char* license_key) {
        (void)account_number;
        (void)license_key;
        return NX_OK;  // Always pass
    }

    static inline const char* NX_GetLicenseStatus() {
        return "OPEN BUILD - No license required";
    }

    static inline int NX_GetLicenseType() {
        return 99;  // Creator/developer
    }

#else
    // ============================================================
    // COMMERCIAL BUILD — License validation required
    // ============================================================

    // License types
    enum NX_LicenseType {
        NX_LIC_INVALID   = 0,
        NX_LIC_TRIAL     = 1,   // 14 days, 1 account
        NX_LIC_STARTER   = 2,   // 1 year, 1 account
        NX_LIC_PRO       = 3,   // 1 year, 3 accounts
        NX_LIC_LIFETIME  = 4,   // Lifetime, 5 accounts
        NX_LIC_CREATOR   = 99   // Unlimited (internal only)
    };

    // License data (validated in DLL, never exposed)
    struct NX_LicenseData {
        uint32_t magic;           // 0x4E585633 = "NXV3"
        int      license_type;    // NX_LicenseType
        int      account_number;  // MT5 account locked to
        int      max_accounts;    // Max simultaneous accounts
        uint32_t expiry_date;     // Unix timestamp (0 = no expiry)
        uint32_t hwid_hash;       // Hardware ID hash
        uint32_t checksum;        // Simple checksum for tamper detection
    };

    static NX_LicenseData g_license = {0};
    static char g_license_status[256] = "NOT VALIDATED";
    static bool g_license_valid = false;

    //+------------------------------------------------------------------+
    //| HWID Generation (Windows)                                        |
    //+------------------------------------------------------------------+
    static uint32_t GenerateHWID() {
        uint32_t hwid = 0;
    #ifdef _WIN32
        // Use volume serial number of C: drive
        DWORD serial = 0;
        GetVolumeInformationA("C:\\", NULL, 0, &serial, NULL, NULL, NULL, 0);
        hwid = (uint32_t)serial;

        // Mix with computer name hash
        char comp_name[256] = {0};
        DWORD name_len = sizeof(comp_name);
        GetComputerNameA(comp_name, &name_len);
        for (int i = 0; comp_name[i]; i++) {
            hwid = hwid * 31 + (uint32_t)comp_name[i];
        }
    #endif
        return hwid;
    }

    //+------------------------------------------------------------------+
    //| License Key Decoder                                               |
    //| Format: XXXX-XXXX-XXXX-XXXX (hex encoded, 16 chars = 64 bits)    |
    //+------------------------------------------------------------------+
    static uint32_t SimpleHash(const char* str) {
        uint32_t hash = 5381;
        while (*str) {
            hash = ((hash << 5) + hash) + (uint32_t)*str;
            str++;
        }
        return hash;
    }

    static bool DecodeLicenseKey(const char* key, int account_number, NX_LicenseData* out) {
        if (!key || !out) return false;

        // Key format: TYPE-ACCT-EXPR-CHCK
        // Simple validation: hash-based
        int type_code = 0, acct_code = 0, expr_code = 0, chck_code = 0;

        if (sscanf(key, "%X-%X-%X-%X", &type_code, &acct_code, &expr_code, &chck_code) != 4) {
            return false;
        }

        // Validate checksum
        uint32_t expected_chk = (type_code ^ acct_code ^ expr_code ^ 0x4E585633) & 0xFFFF;
        if ((uint32_t)chck_code != expected_chk) {
            return false;
        }

        out->magic = 0x4E585633;
        out->license_type = type_code & 0xFF;
        out->account_number = acct_code;
        out->expiry_date = (uint32_t)expr_code;
        out->checksum = (uint32_t)chck_code;

        // Validate license type
        if (out->license_type < NX_LIC_TRIAL || out->license_type > NX_LIC_LIFETIME) {
            return false;
        }

        // Set max accounts based on type
        switch (out->license_type) {
            case NX_LIC_TRIAL:    out->max_accounts = 1; break;
            case NX_LIC_STARTER:  out->max_accounts = 1; break;
            case NX_LIC_PRO:      out->max_accounts = 3; break;
            case NX_LIC_LIFETIME: out->max_accounts = 5; break;
            default:              out->max_accounts = 0; break;
        }

        return true;
    }

    //+------------------------------------------------------------------+
    //| License Validation                                                |
    //+------------------------------------------------------------------+
    static int NX_CheckLicense(int account_number, const char* license_key) {
        // No key provided
        if (!license_key || license_key[0] == '\0') {
            snprintf(g_license_status, sizeof(g_license_status),
                "LICENSE REQUIRED: Please provide a valid license key in EA inputs.");
            g_license_valid = false;
            return NX_ERR_LICENSE_INVALID;
        }

        // Decode key
        NX_LicenseData lic = {0};
        if (!DecodeLicenseKey(license_key, account_number, &lic)) {
            snprintf(g_license_status, sizeof(g_license_status),
                "INVALID LICENSE KEY: Format error or checksum mismatch.");
            g_license_valid = false;
            return NX_ERR_LICENSE_INVALID;
        }

        // Check account match (0 = any account)
        if (lic.account_number != 0 && lic.account_number != account_number) {
            snprintf(g_license_status, sizeof(g_license_status),
                "LICENSE ERROR: Key is for account %d, current account is %d.",
                lic.account_number, account_number);
            g_license_valid = false;
            return NX_ERR_LICENSE_INVALID;
        }

        // Check expiry
        if (lic.expiry_date > 0) {
        #ifdef _WIN32
            FILETIME ft;
            GetSystemTimeAsFileTime(&ft);
            // Convert FILETIME to unix timestamp
            uint64_t win_time = ((uint64_t)ft.dwHighDateTime << 32) | ft.dwLowDateTime;
            uint32_t unix_time = (uint32_t)((win_time - 116444736000000000ULL) / 10000000ULL);

            if (unix_time > lic.expiry_date) {
                snprintf(g_license_status, sizeof(g_license_status),
                    "LICENSE EXPIRED: Your license expired. Please renew.");
                g_license_valid = false;
                return NX_ERR_LICENSE_EXPIRED;
            }
        #endif
        }

        // License valid
        g_license = lic;
        g_license_valid = true;

        const char* type_names[] = {"?", "TRIAL", "STARTER", "PRO", "LIFETIME"};
        const char* type_name = (lic.license_type >= 1 && lic.license_type <= 4)
            ? type_names[lic.license_type] : "UNKNOWN";

        snprintf(g_license_status, sizeof(g_license_status),
            "LICENSE VALID: %s | Account: %d | Max Accounts: %d",
            type_name, account_number, lic.max_accounts);

        return NX_OK;
    }

    static const char* NX_GetLicenseStatus() {
        return g_license_status;
    }

    static int NX_GetLicenseType() {
        return g_license_valid ? g_license.license_type : NX_LIC_INVALID;
    }

#endif // NEXUS_OPEN

//+------------------------------------------------------------------+
//| License Key Generator (for admin use, NOT in DLL)                 |
//| Usage: GenerateLicenseKey(type, account, expiry_unix)             |
//+------------------------------------------------------------------+
#ifdef NEXUS_KEYGEN
static void GenerateLicenseKey(int type, int account, uint32_t expiry) {
    uint32_t chk = (type ^ account ^ expiry ^ 0x4E585633) & 0xFFFF;
    printf("License Key: %04X-%04X-%08X-%04X\n", type, account, expiry, chk);
    printf("  Type: %d | Account: %d | Expiry: %u\n", type, account, expiry);
}
#endif

#endif // NEXUS_LICENSE_H
