#!/usr/bin/python

import sys, getopt, subprocess


def main(argv):
    file = ''
    try:
        opts, args = getopt.getopt(argv, "hf:", ["file="])
    except getopt.GetoptError:
        print 'write_file_logs_to_syslog.py -f <file>'
        sys.exit(2)

    for opt, arg in opts:
        if opt == '-h':
            print 'write_file_logs_to_syslog.py -f <file>'
            sys.exit()
        elif opt in ("-f", "--file"):
            file = arg
    print 'Input file is "', file

    content_file = open(file, "r")

    for line in content_file:
        logger_cmd = 'logger -t "pg" "' + line.rstrip('\n') + '"'
        print logger_cmd
        return_code = subprocess.call(logger_cmd, shell=True)

    content_file.close()

if __name__ == "__main__":
    main(sys.argv[1:])
