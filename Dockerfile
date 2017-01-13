FROM 172.16.10.233:5000/gliderlabs/alpine
COPY hello /usr/bin/
ENTRYPOINT /usr/bin/hello
EXPOSE 1234
