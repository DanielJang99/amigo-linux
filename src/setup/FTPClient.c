#include <stdio.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <string.h>
#include <stdlib.h>
#include <errno.h>
#include <netinet/in.h>
#include <sys/time.h>
#include <signal.h>
#include <time.h>

static int quit = 0;
static int sockfd;
static int sockfd_udp;
struct timeval receivedtime;
struct timeval start_time;

typedef struct __attribute__((packed, aligned(2))) m {
  uint32_t seq;
  long long seconds;
  long long mili;
} udp_packet_t;

/* SIGINT handler: set quit to 1 for graceful termination */
void
handle_sigint(int signum) {
  quit = 1;
  gettimeofday(&receivedtime,NULL);

  printf ("\n Finished the experiement \n");
  exit(0);
}


int main(int argc, char** argv) {
    FILE *fp;
    int retries=0;

    if(argc < 5){
        printf("Enter <IP address> <Port number> <IMEI> <EXP_TYPE>");
        exit(EXIT_FAILURE);
    }

    char* ip_address = argv[1];
    int port = atoi(argv[2]);
    char* imei = argv[3];
    char* exp_type = argv[4];

    while (1) { 
        int sockfd = socket(AF_INET, SOCK_STREAM, 0);
        struct sockaddr_in server_addr;
        memset(&server_addr, 0, sizeof(server_addr));
        server_addr.sin_family = AF_INET;
        server_addr.sin_addr.s_addr = inet_addr(ip_address);
        server_addr.sin_port = htons(port);


        int connect_status = connect(sockfd, (struct sockaddr*)&server_addr, sizeof(server_addr));
        if(connect_status != -1){

            char rstr[200];
            char command[1024];

            memset(rstr, 0, sizeof(rstr));
            memset(command, 0, sizeof(command));

            sprintf(command, "START %s %s\n", imei, exp_type);

            write(sockfd, command, strlen(command));
            
            int received_port = 0;
            read(sockfd, &received_port, sizeof(received_port));
            int port = ntohl(received_port);

            if(port > 0){

                printf ("RECEIVED PORT %d \n", port);

                int n, bytes_sent;
                float delay;
                struct sockaddr_in servaddr, to_addr;
                time_t current_time;
    	        time_t time_to_exit;

                char filename[256];
                char serveripaddress[256];
                udp_packet_t *pdu;

                // FIXME: date with file name
                // sprintf(filename, "./%s", argv[2]);

                sockfd_udp=socket(AF_INET,SOCK_DGRAM,0);

                printf ("----%s \n", ip_address);
                
                // creating the address struct for the remote server
                to_addr.sin_family = AF_INET;
                to_addr.sin_port = htons(port);
                to_addr.sin_addr.s_addr = inet_addr(ip_address);

                bytes_sent = sendto(sockfd_udp, "init", 100, 0, (struct sockaddr *)&to_addr, sizeof(to_addr));
                printf ("Sent packet init with %d bytes\n", bytes_sent);

                if (bytes_sent==-1) {
                    printf("failed to send initial packet request from user side \n");
                    exit(0);
                }


                // bind the socket to the the port number
                bzero(&servaddr,sizeof(servaddr));
                servaddr.sin_family = AF_INET;
                servaddr.sin_addr.s_addr=htonl(INADDR_ANY);
                servaddr.sin_port=htons(port);
                bind(sockfd_udp,(struct sockaddr *)&servaddr,sizeof(servaddr));

                printf("Connected for data transmission \n");
                // fprintf(fp, "SEQ \t received time \n");

                time_t t = time(NULL);
                struct tm tm = *localtime(&t);
                // sprintf(filename, "./%d-%02d-%02d %02d:%02d:%02d.csv", tm.tm_year + 1900, tm.tm_mon + 1, tm.tm_mday, tm.tm_hour, tm.tm_min, tm.tm_sec);
                // fp=fopen(filename, "w+");
                fp=fopen("./zeus.csv", "w+");

                signal(SIGINT, handle_sigint);

                pdu = (udp_packet_t *) malloc(sizeof(udp_packet_t));
    	
                time(&current_time);
                gettimeofday(&start_time,NULL);
                time(&time_to_exit);
                time_to_exit += 60; // yasir

                while (time_to_exit > current_time)
                {
                  n = recvfrom(sockfd_udp,pdu,1000000,0,NULL,NULL);
                  gettimeofday(&receivedtime,NULL);
                  time(&current_time);

                  //printf("%3.9u,\t %ld.%3.6ld\n", pdu->seq, receivedtime.tv_sec, receivedtime.tv_usec);
                  fprintf(fp, "%3.9u, %ld.%3.6ld\n", pdu->seq, receivedtime.tv_sec-start_time.tv_sec, receivedtime.tv_usec-start_time.tv_usec);
                  //fprintf(fp, "%3.9u,\t %ld.%3.6d,\t %lld.%3.6lld,\t %f,\t %d, \t", pdu->seq, receivedtime.tv_sec, receivedtime.tv_usec, pdu->seconds, pdu->mili, delay,n);

                }
                gettimeofday(&receivedtime,NULL);

                close(sockfd_udp);
                fclose (fp);
                break;
            }  else {
                printf("Failed to connect. The server may be busy or you may have mistyped the command.\n");

                retries += 1;

                if (retries > 24)
                    break;
                printf("Trying again in 5 seconds\n");
                usleep(5000000);
            }

            close(sockfd);
            
            printf("Connection closed!\n");
        } else {
            printf("Error connecting to server: %s\n", strerror(errno));
            break;
        }
    }
}
