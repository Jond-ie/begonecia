// begonecia — CLI control, interoperates with the CC tile via the same
// Cephei/HBPreferences state + Darwin notification the tweak listens on.
//
//   begonecia on | off | toggle | status

#import "../BCCommon.h"
#import <stdio.h>
#import <string.h>

int main(int argc, char **argv) {
    @autoreleasepool {
        if (argc < 2) {
            fprintf(stderr, "usage: begonecia on|off|toggle|status\n");
            return 2;
        }
        const char *cmd = argv[1];
        bool state = BCGetState();

        if (!strcmp(cmd, "status")) {
            printf("%s\n", state ? "on (blocking camera/mic/location)" : "off");
            return 0;
        } else if (!strcmp(cmd, "on")) {
            BCSetState(true);
            printf("begonecia on\n");
        } else if (!strcmp(cmd, "off")) {
            BCSetState(false);
            printf("begonecia off\n");
        } else if (!strcmp(cmd, "toggle")) {
            BCSetState(!state);
            printf("begonecia %s\n", !state ? "on" : "off");
        } else {
            fprintf(stderr, "begonecia: unknown command '%s'\n", cmd);
            return 2;
        }
        return 0;
    }
}
