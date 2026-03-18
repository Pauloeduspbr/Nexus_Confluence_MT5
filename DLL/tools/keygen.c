//+------------------------------------------------------------------+
//|                          keygen.c                                 |
//|         Nexus Confluence V3 - License Key Generator               |
//|         INTERNAL USE ONLY - DO NOT DISTRIBUTE                     |
//+------------------------------------------------------------------+
// Build: gcc -o keygen keygen.c
// Usage: keygen <type> <account> [expiry_unix]
//   type: 1=TRIAL, 2=STARTER, 3=PRO, 4=LIFETIME
//   account: MT5 account number (0=any account)
//   expiry: unix timestamp (0=no expiry, default for LIFETIME)

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <time.h>

int main(int argc, char* argv[]) {
    if (argc < 3) {
        printf("Nexus Confluence V3 - License Key Generator\n");
        printf("=============================================\n");
        printf("Usage: %s <type> <account> [expiry_unix]\n\n", argv[0]);
        printf("Types:\n");
        printf("  1 = TRIAL    (14 days, 1 account)\n");
        printf("  2 = STARTER  (1 year, 1 account)\n");
        printf("  3 = PRO      (1 year, 3 accounts)\n");
        printf("  4 = LIFETIME (no expiry, 5 accounts)\n\n");
        printf("Account: MT5 account number (0 = any account)\n");
        printf("Expiry:  Unix timestamp (0 = no expiry)\n\n");
        printf("Examples:\n");
        printf("  %s 1 7635384              # Trial for account 7635384\n", argv[0]);
        printf("  %s 4 0 0                  # Lifetime, any account\n", argv[0]);
        printf("  %s 2 7635384 1772531200   # Starter, expires 2026-03-01\n", argv[0]);
        return 1;
    }

    int type = atoi(argv[1]);
    int account = atoi(argv[2]);
    uint32_t expiry = 0;

    if (argc > 3) {
        expiry = (uint32_t)atoll(argv[3]);
    } else {
        // Default expiry based on type
        time_t now = time(NULL);
        switch (type) {
            case 1: expiry = (uint32_t)now + 14 * 86400;   break; // 14 days
            case 2: expiry = (uint32_t)now + 365 * 86400;  break; // 1 year
            case 3: expiry = (uint32_t)now + 365 * 86400;  break; // 1 year
            case 4: expiry = 0;                             break; // Lifetime
            default:
                printf("ERROR: Invalid type %d\n", type);
                return 1;
        }
    }

    // Generate checksum
    uint32_t chk = (type ^ account ^ expiry ^ 0x4E585633) & 0xFFFF;

    // Format key
    printf("\n");
    printf("=== LICENSE KEY GENERATED ===\n");
    printf("Key:     %04X-%04X-%08X-%04X\n", type, account, expiry, chk);
    printf("Type:    %d (%s)\n", type,
        type == 1 ? "TRIAL" :
        type == 2 ? "STARTER" :
        type == 3 ? "PRO" :
        type == 4 ? "LIFETIME" : "UNKNOWN");
    printf("Account: %d%s\n", account, account == 0 ? " (ANY)" : "");

    if (expiry > 0) {
        time_t exp_time = (time_t)expiry;
        struct tm* tm_info = gmtime(&exp_time);
        char buf[64];
        strftime(buf, sizeof(buf), "%Y-%m-%d %H:%M:%S UTC", tm_info);
        printf("Expires: %s\n", buf);
    } else {
        printf("Expires: NEVER\n");
    }
    printf("=============================\n");

    return 0;
}
